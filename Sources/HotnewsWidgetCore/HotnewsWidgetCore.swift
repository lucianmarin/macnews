import Foundation
import SwiftUI
import WidgetKit
import MacnewsCore

public struct HotnewsWidgetEntry: TimelineEntry, Sendable {
    public let date: Date
    public let entries: [NewsEntry]
    public let errorMessage: String?
    public let isPlaceholder: Bool

    public init(
        date: Date,
        entries: [NewsEntry],
        errorMessage: String? = nil,
        isPlaceholder: Bool = false
    ) {
        self.date = date
        self.entries = entries
        self.errorMessage = errorMessage
        self.isPlaceholder = isPlaceholder
    }

    public static let sampleEntries: [NewsEntry] = [
        NewsEntry(
            id: "sample-1",
            url: "https://www.macrumors.com/2026/10/28/top-stories/",
            title: "Top Stories: Apple 'Pro and Tell' Debut, iPhone Duo Launch, and More",
            domain: "macrumors.com",
            site: "macrumors",
            pub: 1793200000,
            age: "2h",
            score: 0.079
        ),
        NewsEntry(
            id: "sample-2",
            url: "https://www.theverge.com/2026/10/28/macos-widgets/",
            title: "macOS Desktop Widgets Get Smarter Timeline Refreshes",
            domain: "theverge.com",
            site: "theverge",
            pub: 1793195000,
            age: "4h",
            score: 0.071
        ),
        NewsEntry(
            id: "sample-3",
            url: "https://arstechnica.com/gadgets/2026/10/apple-silicon-benchmarks/",
            title: "New Benchmarks Show Sustained Efficiency Gains Across Desktop Workloads",
            domain: "arstechnica.com",
            site: "arstechnica",
            pub: 1793190000,
            age: "6h",
            score: 0.064
        ),
        NewsEntry(
            id: "sample-4",
            url: "https://daringfireball.net/2026/10/swift-ui-updates",
            title: "Notes on Native Mac Layout and Typography",
            domain: "daringfireball.net",
            site: "daringfireball",
            pub: 1793185000,
            age: "8h",
            score: 0.058
        ),
        NewsEntry(
            id: "sample-5",
            url: "https://9to5mac.com/2026/10/28/swift-package-manager/",
            title: "Building Lightweight Native Mac Utilities with Swift Package Manager",
            domain: "9to5mac.com",
            site: "9to5mac",
            pub: 1793180000,
            age: "11h",
            score: 0.052
        ),
        NewsEntry(
            id: "sample-6",
            url: "https://sixcolors.com/post/2026/10/display-scaling/",
            title: "Why Crisp Text Still Matters on High-DPI Displays",
            domain: "sixcolors.com",
            site: "sixcolors",
            pub: 1793175000,
            age: "14h",
            score: 0.047
        ),
        NewsEntry(
            id: "sample-7",
            url: "https://www.macstories.net/stories/automation-shortcuts/",
            title: "Automating Daily News Workflows on macOS",
            domain: "macstories.net",
            site: "macstories",
            pub: 1793170000,
            age: "18h",
            score: 0.041
        ),
        NewsEntry(
            id: "sample-8",
            url: "https://lwn.net/Articles/123456/",
            title: "Kernel Scheduler Improvements for Interactive Desktop Systems",
            domain: "lwn.net",
            site: "lwn",
            pub: 1793165000,
            age: "22h",
            score: 0.036
        )
    ]
}

public struct HotnewsTimelineProvider: TimelineProvider, Sendable {
    public typealias Entry = HotnewsWidgetEntry

    public static let refreshIntervalSeconds: TimeInterval = 60 * 60
    public static let retryIntervalSeconds: TimeInterval = 5 * 60

    public init() {}

    public func placeholder(in context: Context) -> HotnewsWidgetEntry {
        HotnewsWidgetEntry(
            date: Date(),
            entries: HotnewsWidgetEntry.sampleEntries,
            isPlaceholder: true
        )
    }

    public func getSnapshot(in context: Context, completion: @escaping @Sendable (HotnewsWidgetEntry) -> Void) {
        if context.isPreview {
            let cached = SharedWidgetStorage.loadCachedHotEntries()
            completion(HotnewsWidgetEntry(
                date: Date(),
                entries: cached.isEmpty ? HotnewsWidgetEntry.sampleEntries : cached,
                isPlaceholder: cached.isEmpty
            ))
            return
        }

        Task {
            let entry = await Self.loadEntry()
            completion(entry)
        }
    }

