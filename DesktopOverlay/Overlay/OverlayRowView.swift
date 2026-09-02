import SwiftUI

/// One metric line: short label, bold value, optional sparkline (spec §4).
struct OverlayRowView: View {
    let id: MetricID
    let reading: MetricReading?
    let history: [Double]
    let fontSize: FontSizeMode
    let compact: Bool

    private var isUnavailable: Bool {
        reading == nil || reading?.primary == .unavailable
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(id.shortLabel)
                .font(.system(size: fontSize.labelPointSize, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: fontSize.labelPointSize * 3.6, alignment: .leading)

            Text(MetricFormatter.primaryText(for: id, reading: reading))
                .font(.system(size: fontSize.valuePointSize, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isUnavailable ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if !compact, let hint = MetricFormatter.stateHint(for: id, reading: reading) {
                Text(hint)
                    .font(.system(size: fontSize.labelPointSize))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .fixedSize()
            }

            Spacer(minLength: 2)

            if !compact, history.count >= 2 {
                SparklineView(samples: history)
                    .frame(width: 44, height: fontSize.valuePointSize + 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(MetricFormatter.tooltip(for: id, reading: reading))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MetricFormatter.accessibilityText(for: id, reading: reading))
    }
}
