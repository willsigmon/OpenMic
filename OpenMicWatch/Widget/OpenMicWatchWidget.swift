import WidgetKit
import SwiftUI

struct OpenMicEntry: TimelineEntry {
    let date: Date
}

struct OpenMicWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> OpenMicEntry {
        OpenMicEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (OpenMicEntry) -> Void) {
        completion(OpenMicEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OpenMicEntry>) -> Void) {
        let entry = OpenMicEntry(date: .now)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Complication Views

struct OpenMicCircularView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "mic.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.cyan)
        }
        .widgetLabel("OpenMic")
    }
}

struct OpenMicRectangularView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 1) {
                Text("OpenMic")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Tap to talk")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OpenMicInlineView: View {
    var body: some View {
        Label("OpenMic", systemImage: "mic.fill")
    }
}

struct OpenMicCornerView: View {
    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.cyan)
            .widgetLabel("OpenMic")
    }
}

// MARK: - Widget Entry View

struct OpenMicWidgetEntryView: View {
    let entry: OpenMicEntry
    @Environment(\.widgetFamily) var family

    private static let voiceURL: URL = {
        guard let url = URL(string: "openmic://voice") else {
            preconditionFailure("openmic://voice is not a valid URL — check scheme configuration")
        }
        return url
    }()

    var body: some View {
        switch family {
        case .accessoryCircular:
            OpenMicCircularView()
                .widgetURL(Self.voiceURL)
        case .accessoryRectangular:
            OpenMicRectangularView()
                .widgetURL(Self.voiceURL)
        case .accessoryInline:
            OpenMicInlineView()
                .widgetURL(Self.voiceURL)
        case .accessoryCorner:
            OpenMicCornerView()
                .widgetURL(Self.voiceURL)
        default:
            OpenMicCircularView()
                .widgetURL(Self.voiceURL)
        }
    }
}

// MARK: - Widget Definition

@main
struct OpenMicWatchWidget: Widget {
    let kind = "OpenMicWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OpenMicWidgetProvider()) { entry in
            OpenMicWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("OpenMic")
        .description("Quick-launch voice assistant from your watch face.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}
