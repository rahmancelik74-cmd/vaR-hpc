#include "mc/cuda.hpp"
#include <cmath>
#include <iostream>
#include <stdexcept>

void require(bool value) { if (!value) throw std::runtime_error("CUDA diagnostic contract failed"); }
int main() {
    try {
        for (auto mode : {mc::CudaMode::FullDevice, mc::CudaMode::Hybrid}) {
            const auto batch = mode == mc::CudaMode::Hybrid ? 65535 : 0;
            mc::Request r; r.scenarios = 100001;
            const auto plain = mc::CudaEngine(mode, batch).run(r);
            const auto measured = mc::CudaEngine(mode, batch, true).run(r);
            require(!plain.cuda->diagnostics && measured.cuda->diagnostics.has_value());
            for (std::size_t i = 0; i < plain.estimates.size(); ++i)
                require(plain.estimates[i].var == measured.estimates[i].var);
            const auto& d = *measured.cuda->diagnostics;
            const auto batches = measured.cuda->batch_count;
            require(d.initialization_intervals == batches && d.rng_intervals == batches && d.loss_intervals == batches);
            require(d.cub_intervals == (batch ? 0 : 1) && d.gather_intervals == (batch ? 0 : 1));
            const auto sum = d.initialization_ms + d.rng_ms + d.loss_ms + d.cub_ms + d.gather_ms;
            require(std::isfinite(sum) && sum >= 0 && std::isfinite(d.pipeline_span_ms) && d.pipeline_span_ms + 1e-5 >= sum);
            require(std::isfinite(d.host_quantile_ms) && d.host_quantile_ms >= 0 && (batch || d.host_quantile_ms == 0));
            // Common-input diagnostics must report zero RNG intervals.
            r.scenarios = 17; std::vector<double> normals(17, 0.0);
            const auto common = mc::CudaEngine(mode, batch, true).run(r, &normals);
            require(common.cuda->diagnostics->rng_intervals == 0);
        }
        std::cout << "CUDA diagnostic equivalence and scope checks passed\n";
    } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
