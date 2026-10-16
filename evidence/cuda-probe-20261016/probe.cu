#include <cuda_runtime.h>
#include <cstdlib>
#include <iostream>
#include <vector>

void check(cudaError_t result, const char* operation) {
    if (result != cudaSuccess) {
        std::cerr << operation << ": "
                  << cudaGetErrorString(result) << '\n';
        std::exit(EXIT_FAILURE);
    }
}

__global__ void double_values(int* values, int count) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < count) {
        values[i] *= 2;
    }
}

int main() {
    int count = 0;
    check(cudaGetDeviceCount(&count), "Device discovery");
    if (count == 0) {
        std::cerr << "No CUDA device found.\n";
        return EXIT_FAILURE;
    }

    check(cudaSetDevice(0), "Device selection");
    cudaDeviceProp properties{};
    check(cudaGetDeviceProperties(&properties, 0), "Device properties");

    int driver = 0;
    int runtime = 0;
    check(cudaDriverGetVersion(&driver), "Driver version");
    check(cudaRuntimeGetVersion(&runtime), "Runtime version");

    std::cout << "GPU: " << properties.name << '\n'
              << "Compute capability: " << properties.major
              << '.' << properties.minor << '\n'
              << "VRAM MiB: "
              << properties.totalGlobalMem / (1024ULL * 1024ULL) << '\n'
              << "Driver API version: " << driver << '\n'
              << "Runtime version: " << runtime << '\n';

    constexpr int n = 1024;
    std::vector<int> values(n);
    for (int i = 0; i < n; ++i) {
        values[i] = i;
    }

    int* device = nullptr;
    const size_t bytes = values.size() * sizeof(int);
    check(cudaMalloc(reinterpret_cast<void**>(&device), bytes), "Allocation");
    check(cudaMemcpy(device, values.data(), bytes, cudaMemcpyHostToDevice),
          "Host-to-device copy");

    double_values<<<(n + 255) / 256, 256>>>(device, n);
    check(cudaGetLastError(), "Kernel launch");
    check(cudaDeviceSynchronize(), "Kernel execution");

    check(cudaMemcpy(values.data(), device, bytes, cudaMemcpyDeviceToHost),
          "Device-to-host copy");
    check(cudaFree(device), "Device cleanup");

    for (int i = 0; i < n; ++i) {
        if (values[i] != 2 * i) {
            std::cerr << "FAIL: incorrect result at index " << i << '\n';
            return EXIT_FAILURE;
        }
    }

    std::cout << "PASS: all 1024 GPU results are correct.\n";
    return EXIT_SUCCESS;
}
