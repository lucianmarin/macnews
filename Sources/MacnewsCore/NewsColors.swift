import SwiftUI
import AppKit

public enum NewsColors {
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

    /// Odd news rows (1st, 3rd, 5th... in 1-based display order, i.e. 0-based `index % 2 == 0`)
    /// are highlighted, and even rows (2nd, 4th, 6th... i.e. `index % 2 == 1`) are not.
    public static func isOddRowHighlighted(at zeroBasedIndex: Int) -> Bool {
        let oneBasedRowNumber = zeroBasedIndex + 1
        return oneBasedRowNumber % 2 == 1
    }

    public static func rowBackground(forZeroBasedIndex index: Int) -> Color {
        isOddRowHighlighted(at: index) ? oddRowBackground : evenRowBackground
    }
}

public enum SharedWidgetStorage {
    public static let apiBaseURLKey = "macnews.config.apiBaseURL"
    public static let cachedHotEntriesKey = "macnews.widget.cachedHotEntries"

    public static func saveAPIBaseURL(_ url: String, defaults: UserDefaults = .standard) {
        let normalized = APIClient.normalizeBaseURL(url)
        defaults.set(normalized, forKey: apiBaseURLKey)
    }

    public static func loadAPIBaseURL(fallbackDefaults: UserDefaults = .standard) -> String {
        if let env = ProcessInfo.processInfo.environment["MACNEWS_API_URL"] {
            return APIClient.normalizeBaseURL(env)
        }
        if let standard = fallbackDefaults.string(forKey: apiBaseURLKey) {
            return APIClient.normalizeBaseURL(standard)
        }
        return APIClient.defaultBaseURL
    }

    public static func saveCachedHotEntries(_ entries: [NewsEntry], defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: cachedHotEntriesKey)
    }

    public static func loadCachedHotEntries(defaults: UserDefaults = .standard) -> [NewsEntry] {
        guard let data = defaults.data(forKey: cachedHotEntriesKey),
              let decoded = try? JSONDecoder().decode([NewsEntry].self, from: data) else {
            return []
        }
        return decoded
    }
}
