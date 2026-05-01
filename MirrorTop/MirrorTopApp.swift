//
//  MirrorTopApp.swift
//  MirrorTop
//
//  Created by Selçuk DİNÇ on 29.04.2026.
//

import SwiftUI
import AppKit

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var dockModeWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print(">>> [DEBUG] Uygulama başlatıldı.")
        
        // Varsayılan: agent (LSUIElement). Pencere açılınca .regular'a geçeceğiz ki Cmd+Tab'da görünsün.
        NSApp.setActivationPolicy(.accessory)
        
        // Kısayolu erkenden kuruyoruz; izin yoksa zaten WindowManager nil döner.
        GlobalHotkeyManager.shared.registerHotkey()
        
        GlobalHotkeyManager.shared.onCaptureToggleTriggered = { [weak self] in
            guard let self else { return }
            // İzinler eksikse onboarding'i göster (sessizce başarısız olmak yerine).
            if !PermissionsManager.shared.allGranted {
                PermissionsManager.shared.refresh()
                if !PermissionsManager.shared.allGranted {
                    self.showOnboarding()
                    return
                }
            }
            Task { @MainActor in
                do {
                    if let windowInfo = try await WindowManager.shared.getFocusedWindow() {
                        try await StreamManager.shared.toggleCapture(windowInfo: windowInfo)
                    } else {
                        print(">>> [DEBUG] Odakta geçerli bir pencere bulunamadı.")
                    }
                } catch {
                    print(">>> [DEBUG] HATA: \(error)")
                }
            }
        }
        
        GlobalHotkeyManager.shared.onInteractionToggleTriggered = {
            StreamManager.shared.toggleInteractionMode()
        }
        
        GlobalHotkeyManager.shared.onSizePresetTriggered = { preset in
            StreamManager.shared.applyPresetSize(preset)
        }
        
        // İzin kontrolü → eksikse modern onboarding penceresi.
        PermissionsManager.shared.refresh()
        if !PermissionsManager.shared.allGranted {
            showOnboarding()
        } else {
            print(">>> [DEBUG] Tüm izinler mevcut. Menü çubuğundan kullanıma hazır.")
        }
        
        // Açılışta güncelleme kontrolü (sadece kullanıcı ayarlardan açtıysa).
        UpdateChecker.shared.checkOnLaunchIfEnabled()
    }
    
    /// Onboarding penceresini açar (zaten açıksa öne getirir).
    /// LSUIElement = YES olduğu için NSWindow'u manuel oluşturuyoruz.
    func showOnboarding() {
        presentOnboarding(mode: .welcome)
    }
    
    /// Menüden "İzinleri Yönet" seçildiğinde açılır — hoş geldin başlığı yerine sade
    /// "İzinleri Yönet" başlığı gösterir.
    func showPermissions() {
        presentOnboarding(mode: .manage)
    }
    
    private func presentOnboarding(mode: OnboardingView.Mode) {
        if let existing = onboardingWindow {
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let view = OnboardingView(
            mode: mode,
            onContinue: { [weak self] in
                self?.onboardingWindow?.close()
            },
            onShowHelp: { [weak self] in
                self?.showAbout()
            }
        )
        
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "MirrorTop"
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.center()
        window.delegate = self
        // Dock'ta ikon yok, başka uygulamaların pencerelerinin altında doğmasın diye
        // önce activation politikasını .regular yap, sonra activate + orderFrontRegardless.
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        self.onboardingWindow = window
        updateActivationPolicy()
    }
    
    /// Hakkında / Yardım penceresini açar (zaten açıksa öne getirir).
    func showAbout() {
        if let existing = aboutWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let view = AboutView { [weak self] in
            self?.aboutWindow?.close()
        }
        
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Mirror Top — Hakkında"
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.center()
        window.delegate = self
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        self.aboutWindow = window
        updateActivationPolicy()
    }
}

extension AppDelegate {
    /// Dock-mode (tüm PiP'ler grid'i) penceresini açar.
    func showDockMode() {
        if let existing = dockModeWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: DockModeView())
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Mirror Top — \(Strings.dockModeTitle)"
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 880, height: 560))
        window.center()
        window.delegate = self
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        self.dockModeWindow = window
        updateActivationPolicy()
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        let w = notification.object as? NSWindow
        if w === onboardingWindow { onboardingWindow = nil }
        if w === aboutWindow { aboutWindow = nil }
        if w === dockModeWindow { dockModeWindow = nil }
        updateActivationPolicy()
    }
    
    /// Açık ayar/about/onboarding penceresi varsa Cmd+Tab'da görünebilmek için 
    /// uygulamayı `.regular` aktivasyon politikasına geçirir; tüm pencereler
    /// kapanınca tekrar `.accessory` (LSUIElement) modunda çalışmaya devam eder.
    fileprivate func updateActivationPolicy() {
        let hasVisibleWindow = (onboardingWindow != nil) || (aboutWindow != nil) || (dockModeWindow != nil)
        if hasVisibleWindow {
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
            }
        } else {
            // Pencere kapandı; menü çubuğu uygulamasına geri dön.
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

// MARK: - SwiftUI App

@main
struct MirrorTopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var permissions = PermissionsManager.shared
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(
                showOnboarding: { appDelegate.showOnboarding() },
                showPermissions: { appDelegate.showPermissions() },
                showAbout: { appDelegate.showAbout() },
                showDockMode: { appDelegate.showDockMode() }
            )
            .environmentObject(permissions)
        } label: {
            Image(systemName: "rectangle.on.rectangle.angled")
        }
        .menuBarExtraStyle(.menu)
    }
}

