# CSV ve kestirim doğrulaması v0.2

14.10.2026. GCC 13.3.0, C++17, -O2 -Wall -Wextra -Wpedantic ile derleme uyarısız.

- Core testleri geçti; mevcut sentetik CLI davranışı korundu.
- CSV/kestirim testleri geçti. Bağımsız beklenen log-getiriler .01, .02, .03
  ile ortalama, n-1 varyans, yıllık volatilite, drift düzeltmesi, son fiyat/V0
  ve işlem günü ufku kontrol edildi.
- CSV/kestirim testleri UndefinedBehaviorSanitizer ile de geçti.
- UTF-8 BOM/CRLF ve geçerli artık yıl tarihi kabul edildi.
- Geçersiz tarih, yinelenen/sırasız tarihler, eksik veri, sıfır/negatif fiyat,
  NaN, taşma, sayıya ek metin, ekstra kolon, yanlış başlık ve boş kayıt reddedildi.
- `--csv data/synthetic_prices.csv 10000 42 10` hattı uçtan uca çalıştı:
  12 gözlem, 11 getiri, V0=100.4, mu=0.112217495, sigma=0.2037837913.
- Analitik %95 VaR=6.143576939; %99 VaR=8.715446716. Bir birim pozisyon,
  10 işlem günü ufku, 252 işlem günü/yıl varsayımları. Değerler para birimi
  belirtilmeyen sentetik test verisine aittir.
- Monte Carlo çıktısı standart kütüphanenin RNG uygulamasına bağlı olarak
  Windows/Linux arasında farklı olabilir. Analitik referans buna bağlı değildir.
- v0.2 bu ortamda doğrudan g++ ile kontrol edildi; CMake/CTest ve MSVC doğrulaması
  kullanıcının bilgisayarında yapılacak. Önceki v0.1 için kullanıcı testlerin ve
  demonun çalıştığını bildirdi.
- Gerçek piyasa verisi, performans kampanyası, GPU kernel ve beş-seed kabul
  çalışması henüz tamamlanmadı.
