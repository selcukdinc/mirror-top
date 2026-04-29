import Foundation
import Carbon
import AppKit

@MainActor
public final class GlobalHotkeyManager {
    public static let shared = GlobalHotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    
    /// Kısayol tetiklendiğinde çalıştırılacak kapanış (closure)
    public var onHotKeyTriggered: (() -> Void)?
    
    private init() {}
    
    /// Arka planda çalışırken genel (global) kısayolu (Cmd+Option+T) dinlemeye başlar.
    public func registerHotkey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(fourCharCode: "ATOP")
        hotKeyID.id = 1
        
        // Cmd(cmdKey) + Option(optionKey) + T (kVK_ANSI_T = 17)
        let modifierFlags: UInt32 = UInt32(cmdKey | optionKey)
        let keyCode: UInt32 = 17 
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        let appTarget = GetApplicationEventTarget()
        
        // C tarzı handler fonksiyonu
        let handler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            print(">>> [DEBUG] Kısayol (Cmd+Option+T) Carbon EventHandler tarafından algılandı!")
            Task { @MainActor in
                if GlobalHotkeyManager.shared.onHotKeyTriggered == nil {
                    print(">>> [DEBUG] UYARI: onHotKeyTriggered atanmamış! Lütfen App veya AppDelegate içinde atamayı yapın.")
                } else {
                    print(">>> [DEBUG] onHotKeyTriggered tetikleniyor...")
                    GlobalHotkeyManager.shared.onHotKeyTriggered?()
                }
            }
            return noErr
        }
        
        InstallEventHandler(appTarget, handler, 1, &eventType, nil, nil)
        
        let status = RegisterEventHotKey(keyCode, modifierFlags, hotKeyID, appTarget, 0, &hotKeyRef)
        if status != noErr {
            print("Global kısayol kaydedilirken hata oluştu: \(status)")
        } else {
            print("Cmd+Option+T kısayolu başarıyla kaydedildi.")
        }
    }
}

// OSType için yardımcı eklenti (String'den 4 karakterlik koda çevirme)
extension OSType {
    init(fourCharCode: String) {
        var result: OSType = 0
        if let data = fourCharCode.data(using: .macOSRoman) {
            for (index, byte) in data.enumerated() where index < 4 {
                result = (result << 8) | OSType(byte)
            }
        }
        self = result
    }
}
