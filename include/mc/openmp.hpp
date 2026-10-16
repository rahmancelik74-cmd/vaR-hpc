#pragma once
#include "mc/core.hpp"

namespace mc {
class OpenMPEngine final : public Engine {
public:
    explicit OpenMPEngine(int requested_threads = 0);
    Result run(const Request& request,
               const std::vector<double>* common_normals = nullptr) const override;
private:
    int requested_threads_;
};
} // namespace mc
