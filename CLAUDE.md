# MirrorTop — Proje Analizi (Claude / Antigravity Notları)

## 1. Proje Özeti

**MirrorTop**, Windows PowerToys'taki *"Always on Top"* özelliğini macOS Sonoma/Sequoia'ya getiren, Swift / SwiftUI tabanlı bir menü çubuğu (Agent / `LSUIElement`) uygulamasıdır.

macOS, üçüncü parti uygulamaların pencere seviyesini doğrudan değiştirmeye SIP olmadan izin vermediği için, klasik "Always on Top" yerine **pencere yansıtma (window mirroring)** yaklaşımı seçilmiştir:

- Hedef pencere `ScreenCaptureKit` ile yakalanır.
- Yakalanan görüntü, `.floating` seviyesindeki şeffaf bir `NSPanel` içinde 60 FPS olarak render edilir.
- İsteğe bağlı *Etkileşim Modu* (Interaction Mode) ile fare/klavye olayları `CGEvent.postToPid` üzerinden orijinal pencereye iletilir.

## 2. Mimari ve Modül Sorumlulukları

| Dosya | Sorumluluk |
|---|---|
| [MirrorTop/MirrorTopApp.swift](MirrorTop/MirrorTopApp.swift) | `AppDelegate` — başlangıçta Erişilebilirlik + Ekran Kaydı izinleri, kısayolları kaydetme, `StreamManager` köprüsü. |
| [MirrorTop/AccessibilityManager.swift](MirrorTop/AccessibilityManager.swift) | `AXIsProcessTrusted()` kontrolü ve izin verilmediğinde Sistem Ayarları + Finder yönlendirmesi. |
| [MirrorTop/GlobalHotkeyManager.swift](MirrorTop/GlobalHotkeyManager.swift) | Carbon `RegisterEventHotKey` ile `Cmd+Opt+T` (Capture Toggle) ve `Cmd+Opt+I` (Interaction Toggle) genel kısayolları. |
| [MirrorTop/WindowManager.swift](MirrorTop/WindowManager.swift) | `AXUIElement` ile odaktaki pencerenin başlık/konum/boyut bilgisini, ardından `SCShareableContent` ile `CGWindowID` çözümlemesi (fallback dahil). |
| [MirrorTop/StreamManager.swift](MirrorTop/StreamManager.swift) | `SCStream` yaşam döngüsü, kare alma, panel boyut senkronizasyonu, `didStopWithError` ile otomatik yeniden başlatma. |
| [MirrorTop/FloatingPanel.swift](MirrorTop/FloatingPanel.swift) | `.floating` seviyeli, şeffaf, tüm Space'lerde görünen `NSPanel` (`.titled` + `fullSizeContentView` ile native resize). |
| [MirrorTop/CapturePreviewView.swift](MirrorTop/CapturePreviewView.swift) | `CALayer` + `VTCreateCGImageFromCVPixelBuffer` ile kare render; etkileşim modunda `CGEvent` köprüleme. |
| [MirrorTop/ContentView.swift](MirrorTop/ContentView.swift) | Görünmez SwiftUI ana pencere (uygulama Agent modunda olduğu için kullanılmıyor). |

## 3. Mevcut Yetenekler (Çalışan)

- ✅ Erişilebilirlik + Ekran Kaydı izin akışı (otomatik prompt + Sistem Ayarları yönlendirmesi).
- ✅ `Cmd+Opt+T` ile herhangi bir uygulamadaki odaklı pencerenin yansıtılması.
- ✅ `Cmd+Opt+I` ile *Etkileşim Modu* (mavi çerçeve + fare/klavye event forwarding).
- ✅ `AXCGWindowIdentifier` öncelikli, `SCShareableContent` fallback'li pencere ID çözümleme.
- ✅ Hedef pencere boyut değiştirdiğinde (resize) panelin canlı orantılı yeniden boyutlandırılması (`SCStreamFrameInfo.contentRect`).
- ✅ `ignoreShadowsSingleWindow` ile çerçeve hizalama tutarlılığı.
- ✅ Kullanıcı yayını manuel durdurursa (`SCStreamError.userStopped`) otomatik yeniden başlatma iptal.
- ✅ Sonsuz çökme döngüsünü engelleyen `consecutiveRestarts` sayacı (≤3).

## 4. Bilinen Sorun (Çözülmesi İstenen)

> Mirror'lanmış (Always on Top yapılmış) pencere veya MirrorTop uygulamasının kendisi, kısayolla ikinci kez kapatıldığında / bazı durumlarda çöküyor.

### 4.1 Kök Neden Analizi

Konsol çıktısı `"ScreenCaptureKit ile ID eşleştirildi: 4238"` satırından sonra aniden kesiliyor; ardından gelen `StreamManager` log'u yok. Bu, `toggleCapture` çağrısı sırasında *sessiz bir çökmenin* (silent crash) yaşandığını gösterir.

İncelenen kodda **üç ciddi risk** tespit edildi:

