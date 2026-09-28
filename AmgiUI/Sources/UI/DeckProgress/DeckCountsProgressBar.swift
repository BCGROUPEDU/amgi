//
//  DeckCountsProgressBar.swift
//  UI
//
//  Created by Vladimir Gusev on 28.09.2026.
//

public import SwiftUI
import Theme

/// Universal study-progress component: one segmented bar across the three
/// Anki queue states (new / learning / review), optionally with a compact
/// count row. Used by the review header, the completed state, and anywhere
/// else a deck's remaining counts need one surface.
///
/// Built on the same palette slots as `DeckDetailTile`
/// (`cardStateNew` / `cardStateLearning` / `cardStateReview`), so a deck's
/// count colors agree wherever they appear. Deliberately takes `Int`s rather
/// than `DeckCounts` so `UI` keeps its "no feature or engine types" rule —
/// callers unwrap the domain type themselves.
public struct DeckCountsProgressBar: View {
    public let newCount: Int
    public let learnCount: Int
    public let reviewCount: Int
    public let showsCounts: Bool

    @Environment(\.palette) private var palette

    public init(
        newCount: Int,
        learnCount: Int,
        reviewCount: Int,
        showsCounts: Bool = false
    ) {
        self.newCount = newCount
        self.learnCount = learnCount
        self.reviewCount = reviewCount
        self.showsCounts = showsCounts
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            bar
            if showsCounts {
                countRow
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var total: Int { max(newCount + learnCount + reviewCount, 1) }

    private var bar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                segment(newCount, color: palette.cardStateNew, width: geo.size.width)
                segment(learnCount, color: palette.cardStateLearning, width: geo.size.width)
                segment(reviewCount, color: palette.cardStateReview, width: geo.size.width)
            }
        }
        .frame(height: 4)
        .clipShape(Capsule())
        .background(Capsule().fill(palette.separator))
        .animation(AmgiMotion.standard, value: newCount)
        .animation(AmgiMotion.standard, value: learnCount)
        .animation(AmgiMotion.standard, value: reviewCount)
    }

    private func segment(_ count: Int, color: Color, width: CGFloat) -> some View {
        Group {
            if count > 0 {
                Capsule()
                    .fill(color)
                    .frame(width: max(3, width * CGFloat(count) / CGFloat(total)))
            }
        }
    }

    private var countRow: some View {
        HStack(spacing: AmgiSpacing.md) {
            countChip(label: "New", value: newCount, color: palette.cardStateNew)
            countChip(label: "Learning", value: learnCount, color: palette.cardStateLearning)
            countChip(label: "Review", value: reviewCount, color: palette.cardStateReview)
        }
    }

    private func countChip(label: String, value: Int, color: Color) -> some View {
        Group {
            if value > 0 || showsCounts {
                HStack(spacing: 3) {
                    Text(label)
                        .amgiFont(size: 11, weight: .medium)
                        .foregroundStyle(palette.textTertiary)
                    Text("\(value)")
                        .amgiFont(size: 11, weight: .semibold)
                        .foregroundStyle(color)
                        .monospacedDigit()
                }
            }
        }
    }

    private var accessibilityLabel: String {
        "\(newCount) new, \(learnCount) learning, \(reviewCount) review due"
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Mixed counts") {
    DeckCountsProgressBar(newCount: 5, learnCount: 2, reviewCount: 13, showsCounts: true)
        .padding()
        .environment(\.palette, .vividLight)
        .preferredColorScheme(.light)
}

#Preview("All done") {
    DeckCountsProgressBar(newCount: 0, learnCount: 0, reviewCount: 0, showsCounts: true)
        .padding()
        .environment(\.palette, .vividLight)
        .preferredColorScheme(.light)
}

#Preview("Bar only") {
    DeckCountsProgressBar(newCount: 5, learnCount: 2, reviewCount: 13)
        .padding()
        .environment(\.palette, .vividLight)
        .preferredColorScheme(.light)
}

#Preview("Dark — Bar only") {
    DeckCountsProgressBar(newCount: 5, learnCount: 2, reviewCount: 13, showsCounts: true)
        .padding()
        .environment(\.palette, .vividDark)
        .preferredColorScheme(.dark)
}
#endif