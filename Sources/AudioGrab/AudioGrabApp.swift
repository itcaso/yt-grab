import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        configureDocumentationScreenshotIfNeeded()
        showMainWindow()
        NSApplication.shared.activate(ignoringOtherApps: true)
        captureDocumentationScreenshotIfNeeded()
    }

    private func configureDocumentationScreenshotIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let stateIndex = arguments.firstIndex(of: "--documentation-screenshot"),
              arguments.indices.contains(stateIndex + 1) else { return }
        model.configureDocumentationScreenshot(state: arguments[stateIndex + 1])
    }

    private func captureDocumentationScreenshotIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let outputIndex = arguments.firstIndex(of: "--screenshot-output"),
              arguments.indices.contains(outputIndex + 1) else { return }
        let outputURL = URL(fileURLWithPath: arguments[outputIndex + 1])

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, let window = self.mainWindow, let contentView = window.contentView else {
                NSApplication.shared.terminate(nil)
                return
            }
            window.displayIfNeeded()
            if let image = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                CGWindowID(window.windowNumber),
                [.boundsIgnoreFraming, .bestResolution]
            ) {
                let representation = NSBitmapImageRep(cgImage: image)
                if let png = representation.representation(using: .png, properties: [:]) {
                    try? png.write(to: outputURL, options: .atomic)
                    NSApplication.shared.terminate(nil)
                    return
                }
            }

            let bounds = contentView.bounds
            guard let representation = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
                NSApplication.shared.terminate(nil)
                return
            }
            contentView.cacheDisplay(in: bounds, to: representation)
            if let png = representation.representation(using: .png, properties: [:]) {
                try? png.write(to: outputURL, options: .atomic)
            }
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    private func showMainWindow() {
        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            return
        }

        let content = RootView().environmentObject(model)
        let hostingController = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "YT-Grab"
        window.setContentSize(NSSize(width: 780, height: 600))
        window.minSize = NSSize(width: 700, height: 520)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false

        let placementKey = "didPlaceInitialWindow"
        if !UserDefaults.standard.bool(forKey: placementKey) {
            let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: 0, y: 0)) }) ?? NSScreen.main
            if let visibleFrame = screen?.visibleFrame {
                window.setFrameOrigin(CGPoint(
                    x: visibleFrame.midX - window.frame.width / 2,
                    y: visibleFrame.midY - window.frame.height / 2
                ))
            }
            UserDefaults.standard.set(true, forKey: placementKey)
        } else {
            window.center()
        }

        mainWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}

@main
struct YTGrabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.model)
                .frame(width: 520, height: 480)
        }
    }
}
