import SwiftUI

/// Placeholder for training analytics.
struct AnalyticsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Analytics",
                systemImage: "chart.xyaxis.line",
                description: Text("Trends from your logged times will appear here.")
            )
            .navigationTitle("Analytics")
        }
    }
}

#Preview {
    AnalyticsView()
}
