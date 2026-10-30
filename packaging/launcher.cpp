// Portable launcher: app-local resources, per-user state, owned process Job Object.
#define UNICODE
#define _UNICODE
#include <windows.h>
#include <shellapi.h>
#include <bcrypt.h>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <iomanip>
#pragma comment(lib,"bcrypt.lib")
#pragma comment(lib,"user32.lib")
#pragma comment(lib,"shell32.lib")
namespace fs=std::filesystem;
static HANDLE child=nullptr, job=nullptr;
static fs::path state;
static HWND label;
static bool stopping=false, quiet=false, ready=false;
static unsigned ticks=0;
static std::string hash(const fs::path& path) {
    std::ifstream f(path,std::ios::binary); if(!f) return "";
    BCRYPT_ALG_HANDLE a=nullptr; BCRYPT_HASH_HANDLE h=nullptr;
    if(BCryptOpenAlgorithmProvider(&a,BCRYPT_SHA256_ALGORITHM,nullptr,0)<0) return "";
    DWORD size=0,n=0; BCryptGetProperty(a,BCRYPT_OBJECT_LENGTH,(PUCHAR)&size,4,&n,0);
    std::vector<unsigned char> object(size), digest(32);
    if(BCryptCreateHash(a,&h,object.data(),size,nullptr,0,0)<0){BCryptCloseAlgorithmProvider(a,0);return "";}
    char buffer[65536]; bool ok=true;
    while(f){ f.read(buffer,sizeof(buffer)); auto got=f.gcount(); if(got && BCryptHashData(h,(PUCHAR)buffer,(ULONG)got,0)<0) ok=false; }
    if(BCryptFinishHash(h,digest.data(),32,0)<0) ok=false;
    BCryptDestroyHash(h); BCryptCloseAlgorithmProvider(a,0);
    if(!ok) return "";
    std::ostringstream out; for(auto c:digest) out<<std::hex<<std::setw(2)<<std::setfill('0')<<(int)c; return out.str();
}
static void requestStop(){stopping=true;ticks=0;std::ofstream(state/"stop.request")<<"stop";SetWindowTextW(label,L"Stopping owned processes. Please wait...");}
static LRESULT CALLBACK proc(HWND w,UINT m,WPARAM a,LPARAM b){
    if(m==WM_COMMAND && LOWORD(a)==2){ShellExecuteW(w,L"open",state.parent_path().parent_path().c_str(),nullptr,nullptr,SW_SHOW);return 0;}
    if(m==WM_CLOSE || (m==WM_COMMAND && LOWORD(a)==1)){if(!stopping)requestStop();return 0;}
    if(m==WM_TIMER){
        if(WaitForSingleObject(child,0)==WAIT_OBJECT_0){DWORD code=0;GetExitCodeProcess(child,&code);TerminateJobObject(job,code);
            if(code && !quiet)MessageBoxW(w,(L"Startup or service failed. Private details: "+(state/L"startup-error.txt").wstring()+L"\nExtract the complete ZIP again if an asset is missing.").c_str(),L"Monte Carlo Lab",MB_ICONERROR);
            DestroyWindow(w);PostQuitMessage((int)code);return 0;}
        if(!ready && !stopping && fs::exists(state/"ready.txt")){
            std::ifstream f(state/"ready.txt");std::string url;std::getline(f,url);
            const std::string prefix="http://127.0.0.1:";
            if(url.rfind(prefix,0)!=0 || url.substr(prefix.size()).find_first_not_of("0123456789")!=std::string::npos){requestStop();return 0;}
            // The launcher is outside the Job Object: user browsers/Explorer must
            // never become descendants that are terminated with the engine job.
            if(!quiet && (INT_PTR)ShellExecuteW(w,L"open",std::wstring(url.begin(),url.end()).c_str(),nullptr,nullptr,SW_SHOW)<=32){
                requestStop();MessageBoxW(w,L"No default browser could be opened. Configure a supported installed browser and try again.",L"Monte Carlo Lab",MB_ICONERROR);return 0;
            }
            if(!quiet)std::ofstream(state/"browser-dispatched.txt")<<url;
            ready=true;SetWindowTextW(label,L"Running in your browser on loopback only.\nUse Stop application or close this window to stop.");
        }
        if(!ready && !stopping && ++ticks>1200)requestStop();
        if(stopping && ++ticks>200){TerminateJobObject(job,1);DestroyWindow(w);PostQuitMessage(1);}
    }
    return DefWindowProcW(w,m,a,b);
}
int WINAPI wWinMain(HINSTANCE instance,HINSTANCE,LPWSTR,int){
    int argc=0;LPWSTR* argv=CommandLineToArgvW(GetCommandLineW(),&argc);
    for(int i=1;i<argc;i++) if(std::wstring(argv[i])==L"--no-browser")quiet=true;
    SYSTEM_INFO systemInfo={};GetNativeSystemInfo(&systemInfo);
    if(systemInfo.wProcessorArchitecture!=PROCESSOR_ARCHITECTURE_AMD64){if(!quiet)MessageBoxW(nullptr,L"This package requires x64 Windows and an x64 CPU. ARM64 and 32-bit Windows are unsupported.",L"Monte Carlo Lab",MB_ICONERROR);LocalFree(argv);return 1;}
    HANDLE mutex=CreateMutexW(nullptr,TRUE,L"Local\\MCLabPortableCPU-v1");
    if(!mutex || GetLastError()==ERROR_ALREADY_EXISTS){if(!quiet)MessageBoxW(nullptr,L"Monte Carlo Lab portable is already running. Use its Stop application window before launching another copy.",L"Monte Carlo Lab",MB_ICONINFORMATION);return 2;}
    wchar_t exe[32768];GetModuleFileNameW(nullptr,exe,32768);fs::path root=fs::path(exe).parent_path();
    try {
        std::ifstream list(root/"integrity.sha256"); if(!list)throw std::runtime_error("Missing integrity list");
        std::string line;size_t count=0;
        while(std::getline(list,line)){
            if(line.size()<67)throw std::runtime_error("Invalid integrity list");
            auto name=line.substr(66);fs::path relative(name);
            if(relative.is_absolute() || name.find("..")!=std::string::npos || hash(root/relative)!=line.substr(0,64))throw std::runtime_error("Missing or changed package asset");
            count++;
        }
        if(count<10)throw std::runtime_error("Incomplete integrity list");
        wchar_t local[32768];if(!GetEnvironmentVariableW(L"LOCALAPPDATA",local,32768))throw std::runtime_error("LOCALAPPDATA unavailable");
        state=fs::path(local)/L"MCLabPortable"/L"sessions"/(std::to_wstring(GetCurrentProcessId())+L"-"+std::to_wstring(GetTickCount64()));
        for(int i=1;i+1<argc;i++) if(std::wstring(argv[i])==L"--state-dir")state=argv[++i];
        fs::create_directories(state);
        job=CreateJobObjectW(nullptr,nullptr);JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits={};limits.BasicLimitInformation.LimitFlags=JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        if(!job || !SetInformationJobObject(job,JobObjectExtendedLimitInformation,&limits,sizeof(limits)))throw std::runtime_error("Cannot create process job");
        std::wstring command=L"\""+(root/L"runtime/python.exe").wstring()+L"\" -I -B \""+(root/L"resources/portable_entry.py").wstring()+L"\" --state-dir \""+state.wstring()+L"\""+(quiet?L" --no-browser":L"");
        STARTUPINFOW si={sizeof(si)};PROCESS_INFORMATION pi={};
        if(!CreateProcessW(nullptr,command.data(),nullptr,nullptr,FALSE,CREATE_SUSPENDED|CREATE_NO_WINDOW,nullptr,root.c_str(),&si,&pi))throw std::runtime_error("Cannot start bundled runtime");
        child=pi.hProcess;
        if(!AssignProcessToJobObject(job,child)){TerminateProcess(child,1);CloseHandle(pi.hThread);throw std::runtime_error("Cannot contain child processes");}
        ResumeThread(pi.hThread);CloseHandle(pi.hThread);
        WNDCLASSW wc={};wc.lpfnWndProc=proc;wc.hInstance=instance;wc.lpszClassName=L"MCLabPortableWindow";wc.hbrBackground=(HBRUSH)(COLOR_WINDOW+1);wc.hCursor=LoadCursor(nullptr,IDC_ARROW);RegisterClassW(&wc);
        HWND window=CreateWindowW(wc.lpszClassName,L"Monte Carlo Lab - Stop application",WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU|WS_MINIMIZEBOX,CW_USEDEFAULT,CW_USEDEFAULT,560,210,nullptr,nullptr,instance,nullptr);
        if(!window)throw std::runtime_error("Cannot create stop window");
        label=CreateWindowW(L"STATIC",L"Starting and checking package...",WS_CHILD|WS_VISIBLE,20,20,490,60,window,nullptr,instance,nullptr);
        CreateWindowW(L"BUTTON",L"Stop application",WS_CHILD|WS_VISIBLE|WS_TABSTOP|BS_DEFPUSHBUTTON,30,100,220,32,window,(HMENU)1,instance,nullptr);
        CreateWindowW(L"BUTTON",L"Open data / logs folder",WS_CHILD|WS_VISIBLE|WS_TABSTOP,270,100,220,32,window,(HMENU)2,instance,nullptr);
        ShowWindow(window,SW_SHOW);SetTimer(window,1,100,nullptr);
        MSG msg;while(GetMessageW(&msg,nullptr,0,0)>0){if(!IsDialogMessageW(window,&msg)){TranslateMessage(&msg);DispatchMessageW(&msg);}}
        if(job)CloseHandle(job);if(child)CloseHandle(child);CloseHandle(mutex);LocalFree(argv);return (int)msg.wParam;
    }catch(const std::exception&){if(job)CloseHandle(job);
        if(!quiet)MessageBoxW(nullptr,L"The package could not start. Extract the entire ZIP to a normal local folder and try again. Required files may be missing or changed. Windows must permit this application and have a writable LOCALAPPDATA directory.",L"Monte Carlo Lab",MB_ICONERROR);
        CloseHandle(mutex);LocalFree(argv);return 1;}
}
