import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Initialize app state and show onboarding if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Task { @MainActor in
                await AppState.shared.initialize()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
    }
}
