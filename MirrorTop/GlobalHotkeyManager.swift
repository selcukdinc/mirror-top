import Foundation
import Carbon
import AppKit

/// Carbon `RegisterEventHotKey` ile global kısayolları kaydeder.
/// Kısayollar `SettingsManager` üzerinden okunur; kullanıcı değiştirirse `reloadShortcuts()` çağrılır.
@MainActor
public final class GlobalHotkeyManager {
    public static let shared = GlobalHotkeyManager()
    
    private var captureHotKeyRef: EventHotKeyRef?
    private var interactionHotKeyRef: EventHotKeyRef?
    private var handlerInstalled = false
    
    /// Kısayollar tetiklendiğinde çalıştırılacak kapanışlar.
    public var onCaptureToggleTriggered: (() -> Void)?
    public var onInteractionToggleTriggered: (() -> Void)?
    
    private init() {}
    
    /// İlk kayıt: handler'ı kur ve UserDefaults'tan okunan kısayolları aktive et.
    public func registerHotkey() {
        installEventHandlerIfNeeded()
        reloadShortcuts()
    }
    
    /// Kullanıcı kısayolu değiştirdiğinde çağrılır. Eski kayıtları kaldırır, yenilerini kurar.
    public func reloadShortcuts() {
        if let ref = captureHotKeyRef {
            UnregisterEventHotKey(ref)
            captureHotKeyRef = nil
        }
        if let ref = interactionHotKeyRef {
            UnregisterEventHotKey(ref)
            interactionHotKeyRef = nil
        }
        
        let appTarget = GetApplicationEventTarget()
        
        let captureSC = SettingsManager.shared.captureShortcut
        let interactionSC = SettingsManager.shared.interactionShortcut
        
        var captureID = EventHotKeyID()
        captureID.signature = OSType(fourCharCode: "ATOP")
        captureID.id = 1
        RegisterEventHotKey(captureSC.keyCode, captureSC.modifiers, captureID, appTarget, 0, &captureHotKeyRef)
        
        var interactionID = EventHotKeyID()
        interactionID.signature = OSType(fourCharCode: "AINT")
        interactionID.id = 2
        RegisterEventHotKey(interactionSC.keyCode, interactionSC.modifiers, interactionID, appTarget, 0, &interactionHotKeyRef)
        
        print(">>> [HotKey] Kısayollar güncellendi → capture: \(captureSC.displayString), interaction: \(interactionSC.displayString)")
    }
    
    private func installEventHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        let appTarget = GetApplicationEventTarget()
        
        let handler: EventHandlerUPP = { (_, theEvent, _) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(theEvent,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hotKeyID)
            
            Task { @MainActor in
                if hotKeyID.id == 1 {
                    GlobalHotkeyManager.shared.onCaptureToggleTriggered?()
                } else if hotKeyID.id == 2 {
                    GlobalHotkeyManager.shared.onInteractionToggleTriggered?()
                }
            }
            return noErr
        }
        
        InstallEventHandler(appTarget, handler, 1, &eventType, nil, nil)
        handlerInstalled = true
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