    public func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<HotnewsWidgetEntry>) -> Void) {
        Task {
            let entry = await Self.loadEntry()
            let nextRefresh = entry.errorMessage == nil
                ? Date().addingTimeInterval(Self.refreshIntervalSeconds)
                : Date().addingTimeInterval(Self.retryIntervalSeconds)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    public static func loadEntry(
        apiClient: APIClient? = nil,
        now: Date = Date()
    ) async -> HotnewsWidgetEntry {
        let client = apiClient ?? APIClient(baseURLString: SharedWidgetStorage.loadAPIBaseURL())
        do {
            let response = try await client.fetchFeed(tab: .hot, page: 1)
            if !response.entries.isEmpty {
                SharedWidgetStorage.saveCachedHotEntries(response.entries)
            }
            return HotnewsWidgetEntry(
                date: now,
                entries: response.entries,
                errorMessage: response.entries.isEmpty ? "No stories available" : nil
            )
        } catch {
            let cached = SharedWidgetStorage.loadCachedHotEntries()
            if !cached.isEmpty {
                return HotnewsWidgetEntry(date: now, entries: cached)
            }
            return HotnewsWidgetEntry(
                date: now,
                entries: [],
                errorMessage: error.localizedDescription
            )
        }
    }
}

public enum HotnewsWidgetMetrics {
    public static func horizontalPadding(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall: return 12
        default: return 14
        }
    }

    public static func rowVerticalPadding(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall: return 4.5
        default: return 4.5
        }
    }

    public static func statusFontSize(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall: return 10.5
        default: return 11
        }
    }

    public static func titleFontSize(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall: return 11.5
        default: return 12
        }
    }

    public static func titleLineLimit(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 3
        default: return 2
        }
    }
}

public struct HotnewsWidgetStoryRowView: View {
    public let entry: NewsEntry
    public let rowIndex: Int
    public let totalRows: Int
    public let family: WidgetFamily
    public let maxLinesOverride: Int?

    @Environment(\.widgetRenderingMode) private var renderingMode

    public init(
        entry: NewsEntry,
        rowIndex: Int,
        totalRows: Int = 1,
        family: WidgetFamily,
        maxLinesOverride: Int? = nil
    ) {
        self.entry = entry
        self.rowIndex = rowIndex
        self.totalRows = totalRows
        self.family = family
        self.maxLinesOverride = maxLinesOverride
    }

    private var statusFontSize: CGFloat {
        HotnewsWidgetMetrics.statusFontSize(for: family)
    }

    private var titleFontSize: CGFloat {
        HotnewsWidgetMetrics.titleFontSize(for: family)
    }

    private var titleLineLimit: Int {
        maxLinesOverride ?? HotnewsWidgetMetrics.titleLineLimit(for: family)
    }

    private var horizontalPadding: CGFloat {
        HotnewsWidgetMetrics.horizontalPadding(for: family)
    }

    private var verticalPadding: CGFloat {
        HotnewsWidgetMetrics.rowVerticalPadding(for: family)
    }

    private var rowBackground: Color {
        if renderingMode == .fullColor {
            return NewsColors.rowBackground(forZeroBasedIndex: rowIndex)
        }
        return NewsColors.isOddRowHighlighted(at: rowIndex) ? Color.primary.opacity(0.06) : Color.clear
    }

    private var dividerColor: Color {
        renderingMode == .fullColor ? NewsColors.gainsboro : Color.primary.opacity(0.14)
    }

    private var primaryColor: Color {
        renderingMode == .fullColor ? NewsColors.primaryText : .primary
    }

    private var secondaryColor: Color {
        renderingMode == .fullColor ? NewsColors.gray : .secondary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1.5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.siteLabel)
                    .font(.system(size: statusFontSize, weight: .regular))
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(entry.ageLabel)
                    .font(.system(size: statusFontSize, weight: .regular))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)

                Text(entry.degreesLabel)
                    .font(.system(size: statusFontSize, weight: .regular))
                    .foregroundStyle(NewsColors.accent)
                    .widgetAccentable()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)

                Spacer(minLength: 0)
            }

            Text(entry.title)
                .font(.system(size: titleFontSize, weight: .bold))
                .foregroundStyle(primaryColor)
                .multilineTextAlignment(.leading)
                .lineLimit(titleLineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(rowBackground)
        .overlay(alignment: .bottom) {
            if rowIndex < totalRows - 1 {
                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: HotnewsRowHeightsPreferenceKey.self,
                    value: [rowIndex: geo.size.height]
                )
            }
        )
    }
}

