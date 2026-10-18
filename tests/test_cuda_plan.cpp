#include "mc/detail/cuda_plan.hpp"
#include <iostream>

namespace {
void check(bool ok, const char* label) {
    if (!ok) throw std::runtime_error(label);
}
template<class E, class F> void rejects(F f) {
    bool threw = false;
    try { f(); } catch (const E&) { threw = true; }
    check(threw, "Expected CUDA planning rejection");
}
}
int main() {
    try {
        using namespace mc::detail;
        const auto maximum = (std::numeric_limits<std::size_t>::max)();
        check(checked_add(maximum, 0) == maximum, "Addition boundary");
        check(checked_multiply(maximum, 1) == maximum, "Multiplication boundary");
        check(checked_multiply(maximum, 0) == 0, "Zero multiplication");
        rejects<std::overflow_error>([&]{ checked_add(maximum, 1); });
        rejects<std::overflow_error>([&]{ checked_multiply(maximum, 2); });
        check(checked_int(10000000) == 10000000, "Supported narrowing");
        rejects<std::overflow_error>([]{ checked_int(static_cast<std::size_t>(
            (std::numeric_limits<int>::max)()) + 1); });
        for (auto n : {1u, 5u, 256u, 257u, 10000u, 10001u, 10000000u}) {
            validate_cuda_counts(n, 16);
            check(normal_count(n, false) == n + n % 2, "Native even padding");
            check(normal_count(n, true) == n, "Common input has no padding");
            const auto blocks = loss_blocks(n, 2147483647, 1024, 1024);
            check(blocks == (n + 255) / 256, "Partial launch block");
        }
        rejects<std::invalid_argument>([]{ validate_cuda_counts(0, 2); });
        rejects<std::invalid_argument>([]{ validate_cuda_counts(10000001, 2); });
        rejects<std::invalid_argument>([&]{ validate_cuda_counts(maximum, 2); });
        rejects<std::invalid_argument>([]{ validate_cuda_counts(1, 0); });
        rejects<std::invalid_argument>([]{ validate_cuda_counts(1, 17); });
        rejects<std::overflow_error>([&]{ normal_count(maximum, false); });
        check(hybrid_batch_size(11,3,false)==4, "Odd native batch rounds up");
        check(hybrid_batch_size(11,3,true)==3, "Odd common batch remains exact");
        check(hybrid_batch_size(5,99,false)==5, "Batch larger than N clamps to N");
        check(hybrid_batch_size(11,1,false)==2, "Native single request uses pairs");
        check(hybrid_device_bytes(4,4)==8*sizeof(double)+sizeof(int), "Hybrid buffer budget");
        rejects<std::invalid_argument>([]{hybrid_batch_size(11,0,false);});
        rejects<std::invalid_argument>([&]{hybrid_batch_size(11,maximum,false);});
        rejects<std::overflow_error>([&]{hybrid_device_bytes(maximum,1);});
        rejects<std::overflow_error>([&]{host_loss_storage(maximum,maximum);});
        rejects<std::length_error>([]{host_loss_storage(11,10);});
        check(host_loss_storage(11,11)==11*sizeof(double), "Exact host loss storage");
        rejects<std::runtime_error>([]{require_memory_budget(hybrid_device_bytes(4,4),1);});
        // Hand-accounted arrays: 6 normals, two 5-loss arrays, 2 values/indices, flag, workspace.
        check(explicit_device_bytes(6, 5, 2, 17) == 18*sizeof(double)
            + 2*sizeof(std::size_t) + sizeof(int) + 17, "Exact device budget");
        check(explicit_device_bytes(5, 5, 2, 0) == 17*sizeof(double)
            + 2*sizeof(std::size_t) + sizeof(int) + 1, "Minimum workspace byte");
        rejects<std::overflow_error>([&]{ explicit_device_bytes(maximum, 1, 1, 1); });
        rejects<std::overflow_error>([&]{ explicit_device_bytes(1, maximum, 1, 1); });
        rejects<std::overflow_error>([&]{ explicit_device_bytes(1, 1, maximum, 1); });
        rejects<std::overflow_error>([&]{ explicit_device_bytes(1, 1, 1, maximum); });
        for (std::size_t free = 0; free < 100; ++free) {
            const auto limit = free * 4 / 5;
            check(memory_budget_80pct(free) == limit, "Exact 80 percent rounding");
            require_memory_budget(limit, free);
            rejects<std::runtime_error>([&]{ require_memory_budget(limit + 1, free); });
        }
        check(memory_budget_80pct(maximum) == maximum - maximum/5 - (maximum%5 != 0 ? 1 : 0),
            "Maximum-size budget is exact");
        require_memory_budget(memory_budget_80pct(maximum), maximum);
        rejects<std::runtime_error>([]{ loss_blocks(257, 1, 1024, 1024); });
        rejects<std::runtime_error>([]{ loss_blocks(1, 1, 255, 1024); });
        rejects<std::runtime_error>([]{ loss_blocks(1, 1, 1024, 255); });
        rejects<std::runtime_error>([]{ loss_blocks(0, 1, 1024, 1024); });
        rejects<std::overflow_error>([]{ loss_blocks(2147483647, 2147483647, 1024, 1024); });
        rejects<std::overflow_error>([&]{ loss_blocks(maximum, 2147483647, 1024, 1024); });
        check(quantile_index(.95, 10000000) == 9499999, "95 percent global rank");
        check(quantile_index(.99, 10000000) == 9899999, "99 percent global rank");
        check(quantile_index(.6, 5) == 2, "Nearest rank without interpolation");
        check(quantile_index(std::numeric_limits<double>::denorm_min(), 1) == 0, "Small probability");
        check(quantile_index(std::nextafter(1.0, 0.0), 10000000) == 9999999, "Upper rank boundary");
        rejects<std::invalid_argument>([]{ quantile_index(.95, 0); });
        rejects<std::invalid_argument>([]{ quantile_index(1, 5); });
        rejects<std::invalid_argument>([]{ quantile_index(std::numeric_limits<double>::quiet_NaN(), 5); });
        std::cout << "CUDA arithmetic, launch, rank and synthetic memory-budget checks passed.\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "CUDA planning test failure: " << e.what() << '\n'; return 1;
    }
}
