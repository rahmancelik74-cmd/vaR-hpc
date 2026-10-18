#include "mc/cuda.hpp"
#include <cuda_runtime.h>
#include <curand.h>
#include <algorithm>
#include <cmath>
#include <iostream>
#include <iomanip>
#include <limits>
#include <numeric>
#include <sstream>
#include <stdexcept>

namespace {
void check(bool ok, const char* label) { if (!ok) throw std::runtime_error(label); }
void cuda_ok(cudaError_t status) { check(status == cudaSuccess, "Reference CUDA operation failed"); }
void rng_ok(curandStatus_t status) { check(status == CURAND_STATUS_SUCCESS, "Reference cuRAND operation failed"); }
template<class E, class F> void rejects(F f) {
    bool threw = false; try { f(); } catch (const E&) { threw = true; }
    check(threw, "Expected hybrid rejection");
}
// Independent reference: concatenate explicitly specified cuRAND call payloads on host.
// Production hybrid never transfers normals in native mode.
std::vector<double> reference_normals(std::uint64_t seed, const std::vector<std::size_t>& payloads) {
    struct Reference {
        curandGenerator_t rng = nullptr;
        double* buffer = nullptr;
        ~Reference() { if (rng) curandDestroyGenerator(rng); if (buffer) cudaFree(buffer); }
    } ref;
    const auto largest = *std::max_element(payloads.begin(), payloads.end());
    cuda_ok(cudaMalloc(reinterpret_cast<void**>(&ref.buffer), (largest + largest%2)*sizeof(double)));
    rng_ok(curandCreateGenerator(&ref.rng, CURAND_RNG_PSEUDO_PHILOX4_32_10));
    rng_ok(curandSetPseudoRandomGeneratorSeed(ref.rng, seed));
    std::vector<double> all;
    for (auto count : payloads) {
        rng_ok(curandGenerateNormalDouble(ref.rng, ref.buffer, count + count%2, 0, 1));
        std::vector<double> part(count);
        cuda_ok(cudaMemcpy(part.data(), ref.buffer, count*sizeof(double), cudaMemcpyDeviceToHost));
        all.insert(all.end(), part.begin(), part.end());
    }
    rng_ok(curandDestroyGenerator(ref.rng)); ref.rng = nullptr;
    cuda_ok(cudaFree(ref.buffer)); ref.buffer = nullptr;
    return all;
}
void agrees(const mc::Result& a, const mc::Result& b, double initial) {
    check(a.estimates.size() == b.estimates.size(), "Estimate count differs");
    for (std::size_t i = 0; i < a.estimates.size(); ++i) {
        check(a.estimates[i].confidence == b.estimates[i].confidence, "Confidence changed");
        const auto delta = std::abs(a.estimates[i].var - b.estimates[i].var);
        check(std::isfinite(delta) && delta <= .00001*initial, "Hybrid project tolerance exceeded");
        check(delta <= 1e-10*std::max(1.0,std::abs(a.estimates[i].var)), "Hybrid strict regression tolerance exceeded");
    }
}
}
int main(int argc, char** argv) {
    try {
        const bool scale = argc == 2 && std::string(argv[1]) == "--scale-common";
        if (argc > 1 && !scale) throw std::invalid_argument("Expected --scale-common or no arguments");
        std::size_t cases = 0;
        double maximum_difference = 0;
        std::ostringstream records;
        records.imbue(std::locale::classic()); records << std::setprecision(17);
        auto common_case = [&](mc::Request r, std::size_t batch) {
            std::vector<double> inputs(r.scenarios);
            for (std::size_t i = 0; i < inputs.size(); ++i)
                inputs[i] = (static_cast<int>(i*37%101)-50)/10.0;
            const auto original = inputs;
            const auto cpu = mc::SerialEngine().run(r, &inputs);
            const auto full = mc::CudaEngine().run(r, &inputs);
            const auto hybrid = mc::CudaEngine(mc::CudaMode::Hybrid,batch).run(r, &inputs);
            agrees(cpu, hybrid, r.model.initial_value); agrees(full, hybrid, r.model.initial_value);
            check(inputs == original, "Hybrid modified common inputs");
            const auto& m = *hybrid.cuda;
            const auto effective = std::min(batch,r.scenarios);
            const auto batches = (r.scenarios + effective - 1)/effective;
            check(m.mode == "hybrid" && m.requested_batch_size == batch
                && m.effective_batch_size == effective && m.batch_count == batches, "Common batch metadata");
            check(m.losses_transferred == r.scenarios && m.host_loss_bytes == r.scenarios*sizeof(double), "Not all losses represented");
            check(m.host_to_device_bytes == r.scenarios*sizeof(double)
                && m.device_to_host_bytes == r.scenarios*sizeof(double)+batches*sizeof(int), "Batch transfer coverage");
            check(m.normals_generated == 0 && m.normals_allocated == effective
                && m.explicit_device_bytes == 2*effective*sizeof(double)+sizeof(int)
                && m.cub_temporary_bytes == 0, "Bounded common-input device memory");
            double case_difference = 0;
            for (std::size_t i = 0; i < cpu.estimates.size(); ++i)
                case_difference = std::max(case_difference,std::abs(cpu.estimates[i].var-hybrid.estimates[i].var));
            maximum_difference = std::max(maximum_difference,case_difference);
            if (cases) records << ',';
            records << "{\"kind\":\"common-input\",\"scenarios\":" << r.scenarios << ",\"requested_batch_size\":" << batch
                << ",\"effective_batch_size\":" << effective << ",\"batch_count\":" << batches
                << ",\"maximum_difference\":" << case_difference << ",\"project_tolerance\":" << .00001*r.model.initial_value
                << ",\"passed\":true}";
            ++cases;
        };
        mc::Request r;
        // All eleven nearest ranks: losing any input, including the tail, changes the fixture.
        r.scenarios = 11; r.confidence_levels.clear();
        for (int i=0;i<11;++i) r.confidence_levels.push_back((i+.5)/11.0);
        for (auto batch : {1u,2u,3u,4u,11u,12u}) common_case(r,batch);
        r.model.volatility=0; common_case(r,3);
        r.model.horizon=0; common_case(r,3);
        r.model={}; r.scenarios=257; r.confidence_levels={.5,.95,.99}; common_case(r,31);
        r.scenarios=1; common_case(r,1);
        r.scenarios=11; r.confidence_levels.assign(16,.95); common_case(r,3);
        r.confidence_levels={.5,.95,.99};
        if (scale) for (auto n : {100000u,1000000u,10000000u}) { r.scenarios=n; common_case(r,65535); }

        auto native_case = [&](std::size_t n, std::size_t requested, std::size_t effective,
                               const std::vector<std::size_t>& payloads) {
            mc::Request request; request.scenarios=n; request.seed=(std::numeric_limits<std::uint64_t>::max)();
            if (n <= 16) {
                request.confidence_levels.clear();
                for (std::size_t i=0;i<n;++i) request.confidence_levels.push_back((i+.5)/static_cast<double>(n));
            }
            const auto reference = reference_normals(request.seed,payloads);
            check(reference.size() == n, "Invalid native reference fixture");
            const auto expected = mc::SerialEngine().run(request,&reference);
            const mc::CudaEngine engine(mc::CudaMode::Hybrid,requested);
            const auto actual = engine.run(request);
            agrees(expected,actual,request.model.initial_value);
            agrees(actual,engine.run(request),request.model.initial_value);
            const auto& m=*actual.cuda;
            check(m.effective_batch_size==effective && m.batch_count==payloads.size()
                && m.normals_generated==n+n%2 && m.losses_transferred==n
                && m.normals_allocated==effective+effective%2 && m.host_to_device_bytes==0,
                "Native stream/padding accounting");
            if (payloads.size()==1) agrees(actual,mc::CudaEngine().run(request),request.model.initial_value);
            if (cases) records << ',';
            records << "{\"kind\":\"native-reference\",\"scenarios\":" << n << ",\"requested_batch_size\":" << requested
                << ",\"effective_batch_size\":" << effective << ",\"batch_count\":" << payloads.size()
                << ",\"normals_generated\":" << m.normals_generated << ",\"passed\":true}";
            ++cases;
        };
        native_case(11,3,4,{4,4,3});
        native_case(12,3,4,{4,4,4});
        native_case(11,1,2,{2,2,2,2,2,1});
        native_case(5,99,5,{5});
        native_case(1,1,1,{1});

        r={}; r.scenarios=11;
        const mc::CudaEngine hybrid(mc::CudaMode::Hybrid,3);
        std::vector<double> bad(11,0);
        for (std::size_t index : {0u,3u,10u}) {
            bad[index]=std::numeric_limits<double>::quiet_NaN();
            rejects<std::invalid_argument>([&]{hybrid.run(r,&bad);}); bad[index]=0;
        }
        bad.back()=1e308; rejects<std::overflow_error>([&]{hybrid.run(r,&bad);}); bad.back()=0;
        agrees(mc::SerialEngine().run(r,&bad),hybrid.run(r,&bad),r.model.initial_value);
        bad.pop_back(); rejects<std::invalid_argument>([&]{hybrid.run(r,&bad);});
        for (auto batch : {std::size_t{0},std::size_t{10000001},(std::numeric_limits<std::size_t>::max)()})
            rejects<std::invalid_argument>([&]{mc::CudaEngine(mc::CudaMode::Hybrid,batch).run(r);});
        rejects<std::invalid_argument>([&]{mc::CudaEngine(mc::CudaMode::FullDevice,1).run(r);});
        r.scenarios=10000001; rejects<std::invalid_argument>([&]{hybrid.run(r);});
        r.scenarios=0; rejects<std::invalid_argument>([&]{hybrid.run(r);});
        r.scenarios=11; r.confidence_levels.assign(17,.95); rejects<std::invalid_argument>([&]{hybrid.run(r);});
        r.confidence_levels={std::numeric_limits<double>::quiet_NaN()}; rejects<std::invalid_argument>([&]{hybrid.run(r);});
        std::cout << std::setprecision(17) << "{\"purpose\":\"Hybrid implementation checks; no statistical acceptance or benchmark\","
            << "\"cases_passed\":" << cases << ",\"scale_common\":" << (scale?"true":"false")
            << ",\"maximum_common_difference\":" << maximum_difference
            << ",\"cases\":[" << records.str() << ']'
            << ",\"native_reference_contract_passed\":true,\"invalid_input_and_recovery_checks_passed\":true}\n";
        return 0;
    } catch (const std::exception& e) { std::cerr << "Hybrid test failure: " << e.what() << '\n'; return 1; }
}
