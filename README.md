# 🪞 MirrorTop

> **Always on Top, the macOS way.**
> Bring Windows PowerToys' beloved *“Always on Top”* feature to macOS Sonoma / Sequoia / Tahoe — without SIP hacks, without unsigned kernel extensions, without `dock` tricks.

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-blue?logo=apple" />
  <img src="https://img.shields.io/badge/Swift-6-orange?logo=swift" />
  <img src="https://img.shields.io/badge/SwiftUI-✓-purple" />
  <img src="https://img.shields.io/badge/ScreenCaptureKit-✓-green" />
  <img src="https://img.shields.io/badge/license-MIT-lightgrey" />
</p>

---

## ✨ What is MirrorTop?

macOS does not allow third-party apps to elevate other applications' window levels without disabling SIP. MirrorTop solves this elegantly: instead of *moving* the window, it **mirrors** it.

- The focused window is captured with **`ScreenCaptureKit`** at 60 FPS.
- The captured frames are rendered into a transparent, floating-level **`NSPanel`**.
- Optionally, an **Interaction Mode** forwards mouse and keyboard events back to the original window through `CGEvent.postToPid`, so the mirrored panel *behaves* like the real window — typing, clicking, scrolling all work.

The result feels indistinguishable from a real Always-on-Top mode, but it requires no SIP modifications and works on every modern macOS.

---

## 🎯 Features

- 🔝 **Pin any window on top** with `⌘ + ⌥ + T`
- 🖱️ **Interactive mirror** with `⌘ + ⌥ + I` — click and type into the mirrored panel; events get forwarded to the source app.
- 🪟 **Native resize** — drag any panel edge; aspect ratio is locked to the source window.
- 🔄 **Live aspect tracking** — when the source window is resized, the panel follows in real time.
- 🌌 **Survives Spaces & full-screen** — panel stays visible across all desktops.
- 🧠 **Silent restart** — macOS sometimes terminates long-running `SCStream`s after several minutes; MirrorTop recovers transparently, keeping the last frame frozen on screen with zero flicker.
- 🛡️ **Recursive-capture protection** — won't accidentally mirror its own panel and create a feedback loop.
- 🍎 **Pure menu bar app** (`LSUIElement`) — no Dock icon, no clutter.
- 🎨 **Modern SwiftUI onboarding** — friendly permission cards with live status; no Finder pop-ups.

---

## 🚀 Quick Start

### Install

1. Download the latest `MirrorTop.app` from [Releases](../../releases) (or build from source — see below).
2. Drag it into `/Applications`.
3. Launch it. It will appear in the menu bar (`⊞ on ⊞` icon, top right).

### First-Run Permissions

On first launch, a polished onboarding window appears. MirrorTop requires **two** macOS permissions:

| Permission | Why we need it |
|---|---|
| **Accessibility** | To read which window is currently focused (`AXUIElement`) and to forward your clicks/keys to the source app in Interaction Mode. |
| **Screen Recording** | To capture the target window's pixels using `ScreenCaptureKit`. |

Click **“İzin Ver”** on each card; macOS will open the relevant Settings pane. The cards update **live** as you toggle the switches — no app restart needed.

### Daily Use

| Action | Shortcut |
|---|---|
| Toggle Always-on-Top mirror for the focused window | `⌘ + ⌥ + T` |
| Toggle Interaction Mode for the active mirror | `⌘ + ⌥ + I` |
| Open menu | Click the 🪞 icon in the menu bar |
| Quit | `⌘ + Q` (when menu bar item is open) |

When Interaction Mode is **ON**, the mirrored panel shows a blue border, becomes clickable, and forwards every event to the original window — handy for keeping a video call, terminal, or notes pinned while typing somewhere else.

---

## 🏗️ Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│ GlobalHotkey    │────▶│  WindowManager   │────▶│   StreamManager  │
│   (Carbon)      │     │  AXUIElement +   │     │   SCStream +     │
│ ⌘⌥T / ⌘⌥I       │     │  ScreenCaptureKit│     │   FloatingPanel  │
└─────────────────┘     └──────────────────┘     └────────┬─────────┘
                                                          │
                                                          ▼
                                              ┌─────────────────────┐
                                              │ CapturePreviewView  │
                                              │  CALayer +  CGEvent │
                                              │  (mouse/keyboard    │
                                              │   forwarding)       │
                                              └─────────────────────┘
