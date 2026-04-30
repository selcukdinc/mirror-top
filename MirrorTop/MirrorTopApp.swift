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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print(">>> [DEBUG] Uygulama başlatıldı.")
        
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
        
        // İzin kontrolü → eksikse modern onboarding penceresi.
        PermissionsManager.shared.refresh()
        if !PermissionsManager.shared.allGranted {
            showOnboarding()
        } else {
            print(">>> [DEBUG] Tüm izinler mevcut. Menü çubuğundan kullanıma hazır.")
        }
    }
    
    /// Onboarding penceresini açar (zaten açıksa öne getirir).
    /// LSUIElement = YES olduğu için NSWindow'u manuel oluşturuyoruz.
    func showOnboarding() {
        if let existing = onboardingWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let view = OnboardingView(
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
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.onboardingWindow = window
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
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.aboutWindow = window
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        let w = notification.object as? NSWindow
        if w === onboardingWindow { onboardingWindow = nil }
        if w === aboutWindow { aboutWindow = nil }
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
                showAbout: { appDelegate.showAbout() }
            )
            .environmentObject(permissions)
        } label: {
            Image(systemName: "rectangle.on.rectangle.angled")
        }
        .menuBarExtraStyle(.menu)
    }
}

