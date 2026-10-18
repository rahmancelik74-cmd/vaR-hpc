#include "mc/cuda.hpp"
#include "mc/detail/cuda_plan.hpp"
#include <cuda_runtime.h>
#include <curand.h>
#include <cub/device/device_radix_sort.cuh>
#include <cub/version.cuh>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <stdexcept>
#include <string>

namespace mc {
namespace {
void check(cudaError_t status, const char* operation) {
    if (status != cudaSuccess)
        throw std::runtime_error(std::string(operation) + ": " + cudaGetErrorString(status));
}
void check_rng(curandStatus_t status, const char* operation) {
    if (status != CURAND_STATUS_SUCCESS)
        throw std::runtime_error(std::string(operation) + ": cuRAND status " + std::to_string(status));
}
struct Resources {
    cudaStream_t stream = nullptr;
    cudaEvent_t begin = nullptr, end = nullptr;
    curandGenerator_t generator = nullptr;
    std::vector<void*> buffers;
    ~Resources() { release(false); }
    template<class T> T* allocate(std::size_t count) {
        void* pointer = nullptr;
        const auto bytes = detail::checked_multiply(count, sizeof(T));
        check(cudaMalloc(&pointer, bytes), "Device allocation");
        try { buffers.push_back(pointer); } catch (...) { cudaFree(pointer); throw; }
        return static_cast<T*>(pointer);
    }
    void initialize() {
        check(cudaStreamCreate(&stream), "Stream creation");
        check(cudaEventCreate(&begin), "Transfer event creation");
        check(cudaEventCreate(&end), "Transfer event creation");
    }
    void release(bool checked) {
        cudaError_t first = cudaSuccess;
        auto remember = [&](cudaError_t value) { if (first == cudaSuccess) first = value; };
        if (stream) remember(cudaStreamSynchronize(stream));
        curandStatus_t rng_status = CURAND_STATUS_SUCCESS;
        if (generator) { rng_status = curandDestroyGenerator(generator); generator = nullptr; }
        for (auto pointer : buffers) remember(cudaFree(pointer));
        buffers.clear();
        if (begin) { remember(cudaEventDestroy(begin)); begin = nullptr; }
        if (end) { remember(cudaEventDestroy(end)); end = nullptr; }
        if (stream) { remember(cudaStreamDestroy(stream)); stream = nullptr; }
        if (checked) { check_rng(rng_status, "cuRAND cleanup"); check(first, "CUDA cleanup"); }
    }
    void copy(void* to, const void* from, std::size_t bytes, cudaMemcpyKind kind, CudaMetadata& info) {
        check(cudaEventRecord(begin, stream), "Copy event start");
        check(cudaMemcpyAsync(to, from, bytes, kind, stream), "Device transfer");
        check(cudaEventRecord(end, stream), "Copy event stop");
        check(cudaEventSynchronize(end), "Copy synchronization");
        float elapsed = 0;
        check(cudaEventElapsedTime(&elapsed, begin, end), "Copy event elapsed time");
        if (kind == cudaMemcpyHostToDevice) {
            info.host_to_device_ms += elapsed;
            info.host_to_device_bytes = detail::checked_add(info.host_to_device_bytes, bytes);
        } else {
            info.device_to_host_ms += elapsed;
            info.device_to_host_bytes = detail::checked_add(info.device_to_host_bytes, bytes);
        }
    }
};
__global__ void losses_kernel(Model model, const double* normals, double* losses, int count, int* invalid) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < count) {
        const double z = normals[i];
        const double exponent = (model.drift - 0.5 * model.volatility * model.volatility) * model.horizon
            + model.volatility * sqrt(model.horizon) * z;
        const double loss = -model.initial_value * expm1(exponent);
        if (!isfinite(z)) atomicMax(invalid, 1);
        else if (!isfinite(loss)) atomicMax(invalid, 2);
        losses[i] = loss;
    }
}
__global__ void quantile_kernel(const double* sorted, const std::size_t* indices, double* values, int count) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < count) values[i] = sorted[indices[i]];
}
std::string compiler_version() {
    return std::to_string(__CUDACC_VER_MAJOR__) + "." + std::to_string(__CUDACC_VER_MINOR__) + "." + std::to_string(__CUDACC_VER_BUILD__);
}
}
Result CudaEngine::run(const Request& r, const std::vector<double>* common) const {
    validate_model(r.model);
    detail::validate_cuda_counts(r.scenarios, r.confidence_levels.size());
    for (double c : r.confidence_levels)
        if (!std::isfinite(c) || c <= 0 || c >= 1)
            throw std::invalid_argument("Probability must be finite and in (0,1)");
    if (common && common->size() != r.scenarios)
        throw std::invalid_argument("Common input count must equal scenario count");
    const auto start = std::chrono::steady_clock::now();
    Result result;
    {
        result.backend = "cuda";
        result.random_source = common ? "common-host-inputs" : "cuRAND/PHILOX4_32_10/normal-double";
        result.cuda.emplace();
        auto& info = *result.cuda;
        int count = 0;
        check(cudaGetDeviceCount(&count), "CUDA device discovery");
        if (count == 0) throw std::runtime_error("No CUDA device available");
        check(cudaSetDevice(0), "CUDA device selection");
        cudaDeviceProp properties{};
        check(cudaGetDeviceProperties(&properties, 0), "CUDA device properties");
        info.device_name = properties.name; info.compute_major = properties.major; info.compute_minor = properties.minor;
        info.compiler_version = compiler_version();
        info.curand_header_version = std::to_string(CURAND_VER_MAJOR) + "." + std::to_string(CURAND_VER_MINOR) + "." +
            std::to_string(CURAND_VER_PATCH) + "." + std::to_string(CURAND_VER_BUILD);
        info.runtime_header_version = CUDART_VERSION; info.cub_version = CUB_VERSION;
        check(cudaDriverGetVersion(&info.driver_api_version), "CUDA driver API version");
        check(cudaRuntimeGetVersion(&info.runtime_version), "CUDA runtime version");
        check_rng(curandGetVersion(&info.curand_runtime_version), "cuRAND runtime version");
        Resources resources;
        resources.initialize();
        const auto n = detail::checked_int(r.scenarios);
        const auto k = r.confidence_levels.size();
        const auto quantile_count = detail::checked_int(k);
        const auto blocks = detail::loss_blocks(r.scenarios, properties.maxGridSize[0],
            properties.maxThreadsDim[0], properties.maxThreadsPerBlock);
        std::vector<std::size_t> indices;
        for (double c : r.confidence_levels)
            indices.push_back(detail::quantile_index(c, r.scenarios));
        // Normal-double generation requires an even output count. Only N values are consumed.
        info.normals_allocated = detail::normal_count(r.scenarios, common != nullptr);
        const auto loss_bytes = detail::checked_multiply(r.scenarios, sizeof(double));
        const auto index_bytes = detail::checked_multiply(k, sizeof(std::size_t));
        const auto value_bytes = detail::checked_multiply(k, sizeof(double));
        // Storage-only query: typed null data pointers are not dereferenced by CUB.
        check(cub::DeviceRadixSort::SortKeys(nullptr, info.cub_temporary_bytes,
            static_cast<const double*>(nullptr), static_cast<double*>(nullptr), n, 0, 64,
            resources.stream), "CUB storage query");
        const auto workspace_bytes = (std::max)(info.cub_temporary_bytes, std::size_t{1});
        info.explicit_device_bytes = detail::explicit_device_bytes(info.normals_allocated,
            r.scenarios, k, info.cub_temporary_bytes);
        // Query after context/stream/events and workspace query, before any pipeline buffer.
        check(cudaMemGetInfo(&info.free_before_bytes, &info.total_vram_bytes), "VRAM preflight");
        info.allocation_budget_limit_bytes = detail::memory_budget_80pct(info.free_before_bytes);
        detail::require_memory_budget(info.explicit_device_bytes, info.free_before_bytes);
        auto normals = resources.allocate<double>(info.normals_allocated);
        auto losses = resources.allocate<double>(r.scenarios);
        auto sorted = resources.allocate<double>(r.scenarios);
        auto indices_device = resources.allocate<std::size_t>(k);
        auto values_device = resources.allocate<double>(k);
        auto invalid_device = resources.allocate<int>(1);
        auto workspace = resources.allocate<unsigned char>(workspace_bytes);
        resources.copy(indices_device, indices.data(), index_bytes, cudaMemcpyHostToDevice, info);
        if (common) resources.copy(normals, common->data(), loss_bytes, cudaMemcpyHostToDevice, info);
        else {
            check_rng(curandCreateGenerator(&resources.generator, CURAND_RNG_PSEUDO_PHILOX4_32_10), "cuRAND device generator creation");
            check_rng(curandSetStream(resources.generator, resources.stream), "cuRAND stream selection");
            check_rng(curandSetPseudoRandomGeneratorSeed(resources.generator, r.seed), "cuRAND seed");
            check_rng(curandGenerateNormalDouble(resources.generator, normals, info.normals_allocated, 0.0, 1.0), "cuRAND device normal generation");
        }
        check(cudaMemsetAsync(invalid_device, 0, sizeof(int), resources.stream), "Device error flag initialization");
        losses_kernel<<<blocks, detail::cuda_loss_threads, 0, resources.stream>>>(r.model, normals, losses, n, invalid_device);
        check(cudaGetLastError(), "Loss kernel launch");
        int invalid = 0;
        resources.copy(&invalid, invalid_device, sizeof(int), cudaMemcpyDeviceToHost, info);
        if (invalid == 1) throw std::invalid_argument("Normal input must be finite");
        if (invalid) throw std::overflow_error("CUDA scenario loss overflow");
        check(cub::DeviceRadixSort::SortKeys(workspace, info.cub_temporary_bytes, losses, sorted, n, 0, 64, resources.stream), "CUB device radix sort");
        quantile_kernel<<<1, 32, 0, resources.stream>>>(sorted, indices_device, values_device, quantile_count);
        check(cudaGetLastError(), "Device nearest-rank gather launch");
        std::vector<double> values(k);
        resources.copy(values.data(), values_device, value_bytes, cudaMemcpyDeviceToHost, info);
        check(cudaStreamSynchronize(resources.stream), "Pipeline completion");
        check(cudaMemGetInfo(&info.free_with_pipeline_bytes, &info.total_vram_bytes), "VRAM pipeline snapshot");
        for (std::size_t i = 0; i < k; ++i) {
            if (!std::isfinite(values[i])) throw std::runtime_error("Nonfinite CUDA quantile");
            result.estimates.push_back({r.confidence_levels[i], values[i]});
        }
        resources.release(true);
    }
    result.end_to_end_ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
    return result;
}
} // namespace mc
