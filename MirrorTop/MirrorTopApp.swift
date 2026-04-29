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
            GlobalHotkeyManager.shared.onHotKeyTriggered = {
                Task {
                    do {
                        print(">>> [DEBUG] Odaklanılmış pencere aranıyor...")
                        if let windowInfo = try await WindowManager.shared.getFocusedWindow() {
                            print(">>> [DEBUG] Bulunan Pencere: \(windowInfo.title) (PID: \(windowInfo.pid), ID: \(windowInfo.cgWindowID))")
                            print(">>> [DEBUG] StreamManager toggleCapture başlatılıyor...")
                            try await StreamManager.shared.toggleCapture(windowInfo: windowInfo)
                        } else {
                            print(">>> [DEBUG] HATA: Odakta geçerli bir pencere bulunamadı.")
                        }
                    } catch {
                        print(">>> [DEBUG] HATA: İşlem sırasında hata oluştu: \(error)")
                    }
                }
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
