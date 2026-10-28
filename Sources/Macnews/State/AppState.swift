import Foundation
import SwiftUI
import AppKit

@MainActor
public final class AppState: ObservableObject {
    @Published public var selectedTab: FeedTab {
        didSet {
            defaults.set(selectedTab.rawValue, forKey: StorageKeys.selectedTab)
        }
    }
    @Published public var selectedSite: String? = nil
    @Published public var entries: [NewsEntry] = []
    @Published public var currentPage: Int = 1
    @Published public var totalPages: Int = 1
    @Published public var isLoading: Bool = false
    @Published public var isLoadingMore: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var visitedURLs: Set<String>
    @Published public var visitedSites: Set<String>
    @Published public var apiBaseURL: String
    @Published public var feedRefreshTrigger: UUID = UUID()
    @Published public var isShowingSettings: Bool = false

    public let apiClient: APIClient
    private let defaults: UserDefaults

    private enum StorageKeys {
        static let selectedTab = "macnews.ui.selectedTab"
        static let visitedURLs = "macnews.history.visitedURLs"
        static let visitedSites = "macnews.history.visitedSites"
        static let apiBaseURL = "macnews.config.apiBaseURL"
    }

    public init(
        defaults: UserDefaults = .standard,
        apiClient: APIClient? = nil
    ) {
        self.defaults = defaults
        let envBaseURL = ProcessInfo.processInfo.environment["MACNEWS_API_URL"]
        let savedBaseURL = envBaseURL ?? defaults.string(forKey: StorageKeys.apiBaseURL) ?? APIClient.defaultBaseURL
        let normalizedBaseURL = APIClient.normalizeBaseURL(savedBaseURL)
        self.apiBaseURL = normalizedBaseURL

        if let rawTab = defaults.string(forKey: StorageKeys.selectedTab),
           let tab = FeedTab(rawValue: rawTab) {
            self.selectedTab = tab
        } else {
            self.selectedTab = .hot
        }

        let storedURLs = defaults.stringArray(forKey: StorageKeys.visitedURLs) ?? []
        self.visitedURLs = Set(storedURLs)

        let storedSites = defaults.stringArray(forKey: StorageKeys.visitedSites) ?? []
        self.visitedSites = Set(storedSites)

        self.apiClient = apiClient ?? APIClient(baseURLString: normalizedBaseURL)
    }

    public var canLoadMore: Bool {
        currentPage < totalPages && !entries.isEmpty
    }

    public var activeFeedPath: String {
        if let selectedSite, !selectedSite.isEmpty {
            return "/api/\(selectedSite)"
        }
        return selectedTab.apiPath
    }

    /// Odd news rows (1st, 3rd, 5th... in 1-based display order, i.e. 0-based `index % 2 == 0`)
    /// are highlighted, and even rows (2nd, 4th, 6th... i.e. `index % 2 == 1`) are not.
    public nonisolated static func isOddRowHighlighted(at zeroBasedIndex: Int) -> Bool {
        let oneBasedRowNumber = zeroBasedIndex + 1
        return oneBasedRowNumber % 2 == 1
    }

    public func selectTab(_ tab: FeedTab) {
        let wasSameTab = (selectedTab == tab && selectedSite == nil)
        selectedSite = nil
        isLoadingMore = false
        if selectedTab != tab {
            selectedTab = tab
        }
        if wasSameTab {
            feedRefreshTrigger = UUID()
        }
    }

    public func selectSite(_ site: String) {
        let cleaned = site.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        markSiteVisited(cleaned)
        isLoadingMore = false
        if selectedSite == cleaned {
            feedRefreshTrigger = UUID()
        } else {
            selectedSite = cleaned
        }
    }

    public func clearSiteFilter() {
        guard selectedSite != nil else { return }
        isLoadingMore = false
        selectedSite = nil
    }

    public func refresh() {
        feedRefreshTrigger = UUID()
    }

    public func updateAPIBaseURL(_ newURL: String) {
        let normalized = APIClient.normalizeBaseURL(newURL)
        self.apiBaseURL = normalized
        defaults.set(normalized, forKey: StorageKeys.apiBaseURL)
        Task {
            await apiClient.setBaseURL(normalized)
            feedRefreshTrigger = UUID()
        }
    }

    public func markArticleVisited(_ url: String) {
        guard !url.isEmpty else { return }
        visitedURLs.insert(url)
        defaults.set(Array(visitedURLs), forKey: StorageKeys.visitedURLs)
    }

    public func isArticleVisited(_ url: String) -> Bool {
        visitedURLs.contains(url)
    }

    public func markSiteVisited(_ site: String) {
        guard !site.isEmpty else { return }
        visitedSites.insert(site)
        defaults.set(Array(visitedSites), forKey: StorageKeys.visitedSites)
    }

    public func isSiteVisited(_ site: String) -> Bool {
        visitedSites.contains(site)
    }

    public func openArticle(_ entry: NewsEntry) {
        markArticleVisited(entry.url)
        markSiteVisited(entry.siteLabel)
        if let url = URL(string: entry.url) {
            NSWorkspace.shared.open(url)
        }
    }

    public func loadFeed(reset: Bool) async {
        if reset {
            isLoading = true
            errorMessage = nil
        } else {
            guard canLoadMore, !isLoading, !isLoadingMore else { return }
            isLoadingMore = true
        }

        let targetPage = reset ? 1 : currentPage + 1
        let activeSite = selectedSite
        let activeTab = selectedTab

        do {
            let response: PaginatedNewsResponse
            if let activeSite, !activeSite.isEmpty {
                response = try await apiClient.fetchSite(site: activeSite, page: targetPage)
            } else {
                response = try await apiClient.fetchFeed(tab: activeTab, page: targetPage)
            }

            guard !Task.isCancelled,
                  selectedTab == activeTab,
                  selectedSite == activeSite else {
                return
            }

            if reset {
                entries = response.entries
            } else {
                let existingIDs = Set(entries.map(\.id))
                let newUnique = response.entries.filter { !existingIDs.contains($0.id) }
                entries.append(contentsOf: newUnique)
            }
            currentPage = response.page
            totalPages = max(response.pages, response.entries.isEmpty ? 0 : response.page)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled,
                  selectedTab == activeTab,
                  selectedSite == activeSite else {
                return
            }
            errorMessage = error.localizedDescription
        }

        if reset {
            isLoading = false
        } else {
            isLoadingMore = false
        }
    }

    public func loadMoreIfNeeded(currentEntry: NewsEntry) async {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        guard let index = entries.firstIndex(where: { $0.id == currentEntry.id }) else { return }
        let thresholdIndex = max(0, entries.count - 3)
        if index >= thresholdIndex {
            await loadFeed(reset: false)
        }
    }
}