1. **`NSPanel` çift-release crash (en olası neden)**
   `FloatingPanel`, `NSWindow`'dan miras aldığı `isReleasedWhenClosed` özelliğini varsayılan `true` ile bırakıyor. `closePanel()` içinde `orderOut(nil)` + `activePanel = nil` yapılınca AppKit referansı release ediyor, bizim güçlü referansımız da release edince **double-free → SIGSEGV** oluşabiliyor. Bu, `.titled` panellerde klasik bir AppKit tuzağıdır.

2. **Kendini yansıtma (recursive capture) tehlikesi**
   Etkileşim Modu `AÇIK` iken kullanıcı panele tıklayınca MirrorTop önplana geçer. O sırada `Cmd+Opt+T`'ye basılırsa `WindowManager.getFocusedWindow()` *bizim* `FloatingPanel`'in `CGWindowID`'sini döndürür. `StreamManager` farklı ID gördüğü için önceki yayını durdurup MirrorTop'un kendi panelini yakalamaya başlar → görsel feedback loop → GPU/bellek aşımı → crash.

3. **`stopCapture` sırasında artık kare (stale frame) yarış koşulu**
   `currentStream.stopCapture()` `await` ederken, `sampleHandlerQueue` üzerinde zaten sıraya girmiş olan kareler `DispatchQueue.main.async` ile main'e atılmış olabiliyor. Bunlar, `previewView` referansı `nil` olmadan önce `enqueue` çağırarak `videoLayer.contents`'i güncelleyebiliyor — kritik değil ama panelin reset'lendiği anla çakıştığında AppKit assertion'larını tetikleyebiliyor.

### 4.2 Uygulanan Çözümler

Bu commit'te aşağıdaki düzeltmeler yapıldı:

- **(1)** `FloatingPanel.init` içine `self.isReleasedWhenClosed = false` eklendi. Panel artık yalnızca Swift güçlü referansı sıfırlandığında ARC tarafından serbest bırakılır.
- **(2)** `WindowManager.getFocusedWindow()` MirrorTop'un *kendi* PID'sine ait pencereleri tespit edip `nil` döndürerek recursive capture'ı engeller. `StreamManager` da güvenlik ağı olarak kendi PID'sine eşleşen `windowInfo`'yu reddeder.
- **(3)** `StreamManager.stopCapture` artık önce stream output'u (`removeStreamOutput`) kaldırıyor, ardından stream'i durduruyor. Böylece stop sırasında yeni kare gelmiyor.
- Ek olarak `Cmd+Opt+T` ile *aynı* pencereye tekrar basıldığında temiz kapanışı garantilemek için `originalWindowInfo` artık `stopCapture`'ın **en başında** `nil`'lanır; böylece `didStopWithError` yeniden başlatma akışı da tetiklenmez.

### 4.3 Uzun Süreli Yayın Sorunu — Sessiz Restart (Silent Restart)

**Belirti:** Yayın 5-6 dakika sorunsuz çalıştıktan sonra macOS, `SCStream`'i sistem politikası gereği aniden durduruyordu (`Yayın hatayla durdu: Duraksız yayın sistem tarafından durduruldu`, ardından `-3808` kodu). Auto-restart mantığı çalışıyordu ancak `stopCapture()` paneli tamamen kapatıp yeniden açtığı için kullanıcı kapanma/açılma flicker'ı görüyordu.

**Çözüm:** [StreamManager.swift](MirrorTop/StreamManager.swift) içinde `silentRestart(for:)` metodu eklendi.

- Paneli ve `previewView`'i **kapatmaz**, yalnızca alttaki `SCStream`'i yeniden oluşturur.
- Son kare `CALayer.contents`'te freeze olarak kalır; yeni stream başladığı anda render kaldığı yerden devam eder.
- `interactionMode` durumu korunur, panel pozisyon/boyutu sıfırlanmaz.
- `didStopWithError` callback'inde `stoppedStream === self.stream` identity kontrolü eklendi; eski stream'lerin geç gelen hata mesajları artık gürültü oluşturmuyor.
- `userStopped` veya `consecutiveRestarts > 3` durumunda paneli tamamen kapatma davranışı korundu.

## 5. İzin Gereksinimleri (Hatırlatma)

- **Accessibility** (Erişilebilirlik) — `AXUIElement` ile odaktaki pencereyi okumak ve `CGEvent.postToPid` ile event forwarding için.
- **Screen Recording** (Ekran Kaydı) — `SCStream` ve `SCShareableContent` için.
- `Info.plist` → `LSUIElement = YES` (menü çubuğu / agent modu).

## 6. İlerideki Geliştirme Notları

- Menü çubuğu ikonu + tercihler menüsü (şu anda görünmez bir `WindowGroup` kullanılıyor).
- Birden fazla pencerenin aynı anda yansıtılması (multi-mirror).
- Hot-corner veya doğrudan `NSStatusItem` ile manuel pencere seçimi (kısayol gerektirmeden).
- Kullanıcının panel boyut/konumunu pencere ID'sine göre hatırlama (`UserDefaults`).
