import SwiftUI

/// Native macOS principal toolbar control: displays the 3 segmented feed tabs, or replaces
/// them with the centered site filter button when viewing a specific site.
public struct ToolbarSegmentedTabsView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    private var selectedTabBinding: Binding<FeedTab> {
        Binding(
            get: { appState.selectedTab },
            set: { newTab in
                appState.selectTab(newTab)
            }
        )
    }

    public var body: some View {
        if let activeSite = appState.selectedSite {
            Button {
                appState.clearSiteFilter()
            } label: {
                HStack(spacing: 4) {
                    Text(activeSite)
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 6)
            }
            .help("Clear \(activeSite) filter")
        } else {
            Picker("Feed", selection: selectedTabBinding) {
                ForEach(FeedTab.allCases) { tab in
                    Text(tab.title)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
            .help("Switch between Hottest, Coldest, and Newest feeds")
        }
    }
}

public struct MainNewsView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        RefreshableScrollView {
            await appState.loadFeed(reset: true)
        } content: {
            feedContent
        }
        .frame(
            minWidth: NewsTheme.minWindowWidth,
            maxWidth: NewsTheme.maxWindowWidth,
            minHeight: NewsTheme.minWindowHeight,
            maxHeight: .infinity
        )
        .background(NewsTheme.background)
        .background(
            NewsWindowConfigurator()
                .frame(width: 0, height: 0)
        )
        .toolbar {
            ToolbarItem(placement: .principal) {
                ToolbarSegmentedTabsView()
            }
        }
        .sheet(isPresented: $appState.isShowingSettings) {
            SettingsSheetView()
                .environmentObject(appState)
        }
        .task(id: "\(appState.selectedTab.rawValue)-\(appState.selectedSite ?? "")-\(appState.feedRefreshTrigger.uuidString)") {
            await appState.loadFeed(reset: true)
        }
    }

    @ViewBuilder
    private var feedContent: some View {
        if appState.isLoading && appState.entries.isEmpty {
            statusRow {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Fetching articles...")
                        .font(.system(size: 14))
                        .foregroundStyle(NewsTheme.gray)
                }
            }
        } else if let errorMessage = appState.errorMessage, appState.entries.isEmpty {
            statusRow {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(NewsTheme.accent)
                    Button("Retry") {
                        appState.refresh()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NewsTheme.primaryText)
                    .buttonStyle(.newsLink)
                }
            }
        } else if appState.entries.isEmpty {
            statusRow {
                Text("Fetching articles...")
                    .font(.system(size: 14))
                    .foregroundStyle(NewsTheme.gray)
            }
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(appState.entries.enumerated()), id: \.element.id) { index, entry in
                    NewsRowView(entry: entry, rowIndex: index)
                        .onAppear {
                            Task {
                                await appState.loadMoreIfNeeded(currentEntry: entry)
                            }
                        }
                }

                if appState.isLoadingMore {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading more...")
                            .font(.system(size: 13))
                            .foregroundStyle(NewsTheme.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                } else if appState.canLoadMore {
                    Button {
                        Task {
                            await appState.loadFeed(reset: false)
                        }
                    } label: {
                        Text("Load more")
                            .font(.system(size: 13))
                            .foregroundStyle(NewsTheme.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.newsLink)
                    .onAppear {
                        Task {
                            await appState.loadFeed(reset: false)
                        }
                    }
                }
            }
        }
    }

    private func statusRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            content()
                .frame(maxWidth: NewsTheme.maxReadingWidth, alignment: .leading)
                .padding(.horizontal, NewsTheme.horizontalPadding)
                .padding(.vertical, 16)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(NewsTheme.oddRowBackground)
    }
}

public struct SettingsSheetView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var serverURL: String = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hotnews API Server")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(NewsTheme.primaryText)

            TextField("https://news.lucianmarin.com", text: $serverURL)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(NewsTheme.oddRowBackground)
                )
                .onSubmit {
                    saveAndDismiss()
                }

            HStack {
                Button("Reset Default") {
                    serverURL = APIClient.defaultBaseURL
                }
                .font(.system(size: 12))
                .foregroundStyle(NewsTheme.gray)
                .buttonStyle(.newsLink)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 13))
                .foregroundStyle(NewsTheme.gray)
                .buttonStyle(.newsLink)

                Button("Save") {
                    saveAndDismiss()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(NewsTheme.accent)
                )
                .buttonStyle(.newsLink)
            }
        }
        .padding(20)
        .frame(width: 360)
        .background(NewsTheme.background)
        .onAppear {
            serverURL = appState.apiBaseURL
        }
    }

    private func saveAndDismiss() {
        appState.updateAPIBaseURL(serverURL)
        dismiss()
    }
}
