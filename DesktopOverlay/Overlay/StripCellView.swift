import SwiftUI

/// One column of the strip: a ring with the value in its centre, the metric name
/// with an SF Symbol, up to two detail lines, and a one-word status hint.
/// `Equatable` so SwiftUI skips re-laying-out a column whose reading did not
/// change this tick (Temp, Fan, Battery and RAM rarely do).
struct StripCellView: View, Equatable {
    let id: MetricID
    let reading: MetricReading?
    let fontSize: FontSizeMode
    let compact: Bool
    let colour: Bool

    private var valuePoints: CGFloat { fontSize.valuePointSize }
    private var ring: CGFloat { StripLayout.ringSize(valuePointSize: valuePoints, compact: compact) }
    private var cell: CGFloat { StripLayout.cellWidth(valuePointSize: valuePoints, compact: compact) }
    private var tint: Color { colour ? id.ringColor : .primary }

    var body: some View {
        let center = MetricFormatter.ringCenter(for: id, reading: reading)
        let details = compact ? [] : MetricFormatter.ringDetail(for: id, reading: reading)
        let hint = compact ? nil : MetricFormatter.stateHint(for: id, reading: reading)

        VStack(spacing: 3) {
            ZStack {
                GaugeView(value: reading?.graphSample ?? 0, tint: tint, lineWidthRatio: 0.085)
                    .frame(width: ring, height: ring)
                VStack(spacing: 0) {
                    Text(center.value)
                        .font(.system(size: valuePoints + (compact ? 0 : 2), weight: .medium))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let unit = center.unit {
                        Text(unit)
                            .font(.system(size: fontSize.labelPointSize + 1))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: ring * 0.72)
            }

            HStack(spacing: 4) {
                Image(systemName: id.symbolName)
                    .foregroundStyle(tint)
                Text(id.shortLabel)
            }
            .font(.system(size: fontSize.labelPointSize + 2, weight: .medium))
            .lineLimit(1)

            if !compact {
                ForEach(Array(details.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: fontSize.labelPointSize + 1))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Text(hint ?? " ")
                    .font(.system(size: fontSize.labelPointSize + 1, weight: .medium))
                    .lineLimit(1)
            }
        }
        .frame(width: cell)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MetricFormatter.accessibilityText(for: id, reading: reading))
        .accessibilityHint(MetricFormatter.tooltip(for: id, reading: reading))
    }
}
