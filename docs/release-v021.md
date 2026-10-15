# Sürüm doğrulaması v0.2.1

15.10.2026. Kaynak ve derleme sürümünü ayırt etmek için `--version` eklendi.
CSV modeli veya kestirim yöntemi değiştirilmedi.

Paylaşılan v0.2 ZIP'in yerel kopyası incelendi: CSV main.cpp ve üç testli
CMakeLists.txt içeriyordu. Kullanıcının 15.10.2026 tarihli çıktısında main.cpp
CSV dalını içermiyor, CMake yalnız core_tests oluşturuyordu. Windows'ta kaynakların
hangi aşamada farklılaştığı bilinmiyor. Bu durum önbellek değiştirerek çözülemez;
birbiriyle tutarlı kaynak dosyaları birlikte kullanılmalıdır.

v0.2.1 ayrı bir paket olarak hazırlanır. ZIP açılarak içindeki kaynaklardan
core ve veri testleri derlenir, CLI sürümü ve CSV hattı kontrol edilir.
Bu doğrulama GCC/Linux içindir; MSVC/Windows CMake testi kullanıcıda yapılır.
