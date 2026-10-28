import SwiftUI
import AppKit

public enum NewsTheme {
    /// Hotnews `orangered` accent color (`#FF4500` / `rgb(255, 69, 0)`)
    public static let accent = Color(red: 1.0, green: 69.0 / 255.0, blue: 0.0)

    /// Website `--white`: `#FFFFFF` (Light) / `#000000` (Dark)
    public static let background = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .black : .white
    }))

    /// Highlighted background for odd news rows (1st, 3rd, 5th...):
    /// Website `--whitesmoke`: `#F0F0F0` (Light) / `#141414` (Dark)
    public static let oddRowBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 0x14 / 255.0, green: 0x14 / 255.0, blue: 0x14 / 255.0, alpha: 1.0)
            : NSColor(srgbRed: 0xF0 / 255.0, green: 0xF0 / 255.0, blue: 0xF0 / 255.0, alpha: 1.0)
    }))

    /// Unhighlighted background for even news rows (2nd, 4th, 6th...):
    /// Website `--white`: `#FFFFFF` (Light) / `#000000` (Dark)
    public static let evenRowBackground = background

    /// Website `--gainsboro`: `#E0E0E0` (Light) / `#242424` (Dark)
    public static let gainsboro = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 0x24 / 255.0, green: 0x24 / 255.0, blue: 0x24 / 255.0, alpha: 1.0)
            : NSColor(srgbRed: 0xE0 / 255.0, green: 0xE0 / 255.0, blue: 0xE0 / 255.0, alpha: 1.0)
    }))

    /// Website `--silver`: `#C0C0C0` (Light) / `#404040` (Dark)
    public static let silver = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 0x40 / 255.0, green: 0x40 / 255.0, blue: 0x40 / 255.0, alpha: 1.0)
            : NSColor(srgbRed: 0xC0 / 255.0, green: 0xC0 / 255.0, blue: 0xC0 / 255.0, alpha: 1.0)
    }))

    /// Website `--gray`: `#808080`
    public static let gray = Color(nsColor: NSColor(srgbRed: 0x80 / 255.0, green: 0x80 / 255.0, blue: 0x80 / 255.0, alpha: 1.0))

    /// Website `--darkgray`: `#404040` (Light) / `#C0C0C0` (Dark)
    public static let darkGray = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 0xC0 / 255.0, green: 0xC0 / 255.0, blue: 0xC0 / 255.0, alpha: 1.0)
            : NSColor(srgbRed: 0x40 / 255.0, green: 0x40 / 255.0, blue: 0x40 / 255.0, alpha: 1.0)
    }))

    /// Website `--darkgray` (visited links): `#404040` (Light) / `#C0C0C0` (Dark)
    public static let visitedText = darkGray

    /// Website `--black`: `#000000` (Light) / `#FFFFFF` (Dark)
    public static let primaryText = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .white : .black
    }))

    public static let maxReadingWidth: CGFloat = 520
    public static let horizontalPadding: CGFloat = 20
    public static let rowVerticalPadding: CGFloat = horizontalPadding / 2
    public static let toolbarHeight: CGFloat = 52
    public static let minWindowWidth: CGFloat = 420
    public static let maxWindowWidth: CGFloat = maxReadingWidth + (horizontalPadding * 2) // 560pt
    public static let defaultWindowWidth: CGFloat = maxWindowWidth
    public static let minWindowHeight: CGFloat = 420
    public static let defaultWindowHeight: CGFloat = 680

    public static func rowBackground(forZeroBasedIndex index: Int) -> Color {
        AppState.isOddRowHighlighted(at: index) ? oddRowBackground : evenRowBackground
    }
}

public struct NewsLinkButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .linkCursor()
    }
}

public extension ButtonStyle where Self == NewsLinkButtonStyle {
    static var newsLink: NewsLinkButtonStyle { NewsLinkButtonStyle() }
}

private struct LinkCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(macOS 15.0, *) {
                content.pointerStyle(.link)
            } else {
                content
            }
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

public extension View {
    func linkCursor() -> some View {
        modifier(LinkCursorModifier())
    }
}

/// Configures the hosting `NSWindow` and its native `NSToolbar` to match `../multicolor`:
/// hidden window title, unified toolbar without baseline separator, full-size content view,
/// and persisted window frame.
public struct NewsWindowConfigurator: NSViewRepresentable {
    private static let windowFrameDefaultsKey = "HotnewsMainWindowFrame"

