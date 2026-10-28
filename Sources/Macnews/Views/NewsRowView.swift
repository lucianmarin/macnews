import SwiftUI

/// Mirrors `templates/entry.html` and `static/style.sass` from `../news`,
/// replacing the 10-step page gradient with odd row highlighting (`isOddRow == true`)
/// and even rows unhighlighted (`isOddRow == false`).
public struct NewsRowView: View {
    @EnvironmentObject private var appState: AppState
    public let entry: NewsEntry
    public let rowIndex: Int

    public init(entry: NewsEntry, rowIndex: Int) {
        self.entry = entry
        self.rowIndex = rowIndex
    }

    public var isOddRow: Bool {
        AppState.isOddRowHighlighted(at: rowIndex)
    }

    public var rowBackgroundColor: Color {
        NewsTheme.rowBackground(forZeroBasedIndex: rowIndex)
    }

    private var isArticleVisited: Bool {
        appState.isArticleVisited(entry.url)
    }

    public var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                // .small metadata row: site + age ago + score°
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Button {
                        appState.selectSite(entry.siteLabel)
                    } label: {
                        Text(entry.siteLabel)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(NewsTheme.primaryText)
                    }
                    .buttonStyle(.newsLink)

                    Text(entry.ageLabel)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(NewsTheme.gray)

                    Text(entry.degreesLabel)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(NewsTheme.accent)

                    Spacer(minLength: 0)
                }

                // h4.title headline
                Button {
                    appState.openArticle(entry)
                } label: {
                    Text(entry.title)
                        .font(.system(size: 14, weight: .bold))
                        .lineSpacing(3)
                        .foregroundStyle(isArticleVisited ? NewsTheme.visitedText : NewsTheme.primaryText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.newsLink)

                // .summary truncated description
                if !entry.summary.isEmpty {
                    Text(entry.summary)
                        .font(.system(size: 14, weight: .regular))
                        .lineSpacing(3)
                        .foregroundStyle(NewsTheme.darkGray)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: NewsTheme.maxReadingWidth, alignment: .leading)
            .padding(.horizontal, NewsTheme.horizontalPadding)
            .padding(.vertical, NewsTheme.rowVerticalPadding)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(rowBackgroundColor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NewsTheme.gainsboro)
                .frame(height: 1)
        }
    }
}
