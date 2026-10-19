#define NOMINMAX
#include <windows.h>
#include <iostream>
#include <string>

int wmain(int argc, wchar_t** argv) {
    const std::wstring mode = argc > 1 ? argv[1] : L"normal";
    if (mode == L"nonzero") { std::cout << "partial-out"; std::cerr << "partial-err"; return 7; }
    if (mode == L"large") {
        for (int i = 0; i < 128; ++i) { std::cout << std::string(4096, 'O'); std::cerr << std::string(4096, 'E'); }
        return 0;
    }
    if (mode == L"child" || mode == L"tree" || mode == L"child-normal") {
        wchar_t self[32768]{};
        if (!GetModuleFileNameW(nullptr, self, 32768)) return 90;
        std::wstring command = L"\"" + std::wstring(self) + L"\" " + (mode == L"child-normal" ? L"normal" : L"hang");
        STARTUPINFOW startup{}; startup.cb = sizeof(startup);
        startup.dwFlags = STARTF_USESTDHANDLES;
        startup.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
        startup.hStdError = GetStdHandle(STD_ERROR_HANDLE);
        startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
        PROCESS_INFORMATION child{};
        if (!CreateProcessW(self, &command[0], nullptr, nullptr, TRUE, CREATE_NO_WINDOW, nullptr, nullptr, &startup, &child)) return 91;
        std::cout << "child_pid=" << child.dwProcessId << '\n' << std::flush;
        CloseHandle(child.hProcess); CloseHandle(child.hThread);
        if (mode != L"tree") return 0;
    }
    if (mode == L"hang" || mode == L"tree") {
        std::cout << "before-hang\n" << std::flush; std::cerr << "before-hang-err\n" << std::flush;
        Sleep(INFINITE);
    }
    std::cout << "normal-out"; std::cerr << "normal-err";
    return 0;
}
