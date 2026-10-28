import SwiftUI

/// The `strip` display style: one horizontal row, one ring column per enabled
/// metric, in the usual overlay order.
struct StripView: View {
    let metrics: [MetricID]
    let readings: [MetricID: MetricReading]
    let fontSize: FontSizeMode
    let compact: Bool
    let colour: Bool

    var body: some View {
        if metrics.isEmpty {
            Text("No metrics selected")
                .font(.system(size: fontSize.labelPointSize))
                .foregroundStyle(.secondary)
                .padding(StripLayout.padding)
        } else {
            HStack(alignment: .top, spacing: StripLayout.cellSpacing) {
                ForEach(metrics, id: \.self) { id in
                    StripCellView(id: id,
                                  reading: readings[id],
                                  fontSize: fontSize,
                                  compact: compact,
                                  colour: colour)
                        .equatable()
                }
            }
            .padding(StripLayout.padding)
        }
    }
}
