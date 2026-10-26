#include "mc/portfolio.hpp"
#include "mc/cuda.hpp"
#include "mc/detail/cuda_plan.hpp"
#include <cuda_runtime.h>
#include <curand.h>
#include <algorithm>
#include <cmath>
#include <iostream>
#include <limits>
#include <stdexcept>

namespace {
void check(bool ok, const char* message) { if (!ok) throw std::runtime_error(message); }
template<class F> void rejects(F op) {
    bool caught = false; try { op(); } catch (const std::exception&) { caught = true; }
    check(caught, "Expected rejection");
}
mc::Portfolio fixture(int a, double rho = .2) {
    mc::Portfolio p; p.unit="USD"; p.horizon=.5;
    for (int i=0;i<a;++i) p.assets.push_back({"A"+std::to_string(i),2.+i,100.-10*i,.03+.01*i,.15+.03*i});
    for (int i=0;i<a;++i) for (int j=0;j<a;++j) p.correlation.push_back(i==j?1:rho);
    return p;
}
void agrees(const mc::Result& x, const mc::Result& y, double v0) {
    check(x.estimates.size()==y.estimates.size(), "Estimate size");
    for (std::size_t i=0;i<x.estimates.size();++i)
        check(x.estimates[i].confidence==y.estimates[i].confidence &&
              std::abs(x.estimates[i].var-y.estimates[i].var)<=1e-10*v0, "Portfolio tolerance 1e-10*V0");
}
// Test-only cuRAND call concatenation. Native production never copies normals to host.
std::vector<double> reference(std::size_t n, std::size_t a, std::size_t b, std::uint64_t seed) {
    struct Guard {
        curandGenerator_t g=nullptr; double* d=nullptr;
        ~Guard() { if(g) curandDestroyGenerator(g); if(d) cudaFree(d); }
    } guard;
    check(cudaMalloc(reinterpret_cast<void**>(&guard.d),(b*a+b*a%2)*sizeof(double))==cudaSuccess,"Reference allocation");
    check(curandCreateGenerator(&guard.g,CURAND_RNG_PSEUDO_PHILOX4_32_10)==CURAND_STATUS_SUCCESS,"Reference RNG");
    check(curandSetPseudoRandomGeneratorSeed(guard.g,seed)==CURAND_STATUS_SUCCESS,"Reference seed");
    std::vector<double> z(n*a);
    for(std::size_t o=0;o<n;) {
        const auto count=std::min(b,n-o), payload=count*a;
        check(curandGenerateNormalDouble(guard.g,guard.d,payload+payload%2,0,1)==CURAND_STATUS_SUCCESS,"Reference generation");
        check(cudaMemcpy(z.data()+o*a,guard.d,payload*sizeof(double),cudaMemcpyDeviceToHost)==cudaSuccess,"Reference copy");
        o+=count;
    }
    return z;
}
}
int main() {
    try {
        std::size_t cases=0; double max_difference=0;
        for(int a:{1,2,3,5}) for(std::size_t n:{1,11,12,255,256,257}) {
            auto p=fixture(a); mc::Request r; r.portfolio=&p; r.scenarios=n;
            r.confidence_levels={.95,.99,.95};
            std::vector<double> z(n*a);
            for(std::size_t i=0;i<z.size();++i) z[i]=(static_cast<int>(i*37%101)-50)/10.;
            const auto saved=z;
            const auto cpu=mc::SerialEngine{}.run(r,&z), full=mc::CudaEngine{}.run(r,&z);
            const auto v0=mc::prepare_portfolio(p).initial_value;
            for(std::size_t b:{1,2,3,4,11,256,999}) {
                const auto actual=mc::CudaEngine(mc::CudaMode::Hybrid,b).run(r,&z);
                agrees(cpu,actual,v0); agrees(full,actual,v0);
                for(std::size_t i=0;i<cpu.estimates.size();++i)
                    max_difference=std::max(max_difference,std::abs(cpu.estimates[i].var-actual.estimates[i].var));
                check(z==saved,"Caller preservation");
                const auto& m=*actual.cuda; const auto effective=std::min(b,n), batches=(n+effective-1)/effective;
                check(m.effective_batch_size==effective && m.batch_count==batches && m.portfolio_assets==a,"Partition metadata");
                check(m.host_to_device_bytes==n*a*sizeof(double) && m.normals_generated==0 &&
                    m.losses_transferred==n && m.host_loss_bytes==n*sizeof(double) &&
                    m.device_to_host_bytes==n*sizeof(double)+batches*sizeof(int) &&
                    m.explicit_device_bytes==(effective*a+effective)*sizeof(double)+sizeof(int),"Common resource accounting");
                ++cases;
            }
            // Independent native payload oracle and exact repeat for every asset/launch size.
            for(std::size_t b:{1,3,256,999}) {
                const auto effective=std::min(b,n);
                const auto normals=reference(n,a,effective,r.seed);
                const mc::CudaEngine engine(mc::CudaMode::Hybrid,b);
                const auto actual=engine.run(r), repeated=engine.run(r);
                agrees(mc::SerialEngine{}.run(r,&normals),actual,v0);
                for(std::size_t i=0;i<actual.estimates.size();++i)
                    check(actual.estimates[i].var==repeated.estimates[i].var,"Native exact repeat");
                std::size_t generated=0;
                for(std::size_t o=0;o<n;) {const auto c=std::min(effective,n-o); generated+=c*a+(c*a)%2; o+=c;}
                const auto& m=*actual.cuda;
                check(m.normals_generated==generated && m.normals_allocated==effective*a+(effective*a)%2 &&
                    m.host_to_device_bytes==0 && m.losses_transferred==n,"Native padding/accounting");
                ++cases;
            }
        }
        auto p=fixture(3,-.3); mc::Request r; r.portfolio=&p; r.scenarios=11;
        const mc::CudaEngine engine(mc::CudaMode::Hybrid,3);
        std::vector<double> z(33,.4);
        agrees(mc::SerialEngine{}.run(r,&z),engine.run(r,&z),790);
        p.horizon=0; check(engine.run(r).estimates[0].var==0,"T=0");
        p.horizon=.5; for(auto& a:p.assets) {a.volatility=0; a.drift=.1;}
        for(const auto& e:engine.run(r).estimates)
            check(std::abs(e.var-790*(1-std::exp(.05)))<1e-10*790 && e.var<0,"Negative deterministic VaR");
        p=fixture(1); p.horizon=1; p.assets[0]={"ONE",1,100,.05,.2}; r.scenarios=100;
        // 96 zero losses and four losses of 80: global 95%=0, 99%=80.
        // Two 50-scenario batch 95% values are 0 and 80: their average 40 is wrong.
        z.assign(100,-.15); for(int i=96;i<100;++i) z[i]=(std::log(.2)-.03)/.2;
        auto actual=mc::CudaEngine(mc::CudaMode::Hybrid,50).run(r,&z);
        check(std::abs(actual.estimates[0].var)<1e-10 && std::abs(actual.estimates[1].var-80)<1e-10,"Independent global rank oracle");
        auto single=r; single.portfolio=nullptr;
        agrees(mc::CudaEngine(mc::CudaMode::Hybrid,50).run(single,&z),actual,100);
        z.pop_back(); rejects([&]{engine.run(r,&z);}); z.push_back(0);
        for(auto index:{0,50,99}) {z[index]=std::numeric_limits<double>::infinity(); rejects([&]{engine.run(r,&z);}); z[index]=0;}
        z.back()=1e308; rejects([&]{engine.run(r,&z);}); z.back()=0;
        agrees(mc::SerialEngine{}.run(r,&z),engine.run(r,&z),100);
        for(std::size_t b:{0,10000001}) rejects([&]{mc::CudaEngine(mc::CudaMode::Hybrid,b).run(r);});
        rejects([&]{mc::CudaEngine(mc::CudaMode::FullDevice,1).run(r);});
        r.scenarios=0; rejects([&]{engine.run(r);}); r.scenarios=10000001; rejects([&]{engine.run(r);});
        r.scenarios=100; r.confidence_levels={.5}; rejects([&]{engine.run(r);});
        rejects([]{mc::detail::checked_multiply((std::numeric_limits<std::size_t>::max)(),5);});
        rejects([]{mc::detail::checked_add((std::numeric_limits<std::size_t>::max)(),1);});
        rejects([]{mc::detail::require_memory_budget(81,100);});
        std::cout.precision(17);
        std::cout<<"{\"cases_passed\":"<<cases<<",\"maximum_common_difference\":"<<max_difference
            <<",\"absolute_tolerance_fraction_V0\":1e-10,\"global_rank_oracle\":true,\"native_repeat_and_payload\":true,\"errors_and_recovery\":true}\n";
        return 0;
    } catch(const std::exception& e) {std::cerr<<e.what()<<'\n'; return 1;}
}
