// Windows instrumentation only. No changes to the numerical engine or its timer.
#define NOMINMAX
#include <windows.h>
#include <powrprof.h>
#include <omp.h>
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <locale>
#include <sstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

namespace {
void require(bool ok, const char* text) {
    if (!ok) throw std::runtime_error(std::string(text) + "; Win32 error=" + std::to_string(GetLastError()));
}
struct Handle {
    HANDLE value = nullptr;
    ~Handle() { if (value && value != INVALID_HANDLE_VALUE) CloseHandle(value); }
};
std::string hex(std::uint64_t value) {
    std::ostringstream out; out << std::hex << value; return out.str();
}
void string(const std::string& text) {
    std::cout << '"';
    for (unsigned char c : text) {
        if (c == '"' || c == '\\') std::cout << '\\' << static_cast<char>(c);
        else if (c < 32 || c >= 127)
            std::cout << "\\u00" << "0123456789abcdef"[c >> 4] << "0123456789abcdef"[c & 15];
        else std::cout << static_cast<char>(c);
    }
    std::cout << '"';
}
void masks(HANDLE process, DWORD_PTR& process_mask, DWORD_PTR& system_mask) {
    require(GetProcessAffinityMask(process, &process_mask, &system_mask) != 0, "GetProcessAffinityMask failed");
}
std::uint64_t mask_argument(const wchar_t* argument) {
    std::size_t used = 0;
    const std::wstring text(argument);
    const auto value = std::stoull(text, &used, 16);
    if (used != text.size() || !value) throw std::invalid_argument("Invalid hexadecimal affinity mask");
    return value;
}
void power() {
    // Documented ProcessorInformation layout, absent from this SDK's headers.
    struct CpuPowerInformation {
        ULONG Number, MaxMhz, CurrentMhz, MhzLimit, MaxIdleState, CurrentIdleState;
    };
    SYSTEM_POWER_STATUS status{};
    require(GetSystemPowerStatus(&status) != 0, "GetSystemPowerStatus failed");
    std::cout << "{\"ac_line_status\":" << static_cast<int>(status.ACLineStatus)
              << ",\"battery_percent\":";
    if (status.BatteryLifePercent == 255) std::cout << "null";
    else std::cout << static_cast<int>(status.BatteryLifePercent);
    std::cout << ",\"battery_flags\":" << static_cast<int>(status.BatteryFlag)
              << ",\"battery_saver\":" << static_cast<int>(status.SystemStatusFlag)
              << ",\"active_power_scheme\":";
    GUID* scheme = nullptr;
    if (PowerGetActiveScheme(nullptr, &scheme) == ERROR_SUCCESS) {
        char guid[64]{};
        sprintf_s(guid, "%08lx-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            scheme->Data1, scheme->Data2, scheme->Data3, scheme->Data4[0], scheme->Data4[1],
            scheme->Data4[2], scheme->Data4[3], scheme->Data4[4], scheme->Data4[5], scheme->Data4[6], scheme->Data4[7]);
        string(guid); LocalFree(scheme);
    } else std::cout << "null";
    const auto count = GetActiveProcessorCount(ALL_PROCESSOR_GROUPS);
    std::vector<CpuPowerInformation> frequencies(count);
    const auto code = CallNtPowerInformation(ProcessorInformation, nullptr, 0, frequencies.data(),
        static_cast<ULONG>(frequencies.size() * sizeof(CpuPowerInformation)));
    std::cout << ",\"frequency_query_status\":" << code << ",\"frequency_snapshot_mhz\":[";
    if (code == 0) {
        for (std::size_t i = 0; i < frequencies.size(); ++i) {
            if (i) std::cout << ',';
            std::cout << "{\"logical_processor\":" << frequencies[i].Number
                      << ",\"current\":" << frequencies[i].CurrentMhz
                      << ",\"maximum\":" << frequencies[i].MaxMhz
                      << ",\"limit\":" << frequencies[i].MhzLimit << '}';
        }
    }
    std::cout << "],\"cpu_package_temperature_c\":null,\"temperature_status\":\"Not measured; no package sensor reader configured\"}";
}
void inventory() {
    DWORD_PTR process_mask{}, system_mask{};
    masks(GetCurrentProcess(), process_mask, system_mask);
    std::cout << "{\"processor_groups\":" << GetActiveProcessorGroupCount()
              << ",\"logical_processors\":" << GetActiveProcessorCount(ALL_PROCESSOR_GROUPS)
              << ",\"process_mask_hex\":\"" << hex(process_mask)
              << "\",\"system_mask_hex\":\"" << hex(system_mask) << "\",\"cores\":[";
    DWORD bytes = 0;
    GetLogicalProcessorInformationEx(RelationProcessorCore, nullptr, &bytes);
    require(bytes != 0, "Topology size unavailable");
    std::vector<unsigned char> buffer(bytes);
    require(GetLogicalProcessorInformationEx(RelationProcessorCore,
        reinterpret_cast<PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX>(buffer.data()), &bytes) != 0,
        "Topology query failed");
    bool first = true;
    for (std::size_t offset = 0, core = 0; offset < bytes; ++core) {
        const auto row = reinterpret_cast<PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX>(buffer.data() + offset);
        if (!row->Size || offset + row->Size > bytes) throw std::runtime_error("Invalid topology record");
        const auto& p = row->Processor;
        if (!first) std::cout << ',';
        first = false;
        std::cout << "{\"core_index\":" << core << ",\"efficiency_class\":" << static_cast<int>(p.EfficiencyClass)
                  << ",\"smt_flag\":" << static_cast<int>(p.Flags & LTP_PC_SMT) << ",\"groups\":[";
        for (WORD i = 0; i < p.GroupCount; ++i) {
            if (i) std::cout << ',';
            std::cout << "{\"group\":" << p.GroupMask[i].Group << ",\"logical_mask_hex\":\""
                      << hex(p.GroupMask[i].Mask) << "\"}";
        }
        std::cout << "]}";
        offset += row->Size;
    }
    std::cout << "],\"openmp_version\":" << _OPENMP << ",\"runtime\":";
    const auto module = GetModuleHandleW(L"vcomp140.dll");
    if (module) {
        wchar_t path[MAX_PATH]{};
        require(GetModuleFileNameW(module, path, MAX_PATH) != 0, "Runtime path query failed");
        DWORD unused = 0;
        const auto size = GetFileVersionInfoSizeW(path, &unused);
        std::vector<unsigned char> info(size);
        VS_FIXEDFILEINFO* version = nullptr;
        UINT version_size = 0;
        require(size && GetFileVersionInfoW(path, 0, size, info.data()) &&
                VerQueryValueW(info.data(), L"\\", reinterpret_cast<void**>(&version), &version_size),
                "Runtime version query failed");
        std::cout << "{\"module\":\"vcomp140.dll\",\"file_version\":\""
                  << HIWORD(version->dwFileVersionMS) << '.' << LOWORD(version->dwFileVersionMS) << '.'
                  << HIWORD(version->dwFileVersionLS) << '.' << LOWORD(version->dwFileVersionLS) << "\"}";
    } else std::cout << "null";
    std::cout << ",\"power\":"; power(); std::cout << "}\n";
}
void affinity(int threads, std::uint64_t requested_mask) {
    require(SetProcessAffinityMask(GetCurrentProcess(), static_cast<DWORD_PTR>(requested_mask)) != 0,
            "Probe process affinity failed");
    struct Row { int group = -1; std::uint64_t allowed = 0, observed = 0; bool ok = false; };
    std::vector<Row> rows(threads);
    int actual = 0;
#pragma omp parallel num_threads(threads)
    {
#pragma omp single
        actual = omp_get_num_threads();
        const int i = omp_get_thread_num();
        GROUP_AFFINITY allowed{};
        rows[i].ok = GetThreadGroupAffinity(GetCurrentThread(), &allowed) != 0;
        rows[i].allowed = allowed.Mask;
        rows[i].group = allowed.Group;
        const auto finish = std::chrono::steady_clock::now() + std::chrono::milliseconds(25);
        do {
            PROCESSOR_NUMBER cpu{}; GetCurrentProcessorNumberEx(&cpu);
            if (cpu.Group == allowed.Group && cpu.Number < 64)
                rows[i].observed |= UINT64_C(1) << cpu.Number;
            SwitchToThread();
        } while (std::chrono::steady_clock::now() < finish);
    }
    std::cout << "{\"requested_threads\":" << threads << ",\"threads_used\":" << actual
              << ",\"process_mask_hex\":\"" << hex(requested_mask) << "\",\"threads\":[";
    for (int i = 0; i < actual; ++i) {
        require(rows[i].ok, "Worker affinity query failed");
        if (i) std::cout << ',';
        std::cout << "{\"thread\":" << i << ",\"group\":" << rows[i].group
                  << ",\"allowed_mask_hex\":\"" << hex(rows[i].allowed)
                  << "\",\"observed_mask_hex\":\"" << hex(rows[i].observed) << "\"}";
    }
    std::cout << "]}\n";
}
std::wstring quote(const std::wstring& argument) {
    std::wstring out = L"\"";
    std::size_t slashes = 0;
    for (wchar_t c : argument) {
        if (c == L'\\') { ++slashes; continue; }
        out.append(slashes * (c == L'"' ? 2 : 1), L'\\'); slashes = 0;
        if (c == L'"') out += L'\\';
        out += c;
    }
    out.append(slashes * 2, L'\\');
    return out + L'"';
}
void drain_pipe(HANDLE pipe, std::string& output) {
    // A bounded nonblocking drain keeps the execution deadline observable even
    // when a child writes continuously or a descendant retains an inherited pipe.
    for (int chunk = 0; chunk < 16; ++chunk) {
        DWORD available = 0;
        if (!PeekNamedPipe(pipe, nullptr, 0, nullptr, &available, nullptr)) {
            require(GetLastError() == ERROR_BROKEN_PIPE, "Pipe query failed");
            return;
        }
        if (!available) return;
        char bytes[4096]; DWORD count = 0;
        require(ReadFile(pipe, bytes, (std::min)(available, DWORD(sizeof(bytes))), &count, nullptr) != 0,
                "Pipe read failed");
        output.append(bytes, count);
    }
}
void launch(std::uint64_t mask, int argc, wchar_t** argv, int first = 3, DWORD timeout_ms = 60000) {
    SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
    Handle out_read, out_write, err_read, err_write;
    require(CreatePipe(&out_read.value, &out_write.value, &security, 0) != 0, "stdout pipe failed");
    require(CreatePipe(&err_read.value, &err_write.value, &security, 0) != 0, "stderr pipe failed");
    require(SetHandleInformation(out_read.value, HANDLE_FLAG_INHERIT, 0) &&
            SetHandleInformation(err_read.value, HANDLE_FLAG_INHERIT, 0), "Pipe inheritance failed");
    STARTUPINFOW startup{}; startup.cb = sizeof(startup); startup.dwFlags = STARTF_USESTDHANDLES;
    startup.hStdOutput = out_write.value; startup.hStdError = err_write.value;
    PROCESS_INFORMATION child{};
    std::wstring command;
    for (int i = first; i < argc; ++i) { if (i > first) command += L' '; command += quote(argv[i]); }
    Handle job;
    job.value = CreateJobObjectW(nullptr, nullptr);
    require(job.value != nullptr, "Job creation failed");
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    require(SetInformationJobObject(job.value, JobObjectExtendedLimitInformation, &limits, sizeof(limits)) != 0,
            "Job limit setup failed");
    require(CreateProcessW(argv[first], &command[0], nullptr, nullptr, TRUE,
        CREATE_SUSPENDED | CREATE_NO_WINDOW | NORMAL_PRIORITY_CLASS, nullptr, nullptr, &startup, &child) != 0,
        "CreateProcess failed");
    Handle process{child.hProcess}, thread{child.hThread};
    try {
        // Assign while suspended: descendants cannot escape between creation and assignment.
        require(AssignProcessToJobObject(job.value, process.value) != 0, "Job assignment failed");
        require(SetProcessAffinityMask(process.value, static_cast<DWORD_PTR>(mask)) != 0, "Child affinity failed");
        DWORD_PTR effective{}, system{}; masks(process.value, effective, system);
        require(effective == mask, "Child affinity did not match request");
        CloseHandle(out_write.value); out_write.value = nullptr;
        CloseHandle(err_write.value); err_write.value = nullptr;
        std::ostringstream before;
        auto* saved = std::cout.rdbuf(before.rdbuf());
        try { power(); } catch (...) { std::cout.rdbuf(saved); throw; }
        std::cout.rdbuf(saved);
        const auto priority = GetPriorityClass(process.value);
        const auto started = std::chrono::steady_clock::now();
        require(ResumeThread(thread.value) != static_cast<DWORD>(-1), "ResumeThread failed");
        std::string output, error_text;
        bool timed_out = false, terminated = false;
        DWORD active_at_timeout = 0;
        for (;;) {
            drain_pipe(out_read.value, output); drain_pipe(err_read.value, error_text);
            JOBOBJECT_BASIC_ACCOUNTING_INFORMATION accounting{};
            require(QueryInformationJobObject(job.value, JobObjectBasicAccountingInformation,
                    &accounting, sizeof(accounting), nullptr) != 0, "Job status failed");
            if (accounting.ActiveProcesses == 0) break;
            if (std::chrono::steady_clock::now() - started >= std::chrono::milliseconds(timeout_ms)) {
                timed_out = true; active_at_timeout = accounting.ActiveProcesses;
                require(TerminateJobObject(job.value, 124) != 0, "Owned job termination failed");
                terminated = true;
                require(WaitForSingleObject(process.value, 5000) == WAIT_OBJECT_0, "Termination wait failed");
                break;
            }
            Sleep(1);
        }
        // Once the owned tree is gone, consume finite buffered output. Never wait
        // for EOF: a foreign inherited handle must not make the launcher hang.
        for (int i = 0; i < 100; ++i) {
            const auto prior = output.size() + error_text.size();
            drain_pipe(out_read.value, output); drain_pipe(err_read.value, error_text);
            if (prior == output.size() + error_text.size()) break;
        }
        DWORD code = 0; require(GetExitCodeProcess(process.value, &code) != 0, "Child exit code failed");
        const auto elapsed = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - started).count();
        std::cout << "{\"process_mask_hex\":\"" << hex(effective)
                  << "\",\"priority_class\":" << priority << ",\"before\":" << before.str();
        std::cout << ",\"after\":"; power();
        std::cout << ",\"timeout_ms\":" << timeout_ms << ",\"timed_out\":" << (timed_out ? "true" : "false")
                  << ",\"owned_job_terminated\":" << (terminated ? "true" : "false")
                  << ",\"active_processes_at_timeout\":" << active_at_timeout
                  << ",\"launcher_elapsed_ms\":" << elapsed
                  << ",\"exit_code\":" << code << ",\"stdout\":"; string(output);
        std::cout << ",\"stderr\":"; string(error_text); std::cout << "}\n";
    } catch (...) { TerminateJobObject(job.value, 1); TerminateProcess(process.value, 1); throw; }
}
}
int wmain(int argc, wchar_t** argv) {
    try {
        std::cout.imbue(std::locale::classic()); std::cout << std::setprecision(17);
        if (GetActiveProcessorGroupCount() != 1)
            throw std::runtime_error("Instrumentation currently requires one processor group");
        if (argc == 2 && std::wstring(argv[1]) == L"--inventory") inventory();
        else if (argc == 4 && std::wstring(argv[1]) == L"--affinity") {
            const int threads = std::stoi(argv[2]);
            if (threads < 1 || threads > 64) throw std::invalid_argument("Invalid probe thread count");
            affinity(threads, mask_argument(argv[3]));
        } else if (argc >= 5 && std::wstring(argv[1]) == L"--run-timeout") {
            std::size_t used = 0;
            const std::wstring text(argv[2]);
            const auto timeout = std::stoull(text, &used);
            if (used != text.size() || timeout == 0 || timeout > 3600000)
                throw std::invalid_argument("Timeout must be 1 through 3600000 milliseconds");
            launch(mask_argument(argv[3]), argc, argv, 4, static_cast<DWORD>(timeout));
        } else if (argc >= 4 && std::wstring(argv[1]) == L"--run") launch(mask_argument(argv[2]), argc, argv);
        else throw std::invalid_argument("Usage: mc_cpu_probe --inventory | --affinity threads mask_hex | --run mask_hex executable [arguments]");
        return 0;
    } catch (const std::exception& e) { std::cerr << "Probe error: " << e.what() << '\n'; return 1; }
}