    public init() {}

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> NSView {
        let view = WindowObserverView()
        view.onWindowAttached = { window in
            context.coordinator.attach(to: window)
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            context.coordinator.attach(to: window)
        }
    }

    private final class WindowObserverView: NSView {
        var onWindowAttached: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            onWindowAttached?(window)
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else { return }
                self.onWindowAttached?(window)
            }
        }
    }

    @MainActor
    public final class Coordinator: NSObject {
        private weak var observedWindow: NSWindow?
        private var hasRestoredFrame = false
        private nonisolated(unsafe) var observers: [NSObjectProtocol] = []

        public func attach(to window: NSWindow) {
            configureWindow(window)

            guard observedWindow !== window else { return }
            removeObservers()
            observedWindow = window

            if !hasRestoredFrame {
                hasRestoredFrame = true
                if let savedFrame = UserDefaults.standard.string(forKey: NewsWindowConfigurator.windowFrameDefaultsKey) {
                    window.setFrame(from: savedFrame)
                }
                configureWindow(window)
            }

            let center = NotificationCenter.default
            let configNames: [Notification.Name] = [
                NSWindow.didBecomeKeyNotification,
                NSWindow.didDeminiaturizeNotification,
                NSWindow.didExitFullScreenNotification
            ]

            for name in configNames {
                let token = center.addObserver(forName: name, object: window, queue: .main) { [weak self, weak window] _ in
                    MainActor.assumeIsolated {
                        guard let self, let window else { return }
                        self.configureWindow(window)
                    }
                }
                observers.append(token)
            }

            let frameNames: [Notification.Name] = [
                NSWindow.didResizeNotification,
                NSWindow.didMoveNotification,
                NSWindow.willCloseNotification
            ]

            for name in frameNames {
                let token = center.addObserver(forName: name, object: window, queue: .main) { [weak self, weak window] _ in
                    MainActor.assumeIsolated {
                        guard let self, let window else { return }
                        self.saveWindowFrame(window)
                    }
                }
                observers.append(token)
            }
        }

        private func configureWindow(_ window: NSWindow) {
            window.titleVisibility = .hidden
            window.toolbarStyle = .unified
            window.styleMask.insert(.fullSizeContentView)
            if let toolbar = window.toolbar {
                toolbar.showsBaselineSeparator = false
                toolbar.displayMode = .iconOnly
                toolbar.sizeMode = .regular
            }
            window.contentMinSize = NSSize(
                width: NewsTheme.minWindowWidth,
                height: NewsTheme.minWindowHeight
            )
            window.contentMaxSize = NSSize(
                width: NewsTheme.maxWindowWidth,
                height: .greatestFiniteMagnitude
            )
            window.maxSize = NSSize(
                width: NewsTheme.maxWindowWidth,
                height: .greatestFiniteMagnitude
            )
            if window.frame.width > NewsTheme.maxWindowWidth {
                var clampedFrame = window.frame
                clampedFrame.size.width = NewsTheme.maxWindowWidth
                window.setFrame(clampedFrame, display: true)
            }
        }

        private func saveWindowFrame(_ window: NSWindow) {
            UserDefaults.standard.set(
                window.frameDescriptor,
                forKey: NewsWindowConfigurator.windowFrameDefaultsKey
            )
        }

        private nonisolated func removeObservers() {
            for token in observers {
                NotificationCenter.default.removeObserver(token)
            }
            observers.removeAll()
        }

        deinit {
            removeObservers()
        }
    }
}

