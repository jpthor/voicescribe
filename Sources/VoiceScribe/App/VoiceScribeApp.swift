import SwiftUI

@main
struct VoiceScribeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var appState = AppState.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Label("VoiceScribe", systemImage: menuBarIcon)
        }
        .menuBarExtraStyle(.window)

        Window("Onboarding", id: "onboarding") {
            OnboardingView(appState: appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Window("VoiceScribe", id: "settings") {
            SettingsView(appState: appState)
        }
        .windowResizability(.contentSize)
    }

    private var menuBarIcon: String {
        // Check if we need to show onboarding or settings
        if appState.showOnboarding {
            DispatchQueue.main.async {
                self.openWindow(id: "onboarding")
                NSApp.activate(ignoringOtherApps: true)
            }
        } else if !AppState.shared.hasShownSettingsOnLaunch {
            DispatchQueue.main.async {
                AppState.shared.hasShownSettingsOnLaunch = true
                self.openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        switch appState.state {
        case .idle:
            return "mic.fill"
        case .recording:
            return "mic.badge.plus"
        case .processing:
            return "ellipsis.circle"
        case .error:
            return "mic.slash"
        }
    }
}