public struct HotnewsRowHeightsPreferenceKey: PreferenceKey {
    public static let defaultValue: [Int: CGFloat] = [:]

    public static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Measures natural stacked height when height is unspecified (for `ViewThatFits`),
/// and divides the full container height equally among rows when placed in a bounded frame.
private struct EqualHeightRowsLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        if let proposedHeight = proposal.height, proposedHeight.isFinite {
            return CGSize(width: width, height: proposedHeight)
        }
        let naturalHeight = subviews.reduce(CGFloat.zero) { partial, subview in
            partial + subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        return CGSize(width: width, height: naturalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let rowHeight = bounds.height / CGFloat(subviews.count)
        let rowProposal = ProposedViewSize(width: bounds.width, height: rowHeight)
        for (index, subview) in subviews.enumerated() {
            let origin = CGPoint(x: bounds.minX, y: bounds.minY + CGFloat(index) * rowHeight)
            subview.place(at: origin, anchor: .topLeading, proposal: rowProposal)
        }
    }
}

public struct HotnewsWidgetEntryView: View {
    public let entry: HotnewsWidgetEntry
    private let familyOverride: WidgetFamily?
    private let onStoryCountSelected: (@Sendable (Int) -> Void)?

    @Environment(\.widgetFamily) private var environmentFamily
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var family: WidgetFamily {
        familyOverride ?? environmentFamily
    }

    public init(
        entry: HotnewsWidgetEntry,
        familyOverride: WidgetFamily? = nil,
        onStoryCountSelected: (@Sendable (Int) -> Void)? = nil
    ) {
        self.entry = entry
        self.familyOverride = familyOverride
        self.onStoryCountSelected = onStoryCountSelected
    }

    private var displayEntries: [NewsEntry] {
        Array(entry.entries.prefix(10))
    }

    private var candidateCounts: [Int] {
        let maxCount = displayEntries.count
        guard maxCount >= 1 else { return [] }
        return Array((1...maxCount).reversed())
    }

    public var body: some View {
        Group {
            if displayEntries.isEmpty {
                emptyStateView
            } else {
                storiesFittingView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(family == .systemSmall ? displayEntries.first.flatMap(WidgetDeepLink.makeArticleURL(for:)) : nil)
        .containerBackground(for: .widget) {
            if renderingMode == .fullColor {
                NewsColors.background
            }
        }
    }

    private var storiesFittingView: some View {
        ViewThatFits(in: .vertical) {
            ForEach(candidateCounts, id: \.self) { count in
                storiesStack(count: count)
                    .onAppear {
                        onStoryCountSelected?(count)
                    }
            }
            if let first = displayEntries.first {
                interactiveRow(entry: first, index: 0, totalRows: 1, maxLinesOverride: 2)
                    .onAppear {
                        onStoryCountSelected?(1)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func storiesStack(count: Int) -> some View {
        EqualHeightRowsLayout {
            ForEach(Array(displayEntries.prefix(count).enumerated()), id: \.element.id) { index, item in
                interactiveRow(entry: item, index: index, totalRows: count, maxLinesOverride: nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func interactiveRow(entry: NewsEntry, index: Int, totalRows: Int, maxLinesOverride: Int?) -> some View {
        let row = HotnewsWidgetStoryRowView(
            entry: entry,
            rowIndex: index,
            totalRows: totalRows,
            family: family,
            maxLinesOverride: maxLinesOverride
        )
        if family != .systemSmall, let url = WidgetDeepLink.makeArticleURL(for: entry) {
            Link(destination: url) {
                row
            }
        } else {
            row
        }
    }

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hottest")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NewsColors.accent)
                .widgetAccentable()
            Text(entry.errorMessage ?? "Fetching articles...")
                .font(.system(size: 12))
                .foregroundStyle(renderingMode == .fullColor ? NewsColors.gray : .secondary)
                .lineLimit(3)
        }
        .padding(HotnewsWidgetMetrics.horizontalPadding(for: family))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
