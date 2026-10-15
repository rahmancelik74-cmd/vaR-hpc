# Requirements and Design Document

Durum: başlangıç taslağı v0.1. Danışmana teslim edilecek en fazla sekiz sayfalık
v1.0 belgesinin içeriği için temel; nihai onaylı belge değildir.

## Kapsam

Bu çalışmanın temel katkısı hesaplama doğruluğu ve performans analizidir.
Geometrik Brown Hareketi ve Value at Risk, sıralı C++, OpenMP ve CUDA
uygulamalarını karşılaştırmak için iyi tanımlanmış ve bağımsız olarak
doğrulanabilir bir hesaplama iş yükü olarak kullanılmaktadır. Çalışma gerçek
piyasalarda tahmin başarısı, stres testi yeterliliği veya finansal model üstünlüğü
iddia etmemektedir. Aynı kapsam beyanı teknik raporun başında da bulunacaktır.

İngilizce belgelerde kullanılabilecek karşılığı:

The contribution of this work is computational correctness and performance.
GBM and VaR serve as a well-defined, independently verifiable workload for
comparing sequential C++, OpenMP, and CUDA implementations. No claim is made
about predictive validity in real markets.

Tek varlık ve pozitif long pozisyon temel kapsamdır. GUI, canlı fiyat API'si,
makine öğrenimi ve MPI dahil değildir. Çok-varlıklı portföy, temel benchmark'ın
yerine geçmez; yalnızca Plan B kapsamında hocayla kararlaştırılabilecek ek moddur.

## Model ve sayısal sözleşme

- V0 = q * S0; S0 > 0 ve q > 0. İlk demo V0 üzerinden çalışır.
- `mu` fiyat drift'idir, ortalama log-getiri değildir; birimi yıl^-1.
- `sigma` volatilitedir; birimi yıl^-1/2. T yıl cinsindendir.
- Z standart normal: V_T = V0 * exp((mu - sigma^2/2)*T + sigma*sqrt(T)*Z).
- L = V0 - V_T; pozitif değer kayıptır. Negatif VaR sıfıra kırpılmaz.
- Güven düzeyleri alpha = 0.95 ve 0.99. Tüm hesaplama değerleri double.
- Kayıplar artan sıralanır: 1 tabanlı k = ceil(alpha*N), C++ indeksi k-1.
- Analitik VaR = V0 - Q_(1-alpha)(V_T). %99 için alt terminal kuantil %1'dir.
- Analitik terminal kuantil aynı GBM formülüne Phi^-1(1-alpha) konularak bulunur.
- Yalnız terminal değer gerekli olduğu için tam fiyat yolu simüle edilmez.

GBM sabit drift/volatilite, sürekli yollar, normal bağımsız log-getiri
artışları ve lognormal terminal değer varsayar. Gerçek piyasalarda volatilite
zamanla değişebilir; volatilite kümelenmesi, kalın kuyruklar ve sıçramalar bu
varsayımları ihlal edebilir. Analitik teste uyum, model içi uygulama doğruluğudur;
gerçek piyasa geçerliliği değildir.

## Parametre kestirimi tasarımı

Eşit aralıklı gözlemler için r_i = log(P_i/P_(i-1)). Gözlem aralığı dt yıl ise,
ortalama m ve örneklem varyansı s^2 kullanılarak sigma = sqrt(s^2/dt) ve
mu = m/dt + sigma^2/2 hesaplanacaktır. Bu proje sözleşmesi n-1 paydalı
örneklem varyansını kullanır; nihai dokümanda kestirici tercihi açıklanacaktır.
Yıllık işlem günü sayısı ve seçilen ufuk açıkça kaydedilir; takvim günleriyle
işlem günleri karıştırılmaz. Aritmetik günlük getiri ortalaması bu formüle konmaz.

CSV kaynağı/ticker/tarih aralığı/fiyat düzeltme politikası henüz seçilmedi.
Eksik, mükerrer, sırasız, sıfır veya negatif fiyatlar için açık hata politikası
yazılacak; sessiz temizleme yapılmayacak. Nihai giriş dosyasının SHA-256 özeti
kaydedilecek. Girdi verisi ve parametre kestirimi bütün motorlar için ortak.

## Numaralı gereksinimler

| ID | Gereksinim | Kabul kanıtı | Bu paketteki durum |
| --- | --- | --- | --- |
| R01 | Hesaplama odaklı kapsam ve GBM sınırlamaları | Gereksinim ve teknik rapor başında beyan | Taslak var |
| R02 | Birimler, kayıp işareti, kuantil ve double | Belgelenmiş sözleşme ve deterministik testler | Başlangıç testleri var |
| R03 | Donanım/toolchain ve derleme ayarları | Kullanıcının hedef makine envanteri | Şablon var |
| R04 | CMake ve temel CI | Yerel build/CTest ve repository CI sonucu | Tanım var; CI bekliyor |
| R05 | Ortak motor arayüzü | Aynı Request/Result ile backend çağrısı | Serial arayüz var; GPU kanıtı bekliyor |
| R06 | CSV ve log-getiri kestirimi | Bilinen girdilerle kestirim testleri | v0.2 uygulaması ve kontrollü testler var; gerçek veri seçimi bekliyor |
| R07 | Analitik tek-varlık VaR | Bilinen normal kuantiller ve sınır durumları | Başlangıç uygulaması/testleri var |
| R08 | Serial motorun analitik doğrulanması | %95/%99, beş seed, onaylı eşikler | Demo var; kabul çalışması bekliyor |
| R09 | OpenMP ve thread ölçeklenmesi | Ortak girdiler, thread sweep, affinity kaydı | Bekliyor |
| R10 | İlk dönem GPU yürüyen iskeleti | CSV→kestirim→cuRAND→GPU kuantil→VaR, N=10000 | Bekliyor |
| R11 | CUDA tam ölçek ve bellek yönetimi | 100 bin/1 milyon/10 milyon, bellek ve race testleri | Bekliyor |
| R12 | Tam motor doğrulaması | Ortak girdiler + ayrı analitik/seed testleri | Bekliyor |
| R13 | Adil benchmark ve yakınsama | 3 warm-up, 10 tekrar, ortalama/std, iki CPU referansı | Bekliyor |
| R14 | Tekrar üretilebilirlik ve rapor | Build/run betikleri, envanter, checksum, rapor | Bekliyor |
| B01 | Plan B profil temelli optimizasyon | Nsight, darboğaz, önce/sonra, yeniden doğrulama | Koşullu |
| B02 | Plan B çok-varlıklı ek mod | Hocanın kararı ve ayrı doğrulama stratejisi | Koşullu |

