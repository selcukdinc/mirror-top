## v0.0.6 — Dock Uygulaması & Tema Sistemi

### Yeni
- 🎨 4 tema (Klasik, Gece, Okyanus, Gün Batımı)
- 🪟 **Dock Uygulaması**: PiP yönetimi, saydamlık, tema, ayarlar ve hakkında — tek merkezde
- 🌫️ Per-PiP saydamlık denetimi + master override
- 🔁 Dock'tan kapatılmış PiP'leri yeniden açma (kayıtlı pozisyon/boyut ile)
- 🔍 Dock grid'inde akıcı pinch-zoom

### Geliştirildi
- Etkileşim modunda fare artık **hiçbir koşulda** hedef pencereye ışınlanmıyor
- Saydamlık ve tema seçimi üst bardan da hızlı erişilebilir
- Künye Dock Uygulaması → Hakkında sekmesine taşındı

### Kurulum
Bu build notarize değildir. `MirrorTop.app`'i `/Applications`'a sürükledikten sonra:
- Sağ tık → **Aç** → **Aç** (tek seferlik onay), veya
- `xattr -dr com.apple.quarantine /Applications/MirrorTop.app`