private struct MacScrollViewBridge: NSViewRepresentable {
    let onPullGesture: (_ pullDistance: CGFloat, _ phase: NSEvent.Phase) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPullGesture: onPullGesture)
    }

    func makeNSView(context: Context) -> NSView {
        let view = ScrollObserverNSView()
        view.onScrollViewAttached = { scrollView in
            context.coordinator.attach(to: scrollView)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onPullGesture = onPullGesture
        if let scrollView = nsView.enclosingScrollView {
            context.coordinator.attach(to: scrollView)
        }
    }

    private final class ScrollObserverNSView: NSView {
        var onScrollViewAttached: ((NSScrollView) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self, let sv = self.enclosingScrollView else { return }
                self.onScrollViewAttached?(sv)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var onPullGesture: (_ pullDistance: CGFloat, _ phase: NSEvent.Phase) -> Void
        private weak var observedScrollView: NSScrollView?
        private nonisolated(unsafe) var scrollMonitor: Any?
        private var restingTopOriginY: CGFloat?
        private var accumulatedPull: CGFloat = 0
        private var isTrackingTopPull = false

        init(onPullGesture: @escaping (_ pullDistance: CGFloat, _ phase: NSEvent.Phase) -> Void) {
            self.onPullGesture = onPullGesture
        }

        func attach(to scrollView: NSScrollView) {
            scrollView.verticalScrollElasticity = .allowed
            if observedScrollView !== scrollView {
                observedScrollView = scrollView
                restingTopOriginY = scrollView.contentView.bounds.origin.y
            }

            if scrollMonitor == nil {
                scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                    self?.handleScrollWheel(event)
                    return event
                }
            }
        }

        private func handleScrollWheel(_ event: NSEvent) {
            guard let scrollView = observedScrollView,
                  let window = scrollView.window,
                  event.window === window else {
                return
            }

            if !event.momentumPhase.isEmpty {
                return
            }

            let locationInScroll = scrollView.convert(event.locationInWindow, from: nil)
            guard scrollView.bounds.contains(locationInScroll) else { return }

            let currentOriginY = scrollView.contentView.bounds.origin.y
            let insetTop = -scrollView.contentInsets.top
            let baselineY = min(restingTopOriginY ?? insetTop, insetTop)
            if restingTopOriginY == nil || (event.phase == .began && currentOriginY < (restingTopOriginY ?? insetTop) && currentOriginY <= insetTop) {
                restingTopOriginY = currentOriginY
            }

            let isAtTop = currentOriginY <= baselineY + 1.0

            if event.phase == .began {
                isTrackingTopPull = isAtTop
                accumulatedPull = 0
            } else if event.phase.isEmpty {
                isTrackingTopPull = isAtTop
            }

            if isTrackingTopPull {
                if event.scrollingDeltaY > 0 && isAtTop {
                    let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.55 : event.scrollingDeltaY * 5.0
                    accumulatedPull = min(90, accumulatedPull + delta)
                } else if event.scrollingDeltaY < 0 {
                    let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.8 : event.scrollingDeltaY * 5.0
                    accumulatedPull = max(0, accumulatedPull + delta)
                }

                let effectivePhase: NSEvent.Phase = event.phase.isEmpty ? .ended : event.phase
                onPullGesture(accumulatedPull, effectivePhase)

                if effectivePhase == .ended || effectivePhase == .cancelled {
                    isTrackingTopPull = false
                    accumulatedPull = 0
                }
            }
        }

        deinit {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

/// Native macOS pull-to-refresh ScrollView.
public struct RefreshableScrollView<Content: View>: View {
    private let onRefresh: () async -> Void
    private let content: () -> Content

    @State private var isRefreshing = false
    @State private var pullOffset: CGFloat = 0

    private let triggerThreshold: CGFloat = 44

    public init(
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onRefresh = onRefresh
        self.content = content
    }

    private var showIndicator: Bool {
        isRefreshing || pullOffset > 6
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                MacScrollViewBridge { distance, phase in
                    handlePullGesture(distance: distance, phase: phase)
                }
                .frame(width: 0, height: 0)

                content()
            }
        }
        .overlay(alignment: .top) {
            if showIndicator {
                HStack(spacing: 7) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: pullOffset >= triggerThreshold ? "arrow.up" : "arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NewsTheme.accent)
                    }
                    Text(statusLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NewsTheme.gray)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(NewsTheme.oddRowBackground)
                        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                )
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.16), value: showIndicator)
        .animation(.easeInOut(duration: 0.16), value: isRefreshing)
    }

    private var statusLabel: String {
        if isRefreshing {
            return "Refreshing..."
        } else if pullOffset >= triggerThreshold {
            return "Release to refresh"
        } else {
            return "Pull to refresh"
        }
    }

    private func handlePullGesture(distance: CGFloat, phase: NSEvent.Phase) {
        guard !isRefreshing else { return }

        switch phase {
        case .began, .changed, .stationary:
            pullOffset = distance
        case .ended:
            let shouldRefresh = distance >= triggerThreshold || pullOffset >= triggerThreshold
            pullOffset = 0
            if shouldRefresh {
                Task {
                    await performRefreshWithMinimumDuration()
                }
            }
        default:
            pullOffset = 0
        }
    }

    private func performRefreshWithMinimumDuration() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let start = ContinuousClock.now
        await onRefresh()
        let elapsed = ContinuousClock.now - start
        if elapsed < .milliseconds(350) {
            try? await Task.sleep(for: .milliseconds(350) - elapsed)
        }
        isRefreshing = false
    }
}
