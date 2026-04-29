//
//  MirrorTopApp.swift
//  MirrorTop
//
//  Created by Selçuk DİNÇ on 29.04.2026.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print(">>> [DEBUG] Uygulama başlatıldı. İzinler kontrol ediliyor...")
        
        // 0. Ekran Kaydı (Screen Recording) iznini iste (ScreenCaptureKit için şart)
        let hasScreenCaptureAccess = CGPreflightScreenCaptureAccess()
        if !hasScreenCaptureAccess {
            print(">>> [DEBUG] Ekran Kaydı izni eksik. Sistemden izin isteniyor...")
            CGRequestScreenCaptureAccess()
        }
        
        // 1. İzinleri kontrol et (Erişilebilirlik)
        let isTrusted = AccessibilityManager.shared.checkAndPrompt()
        
        if isTrusted && hasScreenCaptureAccess {
            print(">>> [DEBUG] Erişilebilirlik izni mevcut. Kısayol kaydediliyor...")
            // 2. Kısayolu kaydet
            GlobalHotkeyManager.shared.registerHotkey()
            
            // 3. Kısayol tetiklendiğinde StreamManager'ı çağır
            GlobalHotkeyManager.shared.onCaptureToggleTriggered = {
                Task {
                    do {
                        if let windowInfo = try await WindowManager.shared.getFocusedWindow() {
                            try await StreamManager.shared.toggleCapture(windowInfo: windowInfo)
                        } else {
                            print(">>> [DEBUG] HATA: Odakta geçerli bir pencere bulunamadı.")
                        }
                    } catch {
                        print(">>> [DEBUG] HATA: İşlem sırasında hata oluştu: \(error)")
                    }
                }
            }
            
            // 4. Etkileşim modu (Interaction Mode) aç/kapat
            GlobalHotkeyManager.shared.onInteractionToggleTriggered = {
                StreamManager.shared.toggleInteractionMode()
            }
        } else {
            print(">>> [DEBUG] UYARI: Erişilebilirlik izni yok! Sistem Ayarları'ndan izin verilmesi bekleniyor.")
        }
    }
}

@main
struct MirrorTopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
