#pragma once
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <stdexcept>
#include <vector>

namespace mc { namespace experimental {
// Research helper only. The caller owns losses and guarantees finite samples.
// Mutates their order. Does not replace any production Engine implementation.
inline std::vector<double> select_quantiles_in_place(
    std::vector<double>& losses, const std::vector<double>& confidences) {
    if (losses.empty() || confidences.empty())
        throw std::invalid_argument("Nonempty losses and confidences required");
    std::vector<std::size_t> ranks;
    for (double c : confidences) {
        if (!std::isfinite(c) || c <= 0 || c >= 1)
            throw std::invalid_argument("Probability must be finite and in (0,1)");
        const auto rank = static_cast<std::size_t>(
            std::ceil(c * static_cast<double>(losses.size()))) - 1;
        ranks.push_back((std::min)(rank, losses.size()-1));
    }
    auto unique = ranks;
    std::sort(unique.begin(), unique.end());
    unique.erase(std::unique(unique.begin(), unique.end()), unique.end());
    std::vector<double> selected;
    std::size_t first = 0;
    for (auto rank : unique) {
        // Preserve prior order statistics; partition only their upper suffix.
        std::nth_element(losses.begin()+first, losses.begin()+rank, losses.end());
        selected.push_back(losses[rank]);
        first = rank+1;
    }
    std::vector<double> result;
    for (auto rank : ranks)
        result.push_back(selected[static_cast<std::size_t>(
            std::lower_bound(unique.begin(), unique.end(), rank)-unique.begin())]);
    return result; // Original confidence order, including repeated ranks.
}
} } // namespace mc::experimental