```

| File | Responsibility |
|---|---|
| `MirrorTopApp.swift` | App entry point. `MenuBarExtra` scene + onboarding `NSWindow`. |
| `PermissionsManager.swift` | Live-polled permission state for Accessibility + Screen Recording. |
| `OnboardingView.swift` | Modern SwiftUI permission onboarding with status badges. |
| `MenuBarContent.swift` | Menu bar dropdown items (mirror toggle, interaction toggle, about, quit). |
| `GlobalHotkeyManager.swift` | Carbon `RegisterEventHotKey` for `⌘⌥T` and `⌘⌥I`. |
| `WindowManager.swift` | Resolves focused window via `AXUIElement`, falls back to `SCShareableContent` for `CGWindowID`. |
| `StreamManager.swift` | `SCStream` lifecycle, frame routing, panel resize, silent auto-restart. |
| `FloatingPanel.swift` | Transparent `.floating`-level `NSPanel`, all-spaces, native resize. |
| `CapturePreviewView.swift` | `CALayer` rendering + `CGEvent.postToPid` event forwarding. |
| `AccessibilityManager.swift` | Thin wrapper around `AXIsProcessTrusted` (kept for back-compat). |

### Why mirroring instead of `kCGFloatingWindowLevel`?

Apple does not expose any sanctioned way to elevate **another process's** window above your own. Tools that claim to do this on modern macOS either:

- require disabling SIP,
- inject code (Apple no longer permits this for App Store/notarized apps),
- or only work on the *current* app's own windows.

Mirroring sidesteps all of that. The cost is one extra render pass — negligible on Apple Silicon.

---

## 🛠️ Build From Source

### Requirements

- macOS 13 (Ventura) or newer — recommended **macOS 14+** for best `ScreenCaptureKit` stability.
- Xcode 15 or newer (Swift 6 toolchain).

### Steps

```bash
git clone https://github.com/<your-username>/MirrorTop.git
cd MirrorTop
open MirrorTop.xcodeproj
```

Then in Xcode:
1. Select the **MirrorTop** scheme.
2. Set your **Team** under *Signing & Capabilities* (any free Apple ID works for local builds).
3. ⌘R to run.

Because MirrorTop is a `LSUIElement` app, no Dock icon will appear — look for the 🪞 in the menu bar.

> **Tip:** When running from Xcode, the *bundle path* changes on every build, so macOS may keep asking for permissions. For day-to-day use, build a **Release** archive and copy it to `/Applications` — permissions then persist.

---

## 🐞 Troubleshooting

<details>
<summary><strong>Hotkey doesn't fire</strong></summary>

Make sure **Accessibility** is granted to MirrorTop. Re-open the onboarding window from the menu bar (*“İzinleri Yönet…”*).
</details>

<details>
<summary><strong>Panel is empty / black</strong></summary>

**Screen Recording** permission missing or revoked after an OS update. Toggle it off and on in System Settings → *Privacy & Security → Screen Recording*.
</details>

<details>
<summary><strong>Mirror disappeared after ~5 minutes</strong></summary>

macOS occasionally terminates idle `SCStream`s by policy (`-3808`). MirrorTop reconnects silently — the last frame stays frozen for ~1 second, then live frames resume. If you see a permanent freeze, three consecutive restarts have failed; press `⌘⌥T` once to clear and again to start fresh.
</details>

<details>
<summary><strong>Mirror window won't close</strong></summary>

Make sure the **same window** is still focused when you press `⌘⌥T` to toggle off. If you've switched apps, MirrorTop will start a *new* mirror instead. You can always quit from the menu bar.
</details>

---

## 🗺️ Roadmap

- [ ] Multi-window mirroring (more than one panel at a time)
- [ ] Persist panel position & size per source window (`UserDefaults`)
- [ ] Window picker in the menu bar (no hotkey required)
- [ ] Configurable hotkeys (Settings UI)
- [ ] Optional click-through dimming when not focused
- [ ] Localization (currently TR/EN-mixed)

PRs welcome — see [CONTRIBUTING](#-contributing) below.

---

## 🤝 Contributing

1. Fork the repo & create a feature branch.
2. Run the app from Xcode and verify your change with all three core flows: capture, interaction, silent restart.
3. Open a PR with a short description and (if UI) a screenshot/screen recording.
4. Be kind — first-time contributors are very welcome.

---

## 📜 License

MIT. See [LICENSE](LICENSE).

---

## 🙏 Acknowledgements

- Inspired by Microsoft PowerToys' *Always on Top* feature.
- Built on Apple's `ScreenCaptureKit`, `AXUIElement`, and `Carbon` hotkey APIs.
- Crash-investigation notes documented in [CLAUDE.md](CLAUDE.md).

---

<p align="center">
  Made with ☕ on macOS — by <a href="https://github.com/selcukdinc">Selçuk Dinç</a>.
</p>
