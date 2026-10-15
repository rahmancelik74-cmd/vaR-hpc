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
