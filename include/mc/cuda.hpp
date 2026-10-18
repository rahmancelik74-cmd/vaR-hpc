#pragma once
#include "mc/core.hpp"

namespace mc {
enum class CudaMode { FullDevice, Hybrid };
// Full-device path, 1 through 10000000 scenarios, subject to memory preflight.
class CudaEngine final : public Engine {
public:
    explicit CudaEngine(CudaMode mode = CudaMode::FullDevice, std::size_t batch_size = 0)
        : mode_(mode), batch_size_(batch_size) {}
    Result run(const Request& request,
               const std::vector<double>* common_normals = nullptr) const override;
private:
    CudaMode mode_;
    std::size_t batch_size_;
};
} // namespace mc
