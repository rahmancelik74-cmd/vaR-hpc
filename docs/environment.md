# Hedef makine envanteri

Buradaki değerler kullanıcının proje bilgisayarına aittir. Asistanın çalışma
sunucusundaki donanım, benchmark donanımı olarak kullanılmaz.

| Alan | Değer |
| --- | --- |
| İşletim sistemi ve sürüm | Windows 11; build numarası bekliyor |
| CPU tam model | 12th Gen Intel Core i7-12650H |
| Fiziksel çekirdek / mantıksal thread | 10 / 16, kullanıcının CIM çıktısı |
| RAM | 16 GB, kullanıcı beyanı |
| NVIDIA GPU tam model | NVIDIA GeForce RTX 4060 Laptop GPU |
| VRAM | 8 GB, kullanıcı beyanı |
| NVIDIA sürücüsü | Windows DriverVersion 32.0.16.1088, Status OK |
| CUDA Toolkit / nvcc sürümü | release 13.4, V13.4.92, kullanıcının nvcc çıktısı |
| C++ derleyicisi ve sürümü | MSVC 19.44.35227; VS 17.14.32 |
| CMake sürümü | 3.31.6-msvc6 |
| Release derleyici bayrakları | Doldurulacak |
| OpenMP runtime / affinity ayarı | Doldurulacak |
| GPU kuantil kütüphanesi / sürümü | Doldurulacak |

Windows PowerShell'de ilk bilgiler için:

```powershell
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors
Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory
nvidia-smi
nvcc --version
cmake --version
```

Bir komut bulunamıyorsa çıktıyı hata olarak kaydet; kurulu olduğunu varsayma.
`nvidia-smi` içindeki CUDA alanı kurulu Toolkit sürümü değildir; Toolkit için
`nvcc --version` çıktısı ayrı kaydedilir. Makine adı, seri numarası veya kişisel
dosya yollarını herkese açık repository'ye koyma.

İlk kontrol: CPU build/CTest çalışıyor mu? NVIDIA cihaz ve nvcc erişilebilir mi?
CUDA/cuRAND ve kuantil kütüphanesinin gerçek smoke testi sonraki kanıttır.

14.10.2026: Kullanıcı v0.1 x64 CMake build/CTest ve serial demo çıktısını aldığını
doğruladı. Ham test logu bu pakete eklenmedi. v0.2 Windows testi bekliyor.
`nvcc --version` compiler kurulumunu kanıtlar; GPU kernel çalışmasını kanıtlamaz.
10 çekirdeğin thread sweep'inde 1,2,4,8,10 noktaları kullanılacak; farklı çekirdek
türlerinin yerleşimi ve güç koşulları benchmark aşamasında ayrıca kaydedilecek.

## Verified foundation update: 2026-10-15

The later verification supersedes the older pending v0.2 test status above.
Windows x64 Release configure/build succeeded in build-foundation using
Visual Studio 17 2022 and MSVC 19.44.35227.0. All three CTest tests passed
(core_tests, csv_calibration_tests, csv_cli_smoke; 0.23 seconds total).
The log is committed as evidence/windows-release-ctest-20261015.log in 48429b5.
CMake selected Windows SDK 10.0.26100.0 and target version 10.0.26200; these
version strings alone are not a separate verification of the OS edition.
Compiler optimization flags, hosted CI and GPU runtime execution remain open.
This CPU verification is not a formal performance benchmark.
