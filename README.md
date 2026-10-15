# GPU Accelerated Monte Carlo Simulation for Financial Risk Analysis

Abdurrahman Çelik — başlangıç paketi v0.2.1, 15 Ekim 2026.

Bu projenin katkısı hesaplamaya yöneliktir. GBM ve VaR, CPU ve GPU
uygulamalarının doğruluğunu ve performansını karşılaştırmak için iyi tanımlanmış,
bağımsız olarak doğrulanabilir bir iş yüküdür. Gerçek piyasalarda tahmin başarısı
iddia edilmemektedir.

## Şu an ne var

- C++17, CMake ve CTest projesi; GitHub Actions CPU derleme/test tanımı.
- Backend'in RNG, bellek, simülasyon ve kuantili yönettiği ortak `Engine` arayüzü.
- Sabit sentetik parametrelerle çalışan, optimize edilmemiş serial örnek.
- Tek varlıklı GBM analitik VaR referansı ve deterministik birim testleri.
- CSV okuyucu, log-getiri kestirimi ve bunları doğrulayan testler.
- Numaralı gereksinim/tasarım taslağı ve donanım envanter şablonu.

Henüz OpenMP, CUDA veya GPU kuantil kodu yok.
Serial örnek, beş-seed analitik kabul testini henüz tamamlamış bir motor değildir.
CI dosyası hazırlanmıştır; uzak repository oluşturulmamış ve CI çalıştırılmamıştır.

## Derleme

CMake ve bir C++17 derleyicisi gerekli; başlangıç için NVIDIA GPU gerekmiyor.

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --parallel
ctest --test-dir build -C Release --output-on-failure
```

Linux veya tek yapılandırmalı Ninja/MinGW derlemesi:

```sh
./build/mc_var 10000 42
```

Windows Visual Studio çok yapılandırmalı derlemesi, PowerShell:

```powershell
.\build\Release\mc_var.exe 10000 42
```

Örnekte `V0=100`, yıllık `mu=0.05`, `sigma=0.20`, `T=1` yıl kullanılır.
Bunlar yalnızca demo değerleridir; nihai veri ve zaman ufku değildir.
Çıktı %95/%99 Monte Carlo VaR, analitik VaR, fark ve tek koşunun süresini gösterir.
Tek koşu benchmark kampanyası veya %1 yakınsama garantisi değildir.

## CSV ile çalışma

v0.2.1 kurulum kontrolü: `mc_var.exe --version` çıktısı
`mc_var 0.2.1 (CSV support enabled)` olmalıdır. Bu sürümde CTest üç test
çalıştırır: core_tests, csv_calibration_tests ve csv_cli_smoke. Tek core_tests
görünüyorsa kaynak veya derleme sürümleri karışmıştır. Yeni paketi boş bir
klasöre aç; eski build klasörünü kopyalama.

Windows'ta v0.2 kaynaklarını ayrı bir klasöre açıp Developer PowerShell'de,
`CMakeLists.txt` bulunan klasörde çalıştır:

```powershell
cmake -S . -B build-x64 -G "Visual Studio 17 2022" -A x64
cmake --build build-x64 --config Release --parallel
ctest --test-dir build-x64 -C Release --output-on-failure
.\build-x64\Release\mc_var.exe --csv .\data\synthetic_prices.csv 10000 42 10
```

Linux: `./build/mc_var --csv data/synthetic_prices.csv 10000 42 10`.

Son argüman 10 işlem günlük ufuktur. CSV modu varsayılan 252 işlem günü/yıl ve
bir varlık birimi kullanır; V0 son satırdaki kapanış fiyatıdır. Bunlar başlangıç
ayarlarıdır, danışmanın onayladığı nihai ufuk değildir. Yıl ölçeğini değiştirmek
için sona ekle: `--csv file.csv 10000 42 10 252`.

CSV sözleşmesi: başlık tam olarak `date,close`; iki kolon; YYYY-MM-DD;
ondalık nokta; artan, benzersiz tarihler; sonlu ve pozitif fiyatlar.
UTF-8 BOM ve CRLF desteklenir; tırnaklı alanlar, ek kolonlar, noktalı virgül,
ondalık virgül ve boş kayıtlar desteklenmez. Hatalı satırlar atlanmaz;
satır numarasıyla hata verilir. En az 3 fiyat gerekir.

Her kayıt bir sonraki işlem gözlemi kabul edilir. Hafta sonu/tatil aralığı
normaldir; eksik işlem günü tespiti için piyasa takvimi henüz eklenmedi.
Veri sağlayıcının CSV'sini bu sözleşmeye dönüştürmek ve fiyat düzeltme politikasını
belgelemek gerekir. Kapanış/düzeltilmiş kapanış seçimi sessizce yapılmaz.

`data/synthetic_prices.csv` elle oluşturulmuş yazılım test verisidir; gerçek
hisse, fiyat kaynağı veya piyasa performansı kanıtı değildir. Yalnız 12 fiyat
içerir; istatistiksel model kalibrasyonu için yeterlilik iddiası yok.
CSV okuma/kestirim, motorun `end_to_end_ms` ölçümünün dışındadır.

Kestirimde n log-getiri için n-1 paydalı örneklem varyansı kullanılır.
Yıllık fiyat drift'i, yıllık ortalama log-getiriye yıllık varyansın yarısı
eklenerek bulunur. Ayrıntılar `docs/requirements-design.md` içindedir.

## Başlangıç sırası

1. `docs/environment.md` dosyasını kendi bilgisayarın için doldur.
2. `docs/requirements-design.md` içindeki açık kararları tamamla.
3. Yerelde derle ve testleri çalıştır; Git repository'sini oluştur.
4. CSV/kestirim testlerini yerelde çalıştır ve veri kaynağı sözleşmesini tamamla.
5. Serial motoru iki güven düzeyinde beş seed ile analitik referansa karşı doğrula.
6. OpenMP ve thread ölçeklenmesini ekle.
7. İlk dönem 12–13. haftalarda CSV → kestirim → GPU/cuRAND → GPU kuantil → VaR
   hattını 10.000 senaryoda aynı arayüzle bağla.

Plan A ana plandır. Plan B ilk dönem rahat tamamlanırsa hocayla birlikte seçilir;
profil temelli optimizasyon ve isteğe bağlı çok-varlıklı genişleme başlangıca eklenmez.

## Kaynaklar

- Danışmanın 14.10.2026 tarihli Plan A ve Plan B yol haritaları.
- https://docs.nvidia.com/cuda/curand/device-api-overview.html
- https://cmake.org/cmake/help/latest/guide/tutorial/index.html

## RNG notu

`std::normal_distribution` çıktısı farklı standart kütüphane uygulamalarında aynı
olmak zorunda değildir. Aynı seed, CPU–GPU aynı örnekler demek değildir.
Çapraz sayısal testlerde önceden üretilmiş ortak girdiler kullanılır.
CUDA RNG API ve Toolkit sürümü hedef bilgisayar incelendikten sonra sabitlenecek.
