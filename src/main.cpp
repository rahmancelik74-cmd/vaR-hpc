#include "mc/core.hpp"
#include "mc/data.hpp"
#include "mc/output.hpp"
#include "mc/version.hpp"
#ifdef MC_HAS_OPENMP
#include "mc/openmp.hpp"
#endif
#ifdef MC_HAS_CUDA
#include "mc/cuda.hpp"
#endif
#include <iomanip>
#include <iostream>
#include <limits>
#include <memory>
#include <stdexcept>

namespace {
std::uint64_t positive_integer(const std::string& text) {
    if (text.empty() || text.find_first_not_of("0123456789") != std::string::npos)
        throw std::invalid_argument("Expected an unsigned integer");
    std::size_t used = 0;
    const auto value = std::stoull(text, &used);
    if (used != text.size()) throw std::invalid_argument("Invalid integer");
    return value;
}
}
int main(int argc, char** argv) {
    try {
        if (argc == 2 && std::string(argv[1]) == "--version") {
            std::cout << "mc_var " MC_APPLICATION_VERSION " (CSV support enabled)\n";
            return 0;
        }
        const bool json_mode = argc > 1 && std::string(argv[argc - 1]) == "--json";
        if (json_mode) --argc;
        std::string backend = "serial";
        int threads = 0;
        bool backend_seen = false, threads_seen = false;
        std::vector<char*> positional{argv[0]};
        for (int i = 1; i < argc; ++i) {
            const std::string option = argv[i];
            if (option == "--backend") {
                if (backend_seen || i + 1 >= argc)
                    throw std::invalid_argument("Missing or duplicate --backend");
                backend_seen = true;
                backend = argv[++i];
                if (backend != "serial" && backend != "openmp" && backend != "cuda")
                    throw std::invalid_argument("Backend must be serial, openmp or cuda");
            } else if (option == "--threads") {
                if (threads_seen || i + 1 >= argc)
                    throw std::invalid_argument("Missing or duplicate --threads");
                threads_seen = true;
                const auto value = positive_integer(argv[++i]);
                if (value == 0 || value > static_cast<std::uint64_t>((std::numeric_limits<int>::max)()))
                    throw std::invalid_argument("Threads must be a positive int");
                threads = static_cast<int>(value);
            } else {
                if (option.rfind("--", 0) == 0 &&
                    !(option == "--csv" && positional.size() == 1))
                    throw std::invalid_argument("Unknown, misplaced or duplicate option");
                positional.push_back(argv[i]);
            }
        }
        if (threads_seen && backend != "openmp")
            throw std::invalid_argument("--threads requires the openmp backend");
#ifndef MC_HAS_OPENMP
        if (backend == "openmp")
            throw std::invalid_argument("OpenMP backend unavailable; configure MC_ENABLE_OPENMP=ON");
#endif
#ifndef MC_HAS_CUDA
        if (backend == "cuda")
            throw std::invalid_argument("CUDA backend unavailable; configure MC_ENABLE_CUDA=ON");
#endif
        argc = static_cast<int>(positional.size());
        argv = positional.data();
        const bool csv_mode = argc > 1 && std::string(argv[1]) == "--csv";
        const std::string usage = "Usage: mc_var [scenarios] [seed] OR mc_var --csv file [scenarios] [seed] [horizon_trading_days] [trading_days_per_year]; options: --backend serial|openmp|cuda --threads positive_integer (append --json for structured output)";
        if ((!csv_mode && argc > 3) || (csv_mode && (argc < 3 || argc > 7)))
            throw std::invalid_argument(usage);
        mc::Request request;
        const int first = csv_mode ? 3 : 1;
        if (argc > first) {
            const auto n = positive_integer(argv[first]);
            if (n > std::numeric_limits<std::size_t>::max())
                throw std::invalid_argument("Scenario count too large");
            request.scenarios = static_cast<std::size_t>(n);
        }
        if (argc > first + 1) request.seed = positive_integer(argv[first + 1]);
        if (request.scenarios == 0)
            throw std::invalid_argument("Scenario count must be positive");
        mc::CsvMetadata metadata;
        std::cout << std::setprecision(10);
        if (csv_mode) {
            const auto horizon_days = argc > 5 ? positive_integer(argv[5]) : 10;
            const auto days_per_year = argc > 6 ? positive_integer(argv[6]) : 252;
            const auto prices = mc::load_prices_csv(argv[2]);
            const auto fitted = mc::calibrate(prices, static_cast<double>(days_per_year),
                                             static_cast<double>(horizon_days));
            request.model = fitted.model;
            metadata = {prices.size(), fitted.returns_count, prices.front().date,
                        prices.back().date, fitted.mean_log_return,
                        fitted.sample_log_variance, horizon_days, days_per_year};
            if (!json_mode) std::cout << "CSV calibration under GBM; no claim of market predictive validity.\n"
                      << "file=" << argv[2] << " observations=" << prices.size()
                      << " returns=" << fitted.returns_count
                      << " date_start=" << prices.front().date
                      << " date_end=" << prices.back().date << '\n'
                      << "mean_log_return=" << fitted.mean_log_return
                      << " sample_log_variance=" << fitted.sample_log_variance << '\n'
                      << "V0=" << request.model.initial_value
                      << " mu_annual=" << request.model.drift
                      << " sigma_annual=" << request.model.volatility
                      << " T_years=" << request.model.horizon
                      << " horizon_trading_days=" << horizon_days
                      << " trading_days_per_year=" << days_per_year << '\n';
        } else if (!json_mode) {
            std::cout << "Synthetic fixed-parameter demo; not market validation or a benchmark campaign.\n";
        }
        std::unique_ptr<mc::Engine> engine;
#ifdef MC_HAS_CUDA
        if (backend == "cuda") engine = std::make_unique<mc::CudaEngine>();
        else
#endif
#ifdef MC_HAS_OPENMP
        if (backend == "openmp") engine = std::make_unique<mc::OpenMPEngine>(threads);
        else
#endif
            engine = std::make_unique<mc::SerialEngine>();
        const auto result = engine->run(request);
        if (json_mode) {
            mc::write_run_json(std::cout, request, result, csv_mode ? &metadata : nullptr);
            return 0;
        }
        std::cout << "backend=" << result.backend << " N=" << request.scenarios
                  << " seed=" << request.seed
                  << " requested_threads=" << result.requested_threads
                  << " threads_used=" << result.threads_used << '\n'
                  << std::setprecision(10);
        for (const auto& e : result.estimates) {
            const auto reference = mc::analytical_var(request.model, e.confidence);
            std::cout << "confidence=" << e.confidence << " mc_var=" << e.var
                      << " analytical_var=" << reference
                      << " difference=" << e.var - reference << '\n';
        }
        std::cout << "end_to_end_ms=" << result.end_to_end_ms << '\n';
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << '\n';
        return 1;
    }
}
