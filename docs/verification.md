# Başlangıç doğrulaması

14.10.2026, yalnız bu başlangıç paketinin yazılım kontrolleri.

- GCC 13.3.0, C++17 ile core, CLI ve test executable derlendi.
- `-O2 -Wall -Wextra -Wpedantic` derlemesinde uyarı yok.
- Deterministik core testleri geçti: bilinen normal kuantiller, nearest-rank,
  sıfır ufuk, sıfır volatilite, negatif VaR, ortak girdiler, aynı build'de seed
  tekrarı ve hatalı girdilerin reddedilmesi.
- Sabit sentetik demo N=10000, seed=42 ile çalıştı. %95/%99 VaR üretildi.
- UndefinedBehaviorSanitizer ile testler geçti. Birleşik AddressSanitizer/
  UndefinedBehaviorSanitizer koşusu ortamın LeakSanitizer /proc erişim hatası
  nedeniyle tamamlanamadı; bellek sızıntısı kontrolü geçti olarak sayılmadı.
- Bu ortamda CMake executable veya Python cmake modülü bulunmadığından CMake/CTest
  çalıştırılmadı. Kaynaklar doğrudan g++ ile kontrol edildi. Yerelde CMake/CTest
  ve daha sonra CI ayrıca doğrulanmalı.
- nvcc ve nvidia-smi bulunmadı; CUDA uyumluluğu ve çalışması doğrulanmadı.
- Kullanıcının hedef donanımı ölçülmedi; performans başarısı iddiası yok.
- Beş seed / 10 milyon senaryo kabul çalışması henüz yapılmadı.

Bu kontroller matematiksel/programlama başlangıcıdır; onaylı proposal'ın tüm
doğruluk ve performans başarı koşullarının karşılandığı anlamına gelmez.
