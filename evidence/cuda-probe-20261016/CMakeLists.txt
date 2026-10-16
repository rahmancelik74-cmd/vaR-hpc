cmake_minimum_required(VERSION 3.24)
project(cuda_probe LANGUAGES CXX CUDA)
add_executable(cuda_probe probe.cu)
set_target_properties(cuda_probe PROPERTIES
    CXX_STANDARD 17
    CUDA_STANDARD 17
    CUDA_ARCHITECTURES native
)
