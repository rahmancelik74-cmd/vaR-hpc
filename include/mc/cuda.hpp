#pragma once
#include "mc/core.hpp"

namespace mc {
// Full-device path, 1 through 10000000 scenarios, subject to memory preflight.
class CudaEngine final : public Engine {
public:
    Result run(const Request& request,
               const std::vector<double>* common_normals = nullptr) const override;
};
} // namespace mc
