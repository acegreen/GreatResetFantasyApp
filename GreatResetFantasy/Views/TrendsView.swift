// import Inject
import SwiftUI
import Charts

struct TrendsView: View {
//  @ObserveInjection var inject
    @Environment(CalculatorDataStore.self) private var calculatorStore
    @Environment(StreakStore.self) private var streakStore
    private var calculator: ResetCalculatorManager { calculatorStore.calculator }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    wealthShareLineSection
                    perCapitaWealthSection
                    peopleInPovertySection
                    populationSharePieSection
                    explanationSection
                }
                .padding()
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.large)
            // .enableInjection()
        }
    }

    // MARK: - Bracket scale (single source for chart colors)

    private var bracketChartDomain: [String] {
        Brackets.allCases.map(\.displayName)
    }

    private var bracketChartRange: [Color] {
        Brackets.allCases.map(\.color)
    }

    // MARK: - Share helper

    private func renderChartCard<Content: View>(@ViewBuilder content: () -> Content) -> UIImage? {
        let card = content()
            .padding()
            .frame(width: 400, height: 320)
            .background(Color(.systemBackground))
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }

    private func chartShareButton(shareImage: UIImage?) -> some View {
        Group {
            if let uiImage = shareImage {
                let sharedImage = SharedImage(image: uiImage)
                ShareLink(
                    item: sharedImage,
                    preview: SharePreview(
                        AppConstants.sharePreviewTitle,
                        image: Image(uiImage: sharedImage.image)
                    )
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3.weight(.semibold))
                }
                .simultaneousGesture(TapGesture().onEnded { streakStore.recordShare() })
                .accessibilityLabel("Share this chart")
            }
        }
    }

    // MARK: - Wealth share (line)

    private func wealthShareLineContent(includeShareButton: Bool) -> some View {
        let data = flattenedTrendData
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("Wealth Share by Bracket by Scenario")
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if includeShareButton,
                   let uiImage = renderChartCard(content: { wealthShareLineContent(includeShareButton: false) }) {
                    chartShareButton(shareImage: uiImage)
                }
            }
            Chart(data) { item in
                LineMark(
                    x: .value("Scenario", item.scenarioLabel),
                    y: .value("Wealth Share (%)", item.share)
                )
                .foregroundStyle(by: .value("Bracket", item.bracket.displayName))
                .symbol(by: .value("Bracket", item.bracket.displayName))
            }
            .frame(height: 260)
            .chartYAxisLabel("%")
            .chartForegroundStyleScale(domain: bracketChartDomain, range: bracketChartRange)
            .chartLegend(position: .bottom, alignment: .center)
        }
    }

    private var wealthShareLineSection: some View {
        CardView {
            wealthShareLineContent(includeShareButton: true)
        }
    }

    // MARK: - People in poverty

    private func peopleInPovertyContent(includeShareButton: Bool) -> some View {
        let data = calculator.povertyTrendData
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("Estimated People in Poverty by Scenario")
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if includeShareButton,
                   let uiImage = renderChartCard(content: { peopleInPovertyContent(includeShareButton: false) }) {
                    chartShareButton(shareImage: uiImage)
                }
            }
            Chart(data, id: \.scenarioLabel) { item in
                BarMark(
                    x: .value("Scenario", item.scenarioLabel),
                    y: .value("People (billions)", item.peopleInPoverty / 1_000_000_000)
                )
                .foregroundStyle(.red.gradient)
            }
            .frame(height: 220)
            .chartYAxisLabel("Billions")
        }
    }

    private var peopleInPovertySection: some View {
        CardView {
            peopleInPovertyContent(includeShareButton: true)
        }
    }

    // MARK: - Per-capita wealth by bracket (log scale)

    /// Log10 of per-capita wealth for charting; floor at 100 to avoid log(0).
    private func log10PerCapita(_ value: Double) -> Double {
        log10(max(value, 100))
    }

    private static let perCapitaLogAxisValues: [Double] = [2, 3, 4, 5, 6, 7] // log10($100) ... log10(10M)

    private func perCapitaLogAxisLabel(_ logValue: Double) -> String {
        let value = pow(10, logValue)
        if value >= 1_000_000 { return String(format: "$%.0fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "$%.0fk", value / 1_000) }
        return String(format: "$%.0f", value)
    }

    private func perCapitaWealthContent(includeShareButton: Bool) -> some View {
        let data = calculator.perCapitaTrendData
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("Per-Capita Wealth by Bracket (log scale)")
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if includeShareButton,
                   let uiImage = renderChartCard(content: { perCapitaWealthContent(includeShareButton: false) }) {
                    chartShareButton(shareImage: uiImage)
                }
            }
            Chart(data) { item in
                LineMark(
                    x: .value("Scenario", item.scenarioLabel),
                    y: .value("Wealth (log)", log10PerCapita(item.perCapitaWealth))
                )
                .foregroundStyle(by: .value("Bracket", item.bracket.displayName))
                .symbol(by: .value("Bracket", item.bracket.displayName))
            }
            .frame(height: 260)
            .chartForegroundStyleScale(domain: bracketChartDomain, range: bracketChartRange)
            .chartLegend(position: .bottom, alignment: .center)
            .chartYScale(domain: 2.0 ... 7.5)
            .chartYAxis {
                AxisMarks(values: Self.perCapitaLogAxisValues) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let logV = value.as(Double.self) {
                            Text(perCapitaLogAxisLabel(logV))
                        }
                    }
                }
            }
        }
    }

    private var perCapitaWealthSection: some View {
        CardView {
            perCapitaWealthContent(includeShareButton: true)
        }
    }

    // MARK: - Population share (pie)

    private func populationSharePieContent(includeShareButton: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("Share of World Population by Bracket")
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if includeShareButton,
                   let uiImage = renderChartCard(content: { populationSharePieContent(includeShareButton: false) }) {
                    chartShareButton(shareImage: uiImage)
                }
            }
            Chart(calculator.brackets) { bracket in
                SectorMark(
                    angle: .value("Population %", bracket.populationShare)
                )
                .foregroundStyle(by: .value("Bracket", bracket.bracket.displayName))
            }
            .frame(height: 220)
            .chartForegroundStyleScale(domain: bracketChartDomain, range: bracketChartRange)
            .chartLegend(position: .bottom, alignment: .center)
        }
    }

    private var populationSharePieSection: some View {
        CardView {
            populationSharePieContent(includeShareButton: true)
        }
    }

    // MARK: - Wealth share (line) data

    private var flattenedTrendData: [TrendChartPoint] {
        var result: [TrendChartPoint] = []
        // Use the same wealth share calculations as the simulator,
        // so this line chart matches the distribution shown in SimulatorView.
        for point in calculator.wealthShareTrendData {
            for bracket in Brackets.allCases {
                if let share = point.bracketShares[bracket] {
                    result.append(TrendChartPoint(
                        scenarioLabel: point.scenarioLabel,
                        bracket: bracket,
                        share: share
                    ))
                }
            }
        }
        return result
    }

    private struct TrendChartPoint: Identifiable {
        var id: String { "\(scenarioLabel)-\(bracket.displayName)" }
        let scenarioLabel: String
        let bracket: Brackets
        let share: Double
    }

    // MARK: - Explanation section

    private var explanationSection: some View {
        ExplanationSection(
            title: "How to Read These Charts",
            body: "These visualizations show how wealth distribution could change under different reset scenarios. Scenarios go from the current distribution (left) to more severe resets (right). Wealth share shows each bracket's portion of total wealth; per-capita wealth shows average wealth per person in each bracket; the poverty chart estimates how many people would fall below the poverty line; and the population pie shows what share of the world's people fall into each wealth bracket."
        )
    }
}

#Preview {
    TrendsView()
}
