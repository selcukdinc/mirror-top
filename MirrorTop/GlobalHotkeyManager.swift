import Foundation
import Carbon
import AppKit

@MainActor
public final class GlobalHotkeyManager {
    public static let shared = GlobalHotkeyManager()
    
    private var captureHotKeyRef: EventHotKeyRef?
    private var interactionHotKeyRef: EventHotKeyRef?
    
    /// Kısayol tetiklendiğinde çalıştırılacak kapanış (closure)
    public var onCaptureToggleTriggered: (() -> Void)?
    public var onInteractionToggleTriggered: (() -> Void)?
    
    private init() {}
    
    /// Arka planda çalışırken genel (global) kısayolu (Cmd+Option+T) dinlemeye başlar.
    public func registerHotkey() {
        var captureHotKeyID = EventHotKeyID()
        captureHotKeyID.signature = OSType(fourCharCode: "ATOP")
        captureHotKeyID.id = 1
        
        var interactionHotKeyID = EventHotKeyID()
        interactionHotKeyID.signature = OSType(fourCharCode: "AINT")
        interactionHotKeyID.id = 2
        
        // Cmd(cmdKey) + Option(optionKey)
        let modifierFlags: UInt32 = UInt32(cmdKey | optionKey)
        let keyCodeT: UInt32 = 17 // T
        let keyCodeI: UInt32 = 34 // I
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        let appTarget = GetApplicationEventTarget()
        
        // C tarzı handler fonksiyonu
        let handler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            Task { @MainActor in
                if hotKeyID.id == 1 {
                    print(">>> [DEBUG] Cmd+Option+T (Capture Toggle) algılandı!")
                    GlobalHotkeyManager.shared.onCaptureToggleTriggered?()
                } else if hotKeyID.id == 2 {
                    print(">>> [DEBUG] Cmd+Option+I (Interaction Toggle) algılandı!")
                    GlobalHotkeyManager.shared.onInteractionToggleTriggered?()
                }
            }
            return noErr
        }
        
        InstallEventHandler(appTarget, handler, 1, &eventType, nil, nil)
        
        RegisterEventHotKey(keyCodeT, modifierFlags, captureHotKeyID, appTarget, 0, &captureHotKeyRef)
        RegisterEventHotKey(keyCodeI, modifierFlags, interactionHotKeyID, appTarget, 0, &interactionHotKeyRef)
        print(">>> [DEBUG] Cmd+Option+T ve Cmd+Option+I kısayolları kaydedildi.")
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
