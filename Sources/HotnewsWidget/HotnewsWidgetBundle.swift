import SwiftUI
import WidgetKit
import HotnewsWidgetCore

@main
struct HotnewsWidgetBundle: WidgetBundle {
    var body: some Widget {
        HotnewsHottestWidget()
    }
}

struct HotnewsHottestWidget: Widget {
    let kind = "com.lucianmarin.macnews.widget.hottest"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HotnewsTimelineProvider()) { entry in
            HotnewsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Hottest")
        .description("Top stories from the Hotnews Hottest feed.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
