import SwiftUI
import AppKit
import MacnewsCore

@main
public struct MacnewsApp: App {
    @StateObject private var appState = AppState()

    public init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.applicationIconImage = AppIcon.loadOrRenderImage()
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    public var body: some Scene {
        Window("Hotnews", id: "main") {
            MainNewsView()
                .environmentObject(appState)
                .tint(NewsTheme.accent)
                .onOpenURL { url in
                    appState.handleIncomingURL(url)
                }
        }
        .handlesExternalEvents(matching: [WidgetDeepLink.scheme])
        .windowToolbarStyle(.unified(showsTitle: false))
        .windowResizability(.contentSize)
        .defaultSize(
            width: NewsTheme.defaultWindowWidth,
            height: NewsTheme.defaultWindowHeight
        )
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(replacing: .appSettings) {
                Button("API Server...") {
                    appState.isShowingSettings = true
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandMenu("Feeds") {
                Button("Hottest") {
                    appState.selectTab(.hot)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Coldest") {
                    appState.selectTab(.cold)
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("Newest") {
                    appState.selectTab(.new)
                }
                .keyboardShortcut("3", modifiers: [.command])

                if appState.selectedSite != nil {
                    Divider()
                    Button("Clear Site Filter") {
                        appState.clearSiteFilter()
                    }
                    .keyboardShortcut("[", modifiers: [.command])
                }

                Divider()

                Button("Refresh Feed") {
                    appState.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
