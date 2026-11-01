#include "mc/core.hpp"
#include "mc/detail/experimental_selection.hpp"
#include <algorithm>
#include <cmath>
#include <iostream>
#include <limits>
#include <random>
#include <stdexcept>

namespace {
void check(bool ok) { if (!ok) throw std::runtime_error("Selection regression"); }
void compare(const std::vector<double>& input, const std::vector<double>& c) {
    auto sorted=input, partitioned=input;
    std::sort(sorted.begin(), sorted.end());
    const auto actual=mc::experimental::select_quantiles_in_place(partitioned,c);
    check(actual.size()==c.size());
    for (std::size_t i=0;i<c.size();++i)
        check(actual[i]==mc::sorted_quantile(sorted,c[i]));
    std::sort(partitioned.begin(),partitioned.end());
    check(partitioned==sorted); // No lost/duplicated sample.
}
template<class F> void rejects(F action) {
    bool rejected=false;
    try {action();} catch(const std::invalid_argument&) {rejected=true;}
    check(rejected);
}
}
int main() {
    try {
        const std::vector<double> c{.99,.95,.5,.99,.01};
        for (auto values : {std::vector<double>{-5}, {-5,-4}, {-3,0,4,8,8},
                           {9,8,7,6,5,4,3,2,1}, {-10,-9,-8,-7},
                           {-0.0,0.0,-0.0,0.0}, {2,2,2,2,2}}) compare(values,c);
        compare({-1e300,-1e-300,1e-300,1e300},c);
        compare({std::nextafter(1.,0.),1.,std::nextafter(1.,2.)},c);
        std::mt19937_64 rng(123);
        for (std::size_t n : {3,17,99,100,101,4095,4096,4097,10003,100000}) {
            std::vector<double> values(n);
            for (auto& v:values) v=static_cast<double>(rng()%1001)-700.;
            compare(values,c);
            std::sort(values.begin(),values.end());compare(values,{.95,.99});
            std::reverse(values.begin(),values.end());compare(values,c);
        }
        std::vector<double> values{3,-1,2};
        const auto original=values;
        for (double c_bad : {0.,1.,-1.,std::numeric_limits<double>::infinity(),
                             std::numeric_limits<double>::quiet_NaN()}) {
            rejects([&]{mc::experimental::select_quantiles_in_place(values,{.95,c_bad});});
            check(values==original); // Rejected confidence cannot permute losses.
        }
        rejects([&]{mc::experimental::select_quantiles_in_place(values,{});});
        std::vector<double> empty;
        rejects([&]{mc::experimental::select_quantiles_in_place(empty,{.95});});
        std::cout<<"PASS: exact nearest-rank oracle, repeated ranks/confidences, adversarial samples and invalid requests\n";
    } catch(const std::exception& e) {std::cerr<<e.what()<<'\n';return 1;}
}
