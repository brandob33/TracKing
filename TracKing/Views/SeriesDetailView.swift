import SwiftUI
import SwiftData

/// Shows the drills in a named series from the coach's library, e.g. "Warm Up Series A".
struct SeriesDetailView: View {
    let name: String

    @Query private var matches: [RoutineSeries]

    init(name: String) {
        self.name = name
        _matches = Query(filter: #Predicate<RoutineSeries> { $0.name == name })
    }

    var body: some View {
        Group {
            if let series = matches.first {
                List {
                    Section {
                        ForEach(Array(series.drills.enumerated()), id: \.offset) { index, drill in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.tint)
                                    .monospacedDigit()
                                Text(drill)
                            }
                        }
                    } header: {
                        Label("Drills", systemImage: series.kind.systemImage)
                    }

                    if !series.notes.isEmpty {
                        Section("Coach's Notes") {
                            Text(series.notes)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Series Not Found",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Your coach hasn't added the drills for \(name) yet.")
                )
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SeriesDetailView(name: "Warm Up Series A")
    }
    .modelContainer(SampleData.previewContainer)
}
