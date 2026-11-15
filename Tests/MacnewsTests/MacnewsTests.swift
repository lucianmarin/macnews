import Testing
import Foundation
import SwiftUI
import AppKit
import WidgetKit
@testable import Macnews
@testable import MacnewsCore
@testable import HotnewsWidgetCore

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite("Macnews Core Tests", .serialized)
struct MacnewsTests {

    @Test("Three segmented tabs map to /api/hot, /api/cold, and /api/new")
    func testFeedTabEndpoints() {
        #expect(FeedTab.allCases == [.hot, .cold, .new])
        #expect(FeedTab.hot.title == "Hottest")
        #expect(FeedTab.cold.title == "Coldest")
        #expect(FeedTab.new.title == "Newest")
        #expect(FeedTab.hot.apiPath == "/api/hot")
        #expect(FeedTab.cold.apiPath == "/api/cold")
        #expect(FeedTab.new.apiPath == "/api/new")
    }

    @Test("Decodes PaginatedNewsResponse and computes degrees, ageLabel, and siteLabel")
    func testDecodePaginatedNewsResponse() throws {
        let json = """
        {
            "page": 1,
            "pages": 4,
            "view": "hottest",
            "entries": [
                {
                    "id": "d3b07384d113edec49eaa6238ad5ff00",
                    "url": "https://www.macrumors.com/2026/10/28/top-stories/",
                    "title": "Top Stories: Apple 'Pro and Tell' Debut, iPhone Duo Launch, and More",
                    "domain": "macrumors.com",
                    "site": "macrumors",
                    "pub": 1793200000.0,
                    "age": "35h",
                    "author": "Juli Clover",
                    "description": "Yet another busy week for Apple saw a teaser for even more product announcements.",
                    "summary": "Yet another busy week for Apple saw a teaser for even more product announcements.",
                    "score": 0.0792,
                    "degrees": 79
                }
            ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PaginatedNewsResponse.self, from: json)
        #expect(decoded.page == 1)
        #expect(decoded.pages == 4)
        #expect(decoded.view == "hottest")
        #expect(decoded.hasNextPage == true)
        #expect(decoded.entries.count == 1)

        let entry = decoded.entries[0]
        #expect(entry.siteLabel == "macrumors")
        #expect(entry.ageLabel == "35h ago")
        #expect(entry.degrees == 79)
        #expect(entry.degreesLabel == "79°")
    }

    @Test("Odd news rows are highlighted and even news rows are not")
    @MainActor
    func testOddEvenRowHighlighting() {
        // 1st row (0-based index 0 -> row #1, odd) is highlighted
        #expect(AppState.isOddRowHighlighted(at: 0) == true)
        // 2nd row (0-based index 1 -> row #2, even) is not highlighted
        #expect(AppState.isOddRowHighlighted(at: 1) == false)
        // 3rd row (0-based index 2 -> row #3, odd) is highlighted
        #expect(AppState.isOddRowHighlighted(at: 2) == true)
        // 4th row (0-based index 3 -> row #4, even) is not highlighted
        #expect(AppState.isOddRowHighlighted(at: 3) == false)

        let sample = NewsEntry(
            id: "row-1",
            url: "https://bgr.com/tech/apple-tv-vs-ps5/",
            title: "Apple TV Vs. PlayStation 5: Which Is Best For Streaming?",
            domain: "bgr.com",
            site: "bgr",
            pub: 1793200000,
            age: "34h",
            description: "The PS5 has plenty of power for games.",
            score: 0.067
        )
        let oddRowView = NewsRowView(entry: sample, rowIndex: 0)
        let evenRowView = NewsRowView(entry: sample, rowIndex: 1)
        #expect(oddRowView.isOddRow == true)
        #expect(evenRowView.isOddRow == false)
    }

    @Test("NewsFormatter mirrors Hotnews shortdate, sitename, and 480-char summary truncation")
    func testNewsFormatterHelpers() {
        let now: Double = 1_700_000_000
        #expect(NewsFormatter.shortDate(timestamp: now - 15 * 60, now: now) == "15m")
        #expect(NewsFormatter.shortDate(timestamp: now - 35 * 3600, now: now) == "35h")

        #expect(NewsFormatter.siteName(from: "https://www.macrumors.com/story") == "macrumors")
        #expect(NewsFormatter.siteName(from: "theregister.co.uk") == "theregister")
        #expect(NewsFormatter.siteName(from: "bair.berkeley.edu") == "bair.berkeley")

        let longText = String(repeating: "word ", count: 120)
        let truncated = NewsFormatter.truncateSummary(longText, length: 480)
        #expect(truncated.count <= 480)
        #expect(truncated.hasSuffix("..."))
    }

    @Test("APIClient and AppState support infinite scroll pagination and segmented feed switching")
    @MainActor
    func testInfiniteScrollAndFeedSwitching() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        MockURLProtocol.requestHandler = { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let page = Int(components?.queryItems?.first(where: { $0.name == "p" })?.value ?? "1") ?? 1
            let path = url.path

            let viewName: String
            switch path {
            case "/api/hot": viewName = "hottest"
            case "/api/cold": viewName = "coldest"
            case "/api/new": viewName = "newest"
            default: viewName = "site"
            }

            let entries = (1...10).map { idx -> [String: Any] in
                let globalIndex = (page - 1) * 10 + idx
                return [
                    "id": "\(viewName)-\(globalIndex)",
                    "url": "https://site\(globalIndex).com/article",
                    "title": "\(viewName.capitalized) Article \(globalIndex)",
                    "domain": "site\(globalIndex).com",
                    "site": "site\(globalIndex)",
                    "pub": 1793200000.0,
                    "age": "\(globalIndex)h",
                    "description": "Summary for article \(globalIndex)",
                    "score": 0.05
                ]
            }

            let payload: [String: Any] = [
                "page": page,
                "pages": 2,
                "view": viewName,
                "entries": entries
            ]
            let data = try JSONSerialization.data(withJSONObject: payload)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let suiteName = "macnews.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let client = APIClient(baseURLString: "https://news.lucianmarin.com", session: session)
        let state = AppState(defaults: defaults, apiClient: client)

        // Initial load of Hottest (page 1)
        await state.loadFeed(reset: true)
        #expect(state.selectedTab == .hot)
        #expect(state.currentPage == 1)
        #expect(state.totalPages == 2)
        #expect(state.canLoadMore == true)
        #expect(state.entries.count == 10)
        #expect(state.entries.first?.id == "hottest-1")

        // Infinite scroll trigger near the end of page 1 loads page 2
        let ninthEntry = state.entries[8]
        await state.loadMoreIfNeeded(currentEntry: ninthEntry)
        #expect(state.currentPage == 2)
        #expect(state.canLoadMore == false)
        #expect(state.entries.count == 20)
        #expect(state.entries.last?.id == "hottest-20")

        // Switch segmented tab to Coldest
        state.selectTab(.cold)
        await state.loadFeed(reset: true)
        #expect(state.selectedTab == .cold)
        #expect(state.currentPage == 1)
        #expect(state.entries.count == 10)
        #expect(state.entries.first?.id == "coldest-1")

        // Switch segmented tab to Newest
        state.selectTab(.new)
        await state.loadFeed(reset: true)
        #expect(state.selectedTab == .new)
        #expect(state.entries.first?.id == "newest-1")
    }

    @Test("MainNewsView and AppIcon render properly on macOS")
    @MainActor
    func testViewsAndAppIconRender() throws {
        let pngData = try #require(AppIcon.renderPNGData(pixelSize: 256))
        #expect(!pngData.isEmpty)
        if let iconsetPath = ProcessInfo.processInfo.environment["GENERATE_APP_ICONSET"] {
            try AppIcon.writeIconset(to: URL(fileURLWithPath: iconsetPath))
        }
        let iconImage = AppIcon.loadOrRenderImage()
        #expect(iconImage.size.width > 0)

        let suiteName = "macnews.ui.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = AppState(defaults: defaults)
        state.entries = [
            NewsEntry(
                id: "1",
                url: "https://www.macrumors.com/story",
                title: "Top Stories: Apple Debut",
                domain: "macrumors.com",
                site: "macrumors",
                pub: 1793200000,
                age: "35h",
                description: "Yet another busy week for Apple.",
                score: 0.079
            ),
            NewsEntry(
                id: "2",
                url: "https://www.gsmarena.com/story",
                title: "Deals: Oppo Find X10",
                domain: "gsmarena.com",
                site: "gsmarena",
                pub: 1793190000,
                age: "40h",
                description: "This week saw two major launches.",
                score: 0.072
            )
        ]

        let host = NSHostingView(
            rootView: MainNewsView()
                .environmentObject(state)
                .frame(width: 560, height: 480)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.toolbar = NSToolbar(identifier: "TestToolbar")
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        #expect(NewsTheme.maxWindowWidth == 560)
        #expect(host.fittingSize.width >= 420)
        #expect(host.fittingSize.height >= 420)
        #expect(window.titleVisibility == .hidden)
        #expect(window.toolbarStyle == .unified)
        #expect(window.styleMask.contains(.fullSizeContentView))
        #expect(window.toolbar?.showsBaselineSeparator == false)
        #expect(window.contentMaxSize.width == 560)
        #expect(window.frame.width <= 560)
    }

    @Test("HotnewsTimelineProvider fetches only the Hottest feed (/api/hot)")
    func testWidgetFetchesOnlyHottestFeed() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        final class RequestRecorder: @unchecked Sendable {
            var paths: [String] = []
        }
        let recorder = RequestRecorder()

        MockURLProtocol.requestHandler = { request in
            let url = try #require(request.url)
            recorder.paths.append(url.path)

            let payload: [String: Any] = [
                "page": 1,
                "pages": 3,
                "view": "hottest",
                "entries": [
                    [
                        "id": "hot-1",
                        "url": "https://www.macrumors.com/story-1",
                        "title": "Hottest Story One",
                        "domain": "macrumors.com",
                        "site": "macrumors",
                        "pub": 1793200000.0,
                        "age": "2h",
                        "description": "This description should not appear in the widget.",
                        "score": 0.088
                    ],
                    [
                        "id": "hot-2",
                        "url": "https://www.theverge.com/story-2",
                        "title": "Hottest Story Two",
                        "domain": "theverge.com",
                        "site": "theverge",
                        "pub": 1793195000.0,
                        "age": "4h",
                        "description": "Another hidden description.",
                        "score": 0.075
                    ]
                ]
            ]
            let data = try JSONSerialization.data(withJSONObject: payload)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let client = APIClient(baseURLString: "https://news.lucianmarin.com", session: session)
        let entry = await HotnewsTimelineProvider.loadEntry(apiClient: client)

        #expect(recorder.paths == ["/api/hot"])
        #expect(HotnewsTimelineProvider.refreshIntervalSeconds == 3600)
        #expect(entry.errorMessage == nil)
        #expect(entry.entries.count == 2)
        #expect(entry.entries[0].siteLabel == "macrumors")
        #expect(entry.entries[0].ageLabel == "2h ago")
        #expect(entry.entries[0].degreesLabel == "88°")
        #expect(entry.entries[0].title == "Hottest Story One")
    }

    @Test("Widget deep links round-trip and mark articles visited")
    @MainActor
    func testWidgetDeepLinkHandling() throws {
        let sample = NewsEntry(
            id: "1",
            url: "https://www.macrumors.com/2026/10/28/top-stories/",
            title: "Top Stories",
            domain: "macrumors.com",
            site: "macrumors",
            pub: 1793200000,
            age: "2h",
            score: 0.079
        )
        let deepLink = try #require(WidgetDeepLink.makeArticleURL(for: sample))
        #expect(deepLink.scheme == "hotnews")
        #expect(deepLink.host == "open")

        let parsed = try #require(WidgetDeepLink.parseArticleURL(from: deepLink))
        #expect(parsed.articleURL.absoluteString == sample.url)
        #expect(parsed.site == "macrumors")

        let invalid = URL(string: "hotnews://open?url=javascript:alert(1)")!
        #expect(WidgetDeepLink.parseArticleURL(from: invalid) == nil)
    }

    @Test("Widget renders small, medium, and large sizes fitting more stories as size increases")
    @MainActor
    func testWidgetSizesFitStoriesWithoutDescription() throws {
        let entries = HotnewsWidgetEntry.sampleEntries
        let timelineEntry = HotnewsWidgetEntry(date: Date(), entries: entries)

        final class MeasurementBox: @unchecked Sendable {
            var count = 0
            var rowHeights: [Int: CGFloat] = [:]
        }

        func measureRenderedLayout(family: WidgetFamily, size: CGSize) -> (count: Int, rowHeights: [Int: CGFloat]) {
            let box = MeasurementBox()
            let view = HotnewsWidgetEntryView(entry: timelineEntry, familyOverride: family) { count in
                box.count = count
            }
            .onPreferenceChange(HotnewsRowHeightsPreferenceKey.self) { heights in
                box.rowHeights = heights
            }
            .frame(width: size.width, height: size.height)

            let host = NSHostingView(rootView: view)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            _ = host.bitmapImageRepForCachingDisplay(in: host.bounds)
            return (box.count, box.rowHeights)
        }

        let smallResult = measureRenderedLayout(family: .systemSmall, size: CGSize(width: 164, height: 164))
        let mediumResult = measureRenderedLayout(family: .systemMedium, size: CGSize(width: 344, height: 164))
        let largeResult = measureRenderedLayout(family: .systemLarge, size: CGSize(width: 344, height: 344))

        let smallCount = smallResult.count
        let mediumCount = mediumResult.count
        let largeCount = largeResult.count

        #expect(smallCount >= 2 && smallCount <= 4)
        #expect(mediumCount >= 2 && mediumCount <= 4)
        #expect(largeCount > mediumCount)
        #expect(largeCount >= 5 && largeCount <= 8)

        // Verify each size divides the full widget height equally across the stories that fit
        for (result, expectedTotalHeight) in [
            (smallResult, CGFloat(164)),
            (mediumResult, CGFloat(164)),
            (largeResult, CGFloat(344))
        ] {
            #expect(result.rowHeights.count == result.count)
            let expectedRowHeight = expectedTotalHeight / CGFloat(result.count)
            for idx in 0..<result.count {
                let actual = try #require(result.rowHeights[idx])
                #expect(abs(actual - expectedRowHeight) < 1.0)
            }
        }

        // With short 1-line titles, even more stories dynamically fit in the same dimensions
        let shortEntries = (1...10).map { idx in
            NewsEntry(
                id: "short-\(idx)",
                url: "https://site\(idx).com/s",
                title: "Short Title \(idx)",
                domain: "site\(idx).com",
                site: "site\(idx)",
                pub: 1793200000,
                age: "\(idx)h",
                score: 0.05
            )
        }
        let shortTimeline = HotnewsWidgetEntry(date: Date(), entries: shortEntries)
        func measureShortCount(family: WidgetFamily, size: CGSize) -> Int {
            let box = MeasurementBox()
            let view = HotnewsWidgetEntryView(entry: shortTimeline, familyOverride: family) { count in
                box.count = count
            }
            .frame(width: size.width, height: size.height)
            let host = NSHostingView(rootView: view)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            _ = host.bitmapImageRepForCachingDisplay(in: host.bounds)
            return box.count
        }

        let shortSmall = measureShortCount(family: .systemSmall, size: CGSize(width: 164, height: 164))
        let shortMedium = measureShortCount(family: .systemMedium, size: CGSize(width: 344, height: 164))
        let shortLarge = measureShortCount(family: .systemLarge, size: CGSize(width: 344, height: 344))
        #expect(shortSmall >= smallCount)
        #expect(shortMedium >= mediumCount)
        #expect(shortLarge >= largeCount)
    }
}
