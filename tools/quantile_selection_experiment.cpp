#include "mc/core.hpp"
#include "mc/data.hpp"
#include "mc/detail/experimental_selection.hpp"
#ifdef MC_SELECTION_HAS_OPENMP
#include "mc/openmp.hpp"
#endif
#include <algorithm>
#include <chrono>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <locale>
#include <random>
#include <stdexcept>

namespace {
void require(bool ok,const char* message) {if(!ok) throw std::runtime_error(message);}
std::uint64_t integer(const std::string& text) {
    if(text.empty() || text.find_first_not_of("0123456789")!=std::string::npos)
        throw std::invalid_argument("Expected unsigned decimal integer");
    std::size_t used=0;auto n=std::stoull(text,&used);
    require(used==text.size(),"Invalid integer");return n;
}
std::vector<double> generate(const mc::Request& r) {
    std::vector<double> losses(r.scenarios);
    std::mt19937_64 rng(r.seed);
    std::normal_distribution<double> normal(0.,1.);
    for(auto& loss:losses) loss=mc::scenario_loss(r.model,normal(rng));
    return losses;
}
std::vector<double> full_sort(std::vector<double>& losses,const std::vector<double>& c) {
    std::sort(losses.begin(),losses.end());
    std::vector<double> values;
    for(double confidence:c) values.push_back(mc::sorted_quantile(losses,confidence));
    return values;
}
std::uint64_t fingerprint(const std::vector<double>& losses) {
    std::uint64_t h=UINT64_C(14695981039346656037);
    for(double v:losses) {
        unsigned char bytes[sizeof(double)];std::memcpy(bytes,&v,sizeof v);
        for(auto b:bytes) {h^=b;h*=UINT64_C(1099511628211);}
    }
    return h; // Diagnostic FNV-1a on native double bytes, not a security hash.
}
void validate(mc::Request r) {
    const auto native_n=r.scenarios;
    std::vector<double> means(2,0.);
    std::vector<std::vector<double>> native_values;
    for(auto seed : {UINT64_C(42),UINT64_C(123),UINT64_C(456),UINT64_C(789),UINT64_C(2026)}) {
        r.seed=seed;
        auto losses=generate(r);
        const auto selected=mc::experimental::select_quantiles_in_place(losses,r.confidence_levels);
        const auto baseline=mc::SerialEngine{}.run(r);
        for(std::size_t i=0;i<2;++i) {
            require(selected[i]==baseline.estimates[i].var,"Native serial equality failed");
            means[i]+=selected[i]/5.;
        }
        native_values.push_back(selected);
    }
    if(r.scenarios==10000000) for(std::size_t i=0;i<2;++i) {
        const double analytical=mc::analytical_var(r.model,r.confidence_levels[i]);
        const double tolerance=.01*(std::max)(std::abs(analytical),.01*r.model.initial_value);
        require(std::abs(means[i]-analytical)<=tolerance,"Five-seed analytical acceptance failed");
    }
    r.scenarios=10003;
    std::vector<double> common(r.scenarios),losses(r.scenarios);
    std::mt19937_64 rng(2026);std::normal_distribution<double> normal(0.,1.);
    for(std::size_t i=0;i<r.scenarios;++i) {common[i]=normal(rng);losses[i]=mc::scenario_loss(r.model,common[i]);}
    const auto copy=common;
    const auto selected=mc::experimental::select_quantiles_in_place(losses,r.confidence_levels);
    auto compare=[&](const mc::Result& result) {
        for(std::size_t i=0;i<2;++i) require(selected[i]==result.estimates[i].var,"Common-input equality failed");
        require(common==copy,"Caller common inputs mutated");
    };
    compare(mc::SerialEngine{}.run(r,&common));
#ifdef MC_SELECTION_HAS_OPENMP
    for(int t : {1,2,4,8,10}) compare(mc::OpenMPEngine(t).run(r,&common));
#endif
    std::cout<<"{\"validation\":\"passed\",\"native_seeds\":[42,123,456,789,2026],\"native_scenarios\":"
             <<native_n<<",\"analytical_acceptance_checked\":"<<(native_n==10000000 ? "true":"false")
             <<",\"mean_var95\":"<<means[0]<<",\"mean_var99\":"<<means[1]
             <<",\"initial_value\":"<<r.model.initial_value
             <<",\"analytical_var95\":"<<mc::analytical_var(r.model,.95)
             <<",\"analytical_var99\":"<<mc::analytical_var(r.model,.99)
             <<",\"native_values\":[";
    for(std::size_t i=0;i<native_values.size();++i) {
        if(i) std::cout<<',';
        std::cout<<'['<<native_values[i][0]<<','<<native_values[i][1]<<']';
    }
    std::cout<<"],\"common_input_scenarios\":10003,\"common_var95\":"<<selected[0]
             <<",\"common_var99\":"<<selected[1]
#ifdef MC_SELECTION_HAS_OPENMP
             <<",\"common_openmp_threads\":[1,2,4,8,10]"
#else
             <<",\"common_openmp_threads\":[]"
#endif
             <<",\"exact_equality\":true,\"common_inputs_unchanged\":true}\n";
}
}
int main(int argc,char** argv) {
    try {
        std::cout.imbue(std::locale::classic());std::cout<<std::setprecision(17);
        if(argc==4 && std::string(argv[1])=="--validate") {
            mc::Request r;r.model=mc::calibrate(mc::load_prices_csv(argv[2]),252,10).model;
            r.scenarios=static_cast<std::size_t>(integer(argv[3]));
            require(r.scenarios>0 && r.scenarios<=10000000,"Scenario range 1..10000000 required");
            validate(r);return 0;
        }
        if(argc!=6 || std::string(argv[1])!="--csv")
            throw std::invalid_argument("Use --csv FILE N SEED sort|nth or --validate FILE N");
        mc::Request r;r.model=mc::calibrate(mc::load_prices_csv(argv[2]),252,10).model;
        r.scenarios=static_cast<std::size_t>(integer(argv[3]));r.seed=integer(argv[4]);
        require(r.scenarios>0 && r.scenarios<=10000000,"Scenario range 1..10000000 required");
        const std::string method=argv[5];require(method=="sort" || method=="nth","Unknown selection method");
        auto losses=generate(r);const auto hash=fingerprint(losses);
        const auto begin=std::chrono::steady_clock::now();
        const auto values=method=="sort" ? full_sort(losses,r.confidence_levels)
            : mc::experimental::select_quantiles_in_place(losses,r.confidence_levels);
        const auto end=std::chrono::steady_clock::now();
        const auto elapsed=std::chrono::duration<double,std::milli>(end-begin).count();
        std::cout<<"{\"schema_version\":1,\"scope\":\"quantile-stage-only\",\"method\":\""<<method
          <<"\",\"scenarios\":"<<r.scenarios<<",\"seed\":\""<<r.seed<<"\",\"input_loss_fnv1a64\":\""<<std::hex<<hash<<std::dec
          <<"\",\"quantile_ms\":"<<elapsed<<",\"initial_value\":"<<r.model.initial_value
          <<",\"drift\":"<<r.model.drift<<",\"volatility\":"<<r.model.volatility<<",\"horizon\":"<<r.model.horizon
          <<",\"estimates\":[{\"confidence\":0.95,\"var\":"<<values[0]<<"},{\"confidence\":0.99,\"var\":"<<values[1]<<"}]}\n";
    } catch(const std::exception& e) {std::cerr<<"Experiment error: "<<e.what()<<'\n';return 1;}
}
