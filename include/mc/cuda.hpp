#pragma once
#include "mc/core.hpp"

namespace mc {
// Connectivity only. Explicit cap prevents accidental full-scale campaigns.
class CudaEngine final : public Engine {
public:
    Result run(const Request& request,
               const std::vector<double>* common_normals = nullptr) const override;
};
} // namespace mc
