#include "mc/cuda.hpp"
#include "mc/detail/cuda_plan.hpp"
#include <cuda_runtime.h>
#include <curand.h>
#include <cub/device/device_radix_sort.cuh>
#include <cub/version.cuh>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <new>
#include <stdexcept>
#include <string>

namespace mc {
namespace {
void check(cudaError_t status, const char* operation) {
    if (status != cudaSuccess)
        throw std::runtime_error(std::string(operation) + ": " + cudaGetErrorString(status));
}
void check_rng(curandStatus_t status, const char* operation) {
    if (status != CURAND_STATUS_SUCCESS)
        throw std::runtime_error(std::string(operation) + ": cuRAND status " + std::to_string(status));
}
struct Resources {
    struct Interval { cudaEvent_t begin, end; int stage; };
    CudaDiagnostics* diagnostics = nullptr;
    std::vector<cudaEvent_t> diagnostic_events;
    std::vector<Interval> intervals;
    cudaStream_t stream = nullptr;
    cudaEvent_t begin = nullptr, end = nullptr;
    curandGenerator_t generator = nullptr;
    std::vector<void*> buffers;
    ~Resources() { release(false); }
    cudaEvent_t event() {
        cudaEvent_t value = nullptr;
        check(cudaEventCreate(&value), "Diagnostic event creation");
        try { diagnostic_events.push_back(value); }
        catch (...) { cudaEventDestroy(value); throw; }
        return value;
    }
    std::size_t start(int stage) {
        if (!diagnostics) return 0;
        const auto a = event(), b = event();
        intervals.push_back({a, b, stage});
        check(cudaEventRecord(a, stream), "Diagnostic interval start");
        return intervals.size() - 1;
    }
    void stop(std::size_t token) {
        if (diagnostics) check(cudaEventRecord(intervals[token].end, stream), "Diagnostic interval stop");
    }
    template<class F> void measure(int stage, F operation) {
        const auto token = start(stage);
        operation();
        stop(token);
    }
    void collect() {
        if (!diagnostics) return;
        check(cudaStreamSynchronize(stream), "Diagnostic completion");
        for (const auto& interval : intervals) {
            float ms = 0;
            check(cudaEventElapsedTime(&ms, interval.begin, interval.end), "Diagnostic elapsed time");
            auto& d = *diagnostics;
            switch (interval.stage) {
            case 0: d.initialization_ms += ms; ++d.initialization_intervals; break;
            case 1: d.rng_ms += ms; ++d.rng_intervals; break;
            case 2: d.loss_ms += ms; ++d.loss_intervals; break;
            case 3: d.cub_ms += ms; ++d.cub_intervals; break;
            case 4: d.gather_ms += ms; ++d.gather_intervals; break;
            case 5: d.pipeline_span_ms = ms; break;
            }
        }
    }
    template<class T> T* allocate(std::size_t count) {
        void* pointer = nullptr;
        const auto bytes = detail::checked_multiply(count, sizeof(T));
        check(cudaMalloc(&pointer, bytes), "Device allocation");
        try { buffers.push_back(pointer); } catch (...) { cudaFree(pointer); throw; }
        return static_cast<T*>(pointer);
    }
    void initialize() {
        check(cudaStreamCreate(&stream), "Stream creation");
        check(cudaEventCreate(&begin), "Transfer event creation");
        check(cudaEventCreate(&end), "Transfer event creation");
    }
    void release(bool checked) {
        cudaError_t first = cudaSuccess;
        auto remember = [&](cudaError_t value) { if (first == cudaSuccess) first = value; };
        if (stream) remember(cudaStreamSynchronize(stream));
        curandStatus_t rng_status = CURAND_STATUS_SUCCESS;
        if (generator) { rng_status = curandDestroyGenerator(generator); generator = nullptr; }
        for (auto pointer : buffers) remember(cudaFree(pointer));
        buffers.clear();
        if (begin) { remember(cudaEventDestroy(begin)); begin = nullptr; }
        if (end) { remember(cudaEventDestroy(end)); end = nullptr; }
        for (auto value : diagnostic_events) remember(cudaEventDestroy(value));
        diagnostic_events.clear();
        if (stream) { remember(cudaStreamDestroy(stream)); stream = nullptr; }
        if (checked) { check_rng(rng_status, "cuRAND cleanup"); check(first, "CUDA cleanup"); }
    }
    void copy(void* to, const void* from, std::size_t bytes, cudaMemcpyKind kind, CudaMetadata& info) {
        try {
            check(cudaEventRecord(begin, stream), "Copy event start");
            check(cudaMemcpyAsync(to, from, bytes, kind, stream), "Device transfer");
            check(cudaEventRecord(end, stream), "Copy event stop");
            check(cudaEventSynchronize(end), "Copy synchronization");
            float elapsed = 0;
            check(cudaEventElapsedTime(&elapsed, begin, end), "Copy event elapsed time");
            if (kind == cudaMemcpyHostToDevice) {
                info.host_to_device_ms += elapsed;
                info.host_to_device_bytes = detail::checked_add(info.host_to_device_bytes, bytes);
            } else {
                info.device_to_host_ms += elapsed;
                info.device_to_host_bytes = detail::checked_add(info.device_to_host_bytes, bytes);
            }
        } catch (...) {
            // Keep caller-owned host storage alive until pending DMA has been drained.
            // Preserve the original failure if the stream/context is already broken.
            cudaStreamSynchronize(stream);
            throw;
        }
    }
};
__global__ void losses_kernel(Model model, const double* normals, double* losses, int count, int* invalid) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < count) {
        const double z = normals[i];
        const double exponent = (model.drift - 0.5 * model.volatility * model.volatility) * model.horizon
            + model.volatility * sqrt(model.horizon) * z;
        const double loss = -model.initial_value * expm1(exponent);
        if (!isfinite(z)) atomicMax(invalid, 1);
        else if (!isfinite(loss)) atomicMax(invalid, 2);
        losses[i] = loss;
    }
}
__global__ void quantile_kernel(const double* sorted, const std::size_t* indices, double* values, int count) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < count) values[i] = sorted[indices[i]];
}
void hybrid_pipeline(const Request& r, const std::vector<double>* common, std::size_t requested,
                     Resources& resources, const cudaDeviceProp& properties, Result& result) {
    auto& info = *result.cuda;
    info.mode = "hybrid";
    info.requested_batch_size = requested;
    info.effective_batch_size = detail::hybrid_batch_size(r.scenarios, requested, common != nullptr);
    info.normals_allocated = detail::normal_count(info.effective_batch_size, common != nullptr);
    std::vector<double> host_losses;
    info.host_loss_bytes = detail::host_loss_storage(r.scenarios, host_losses.max_size());
    info.explicit_device_bytes = detail::hybrid_device_bytes(info.normals_allocated, info.effective_batch_size);
    detail::loss_blocks(info.effective_batch_size, properties.maxGridSize[0],
        properties.maxThreadsDim[0], properties.maxThreadsPerBlock);
    check(cudaMemGetInfo(&info.free_before_bytes, &info.total_vram_bytes), "Hybrid VRAM preflight");
    info.allocation_budget_limit_bytes = detail::memory_budget_80pct(info.free_before_bytes);
    detail::require_memory_budget(info.explicit_device_bytes, info.free_before_bytes);
    try { host_losses.resize(r.scenarios); }
    catch (const std::bad_alloc&) { throw std::runtime_error("Hybrid host loss allocation failed"); }
    auto normals = resources.allocate<double>(info.normals_allocated);
    auto losses = resources.allocate<double>(info.effective_batch_size);
    auto invalid_device = resources.allocate<int>(1);
    if (!common) {
        check_rng(curandCreateGenerator(&resources.generator, CURAND_RNG_PSEUDO_PHILOX4_32_10), "Hybrid cuRAND generator creation");
        check_rng(curandSetStream(resources.generator, resources.stream), "Hybrid cuRAND stream selection");
        check_rng(curandSetPseudoRandomGeneratorSeed(resources.generator, r.seed), "Hybrid cuRAND seed");
    }
    std::size_t offset = 0;
    const auto pipeline = resources.start(5);
    while (offset < r.scenarios) {
        const auto count = (std::min)(info.effective_batch_size, r.scenarios - offset);
        const auto bytes = detail::checked_multiply(count, sizeof(double));
        const auto next = detail::checked_add(offset, count);
        if (next > host_losses.size()) throw std::runtime_error("Hybrid batch exceeds host loss storage");
        if (common) resources.copy(normals, common->data() + offset, bytes, cudaMemcpyHostToDevice, info);
        else {
            const auto generated = detail::normal_count(count, false);
            if (generated > info.normals_allocated) throw std::runtime_error("Hybrid normal buffer too small");
            resources.measure(1, [&] {
                check_rng(curandGenerateNormalDouble(resources.generator, normals, generated, 0.0, 1.0), "Hybrid cuRAND normal generation");
            });
            info.normals_generated = detail::checked_add(info.normals_generated, generated);
        }
        resources.measure(0, [&] {
            check(cudaMemsetAsync(invalid_device, 0, sizeof(int), resources.stream), "Hybrid error flag initialization");
        });
        const auto blocks = detail::loss_blocks(count, properties.maxGridSize[0],
            properties.maxThreadsDim[0], properties.maxThreadsPerBlock);
        resources.measure(2, [&] {
          losses_kernel<<<blocks, detail::cuda_loss_threads, 0, resources.stream>>>(
            r.model, normals, losses, detail::checked_int(count), invalid_device);
        check(cudaGetLastError(), "Hybrid loss kernel launch");
        });
        int invalid = 0;
        resources.copy(&invalid, invalid_device, sizeof(int), cudaMemcpyDeviceToHost, info);
        if (invalid == 1) throw std::invalid_argument("Normal input must be finite");
        if (invalid) throw std::overflow_error("CUDA scenario loss overflow");
        resources.copy(host_losses.data() + offset, losses, bytes, cudaMemcpyDeviceToHost, info);
        info.losses_transferred = detail::checked_add(info.losses_transferred, count);
        info.batch_count = detail::checked_add(info.batch_count, 1);
        offset = next;
    }
    resources.stop(pipeline);
    if (offset != r.scenarios || info.losses_transferred != r.scenarios
        || (!common && info.normals_generated != detail::normal_count(r.scenarios, false)))
        throw std::runtime_error("Hybrid scenario accounting mismatch");
    check(cudaStreamSynchronize(resources.stream), "Hybrid pipeline completion");
    check(cudaMemGetInfo(&info.free_with_pipeline_bytes, &info.total_vram_bytes), "Hybrid VRAM pipeline snapshot");
    const auto quantile_start = resources.diagnostics ? std::chrono::steady_clock::now()
                                                     : std::chrono::steady_clock::time_point{};
    std::sort(host_losses.begin(), host_losses.end());
    for (double confidence : r.confidence_levels)
        result.estimates.push_back({confidence, sorted_quantile(host_losses, confidence)});
    if (resources.diagnostics) resources.diagnostics->host_quantile_ms =
        std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - quantile_start).count();
}
std::string compiler_version() {
    return std::to_string(__CUDACC_VER_MAJOR__) + "." + std::to_string(__CUDACC_VER_MINOR__) + "." + std::to_string(__CUDACC_VER_BUILD__);
}
}
Result CudaEngine::run(const Request& r, const std::vector<double>* common) const {
    validate_model(r.model);
    detail::validate_cuda_counts(r.scenarios, r.confidence_levels.size());
    for (double c : r.confidence_levels)
        if (!std::isfinite(c) || c <= 0 || c >= 1)
            throw std::invalid_argument("Probability must be finite and in (0,1)");
    if (common && common->size() != r.scenarios)
        throw std::invalid_argument("Common input count must equal scenario count");
    if (mode_ != CudaMode::FullDevice && mode_ != CudaMode::Hybrid)
        throw std::invalid_argument("Invalid CUDA mode");
    if (mode_ == CudaMode::Hybrid) detail::hybrid_batch_size(r.scenarios, batch_size_, common != nullptr);
    else if (batch_size_ != 0) throw std::invalid_argument("Batch size requires hybrid CUDA mode");
    const auto start = std::chrono::steady_clock::now();
    Result result;
    {
        result.backend = "cuda";
        result.random_source = common ? "common-host-inputs" : "cuRAND/PHILOX4_32_10/normal-double";
        result.cuda.emplace();
        auto& info = *result.cuda;
        int count = 0;
        check(cudaGetDeviceCount(&count), "CUDA device discovery");
        if (count == 0) throw std::runtime_error("No CUDA device available");
        check(cudaSetDevice(0), "CUDA device selection");
        cudaDeviceProp properties{};
        check(cudaGetDeviceProperties(&properties, 0), "CUDA device properties");
        info.device_name = properties.name; info.compute_major = properties.major; info.compute_minor = properties.minor;
        info.compiler_version = compiler_version();
        info.curand_header_version = std::to_string(CURAND_VER_MAJOR) + "." + std::to_string(CURAND_VER_MINOR) + "." +
            std::to_string(CURAND_VER_PATCH) + "." + std::to_string(CURAND_VER_BUILD);
        info.runtime_header_version = CUDART_VERSION; info.cub_version = CUB_VERSION;
        check(cudaDriverGetVersion(&info.driver_api_version), "CUDA driver API version");
        check(cudaRuntimeGetVersion(&info.runtime_version), "CUDA runtime version");
        check_rng(curandGetVersion(&info.curand_runtime_version), "cuRAND runtime version");
        Resources resources;
        resources.initialize();
        if (diagnostics_) {
            info.diagnostics.emplace();
            resources.diagnostics = &*info.diagnostics;
        }
        if (mode_ == CudaMode::Hybrid) {
            hybrid_pipeline(r, common, batch_size_, resources, properties, result);
        } else {
            info.effective_batch_size = r.scenarios;
            info.batch_count = 1;
            const auto n = detail::checked_int(r.scenarios);
            const auto k = r.confidence_levels.size();
            const auto quantile_count = detail::checked_int(k);
            const auto blocks = detail::loss_blocks(r.scenarios, properties.maxGridSize[0],
                properties.maxThreadsDim[0], properties.maxThreadsPerBlock);
            std::vector<std::size_t> indices;
            for (double c : r.confidence_levels)
                indices.push_back(detail::quantile_index(c, r.scenarios));
            // Normal-double generation requires an even output count. Only N values are consumed.
            info.normals_allocated = detail::normal_count(r.scenarios, common != nullptr);
            const auto loss_bytes = detail::checked_multiply(r.scenarios, sizeof(double));
            const auto index_bytes = detail::checked_multiply(k, sizeof(std::size_t));
            const auto value_bytes = detail::checked_multiply(k, sizeof(double));
            // Storage-only query: typed null data pointers are not dereferenced by CUB.
            check(cub::DeviceRadixSort::SortKeys(nullptr, info.cub_temporary_bytes,
                static_cast<const double*>(nullptr), static_cast<double*>(nullptr), n, 0, 64,
                resources.stream), "CUB storage query");
            const auto workspace_bytes = (std::max)(info.cub_temporary_bytes, std::size_t{1});
            info.explicit_device_bytes = detail::explicit_device_bytes(info.normals_allocated,
                r.scenarios, k, info.cub_temporary_bytes);
            // Query after context/stream/events and workspace query, before any pipeline buffer.
            check(cudaMemGetInfo(&info.free_before_bytes, &info.total_vram_bytes), "VRAM preflight");
            info.allocation_budget_limit_bytes = detail::memory_budget_80pct(info.free_before_bytes);
            detail::require_memory_budget(info.explicit_device_bytes, info.free_before_bytes);
            auto normals = resources.allocate<double>(info.normals_allocated);
            auto losses = resources.allocate<double>(r.scenarios);
            auto sorted = resources.allocate<double>(r.scenarios);
            auto indices_device = resources.allocate<std::size_t>(k);
            auto values_device = resources.allocate<double>(k);
            auto invalid_device = resources.allocate<int>(1);
            auto workspace = resources.allocate<unsigned char>(workspace_bytes);
            const auto pipeline = resources.start(5);
            resources.copy(indices_device, indices.data(), index_bytes, cudaMemcpyHostToDevice, info);
            if (common) resources.copy(normals, common->data(), loss_bytes, cudaMemcpyHostToDevice, info);
            else {
                check_rng(curandCreateGenerator(&resources.generator, CURAND_RNG_PSEUDO_PHILOX4_32_10), "cuRAND device generator creation");
                check_rng(curandSetStream(resources.generator, resources.stream), "cuRAND stream selection");
                check_rng(curandSetPseudoRandomGeneratorSeed(resources.generator, r.seed), "cuRAND seed");
                resources.measure(1, [&] {
                    check_rng(curandGenerateNormalDouble(resources.generator, normals, info.normals_allocated, 0.0, 1.0), "cuRAND device normal generation");
                });
                info.normals_generated = info.normals_allocated;
            }
            resources.measure(0, [&] {
                check(cudaMemsetAsync(invalid_device, 0, sizeof(int), resources.stream), "Device error flag initialization");
            });
            resources.measure(2, [&] {
            losses_kernel<<<blocks, detail::cuda_loss_threads, 0, resources.stream>>>(r.model, normals, losses, n, invalid_device);
            check(cudaGetLastError(), "Loss kernel launch");
            });
            int invalid = 0;
            resources.copy(&invalid, invalid_device, sizeof(int), cudaMemcpyDeviceToHost, info);
            if (invalid == 1) throw std::invalid_argument("Normal input must be finite");
            if (invalid) throw std::overflow_error("CUDA scenario loss overflow");
            resources.measure(3, [&] {
                check(cub::DeviceRadixSort::SortKeys(workspace, info.cub_temporary_bytes, losses, sorted, n, 0, 64, resources.stream), "CUB device radix sort");
            });
            resources.measure(4, [&] {
            quantile_kernel<<<1, 32, 0, resources.stream>>>(sorted, indices_device, values_device, quantile_count);
            check(cudaGetLastError(), "Device nearest-rank gather launch");
            });
            std::vector<double> values(k);
            resources.copy(values.data(), values_device, value_bytes, cudaMemcpyDeviceToHost, info);
            resources.stop(pipeline);
            check(cudaStreamSynchronize(resources.stream), "Pipeline completion");
            check(cudaMemGetInfo(&info.free_with_pipeline_bytes, &info.total_vram_bytes), "VRAM pipeline snapshot");
            for (std::size_t i = 0; i < k; ++i) {
                if (!std::isfinite(values[i])) throw std::runtime_error("Nonfinite CUDA quantile");
                result.estimates.push_back({r.confidence_levels[i], values[i]});
            }
        }
        resources.collect();
        resources.release(true);
    }
    result.end_to_end_ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
    return result;
}
} // namespace mc
