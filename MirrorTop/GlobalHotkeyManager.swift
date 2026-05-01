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
    private var sizeSmallHotKeyRef: EventHotKeyRef?
    private var sizeMediumHotKeyRef: EventHotKeyRef?
    private var sizeLargeHotKeyRef: EventHotKeyRef?
    private var handlerInstalled = false
    
    /// Kısayollar tetiklendiğinde çalıştırılacak kapanışlar.
    public var onCaptureToggleTriggered: (() -> Void)?
    public var onInteractionToggleTriggered: (() -> Void)?
    /// Boyut kısayolları (küçük/orta/büyük).
    public var onSizePresetTriggered: ((SizePreset) -> Void)?
    
    public enum SizePreset {
        case small   // ¼
        case medium  // ½
        case large   // 1:1 (kaynak pencerenin gerçek boyutu)
    }
    
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
        for refPtr in [sizeSmallHotKeyRef, sizeMediumHotKeyRef, sizeLargeHotKeyRef] {
            if let ref = refPtr { UnregisterEventHotKey(ref) }
        }
        sizeSmallHotKeyRef = nil; sizeMediumHotKeyRef = nil; sizeLargeHotKeyRef = nil
        
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
        
        // Boyut kısayolları (sabit, kullanıcı henüz özelleştiremiyor): Cmd+Opt+1/2/3.
        let mods = UInt32(cmdKey | optionKey)
        var sizeSmallID = EventHotKeyID(signature: OSType(fourCharCode: "ASZ1"), id: 4)
        RegisterEventHotKey(UInt32(kVK_ANSI_1), mods, sizeSmallID, appTarget, 0, &sizeSmallHotKeyRef)
        var sizeMediumID = EventHotKeyID(signature: OSType(fourCharCode: "ASZ2"), id: 5)
        RegisterEventHotKey(UInt32(kVK_ANSI_2), mods, sizeMediumID, appTarget, 0, &sizeMediumHotKeyRef)
        var sizeLargeID = EventHotKeyID(signature: OSType(fourCharCode: "ASZ3"), id: 6)
        RegisterEventHotKey(UInt32(kVK_ANSI_3), mods, sizeLargeID, appTarget, 0, &sizeLargeHotKeyRef)
        _ = (sizeSmallID, sizeMediumID, sizeLargeID) // suppress unused-mutated warning
        
        print(">>> [HotKey] Kısayollar güncellendi → capture: \(captureSC.displayString), interaction: \(interactionSC.displayString), size: ⌘⌥1/2/3")
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
                } else if hotKeyID.id == 4 {
                    GlobalHotkeyManager.shared.onSizePresetTriggered?(.small)
                } else if hotKeyID.id == 5 {
                    GlobalHotkeyManager.shared.onSizePresetTriggered?(.medium)
                } else if hotKeyID.id == 6 {
                    GlobalHotkeyManager.shared.onSizePresetTriggered?(.large)
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