## Motor arayüzü ve veri sahipliği

`Engine::run(Request, common_normals)` tek toplu çağrıdır. Request model,
senaryo sayısı, seed ve güven düzeylerini taşır. Result VaR değerlerini,
backend/RNG bilgisini ve ölçümü taşır. Backend kendi ara belleğini, RNG durumunu,
simülasyonunu, kuantilini ve senkronizasyonunu yönetir. Bütün kayıpların host'a
dönmesi zorunlu değildir. CPU döngüsü veya host RNG callback'i arayüze dayatılmaz.

`common_normals` yalnız doğrulama modu içindir. Ya tam N girdisi vardır ya da
motor kendi RNG'sini kullanır. Ortak girdilerin sahipliği çağırandadır; motor
yalnız çağrı boyunca okur. CUDA bu modda girdileri cihaza aktaracak; normal
performans modunda bunları CPU'da üretip GPU'ya taşımak zorunda olmayacak.
CUDA uygulaması henüz yazılmadığı için arayüzün GPU ile doğrulandığı iddia edilmez.

GPU kuantil kütüphanesi için geçici aday Thrust `sort`; gerçek cihazda
uyumluluk kontrolünden sonra seçim sabitlenecek. İskelet ile tam motor aynı
kütüphaneyi kullanacak. CUB seçilecekse iskelet baştan CUB ile kurulacak.

## Doğrulama ve ölçüm

Önce deterministik sınır ve kuantil testleri; sonra ortak normal girdilerle
senaryo bazlı kayıp ve VaR karşılaştırması; ardından bağımsız seed'lerle analitik
VaR ve yakınsama testleri. Aynı seed farklı RNG'lerde aynı dizi garantisi değildir.
Sayısal ve istatistiksel testler birbirinin yerine kullanılmaz.

Onaylı proposal'daki toleranslar bu iki roadmap'te tekrar verilmemiştir.
Bu nedenle yeni kabul eşiği uydurulmaz: v1.0 öncesi proposal'dan aktarılacak,
her seed için sonuç/hata ve geçti-kaldı kararı ayrı kaydedilecektir.
GPU iskeleti yalnız hattın bağlandığını kanıtlar; hata/hız kabul testi değildir.

Benchmark harness serial motorla birlikte geliştirilecek. Ortak CSV/kestirim
sonrası başlayıp motor tamamlanınca biten host wall-clock ana ölçümdür;
allocations, RNG kurulumu/üretimi, simülasyon, kuantil, gerekli transferler ve
senkronizasyon dahildir. GPU aşama süreleri CUDA Events ile ayrı raporlanır.
Kernel-only, device pipeline ve end-to-end süreleri birbirine karıştırılmaz.
Profiler çalıştırmaları zamanlı benchmark tekrarlarından ayrılır.

N = 100000, 1000000, 10000000; 3 warm-up + 10 zamanlı tekrar; ortalama ve örneklem
standart sapması; scenarios/s; serial ve en iyi OpenMP ayarına göre speedup.
Thread sweep 1,2,4,... ve fiziksel çekirdek sayısını ayrıca içerir. Ortak girdi
test modu benchmark olarak etiketlenmez. Temel serial demo optimize edilmemiştir;
nihai CPU referansı makul derleyici optimizasyonlarıyla ölçülecektir.

Bellek yetmezse GPU'da gruplar üretilip skaler kayıplar host'ta biriktirilir ve
global kuantil alınır. Grupların VaR değerleri ortalanmaz. Hibrit mod ayrı
etiketlenir ve transfer/host kuantil süreleri toplam süreye dahil edilir.

## İlk iki haftanın açık kararları

1. Hedef CPU/GPU, işletim sistemi, sürücü/Toolkit/derleyici erişimi.
2. T, işlem günü ölçeği, veri kaynağı ve fiyat düzeltme politikası.
3. Onaylı proposal'dan hata eşikleri ve başarı hedefleri.
4. Repository konumu ve CI'nin gerçekten çalıştırılması.
5. GPU kuantil kütüphanesi; cihazda küçük smoke test.

Kaynak: danışmanın Plan A/Plan B v2.0, 14.10.2026. Sayısal kabul koşulları için
onaylı proposal ayrıca esas alınacak. Tüm ilerleme raporları Rxx/Bxx ID'lerine
ve test/ölçüm kanıtlarına bağlanacak.
