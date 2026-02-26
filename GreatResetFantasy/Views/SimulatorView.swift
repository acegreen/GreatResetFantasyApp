//
//  SimulatorView.swift
//  GreatResetFantasy
//

import SwiftUI
// import Inject
import UIKit

struct SimulatorView: View {
    // @ObserveInjection var inject

    @Environment(CalculatorDataStore.self) private var calculatorStore
    @Environment(StreakStore.self) private var streakStore
    @State private var zerosCut: Int = 0

    private var calculator: ResetCalculatorManager { calculatorStore.calculator }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    povertySection
                    wealthBarsSection
                    sliderSection
                    explanatoryNote
                }
                .padding()
            }
            .navigationTitle("Simulator")
            .navigationBarTitleDisplayMode(.large)
        }
        // .enableInjection()
    }

    private func povertySectionContent(includeShareButton: Bool) -> some View {
        let povertyCount = calculator.estimatedPeopleInPoverty(zerosCut: zerosCut)
        let povertyShare = povertyCount / calculator.worldPopulation

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text("Estimated People in Poverty")
                    .font(.headline)
                Spacer(minLength: 8)
                if includeShareButton, let uiImage = simulatorShareImage() {
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
                    .accessibilityLabel("Share this scenario")
                }
            }

            Text("\(NumberFormatting.people(povertyCount)) people")
                .font(.title2.bold())
                .foregroundStyle(povertyShare > 0.5 ? .red : .orange)

            Text(String(format: "≈ %.0f%% of the world population",
                        povertyShare * 100))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            CapsuleProgressBar(ratio: povertyShare, fill: .red)
        }
    }

    private var povertySection: some View {
        CardView {
            povertySectionContent(includeShareButton: true)
        }
    }

    private func wealthBarsSectionContent() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wealth Distribution by Bracket")
                .font(.headline)

            ForEach(calculator.brackets) { bracket in
                let beforeBase = calculator.wealthFor(bracket)
                let afterBase = calculator.denominatedWealth(
                    calculator.adjustedWealth(for: bracket, zerosCut: zerosCut),
                    zerosCut: zerosCut
                )
                let dynamicShare = calculator.wealthShareAfterReset(for: bracket, zerosCut: zerosCut)
                let ratio = dynamicShare / 100.0

                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(bracket.color)
                                    .frame(width: 10, height: 10)
                                Text(bracket.name)
                                    .font(.subheadline)
                            }
                            Spacer()
                            Text(String(format: "%.0f%% wealth",
                                        dynamicShare))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    CapsuleProgressBar(ratio: ratio, fill: bracket.color.gradient)

                    HStack {
                        Text("Before: \(NumberFormatting.wealth(beforeBase))")
                        Spacer()
                        Text("After: \(NumberFormatting.wealth(afterBase))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var wealthBarsSection: some View {
        CardView {
            wealthBarsSectionContent()
        }
    }

    private var sliderSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
            Text("Zeros Cut From All Balances")
                .font(.headline)

            HStack {
                Slider(
                    value: Binding(
                        get: { Double(zerosCut) },
                        set: { zerosCut = Int($0.rounded()) }
                    ),
                    in: 0...9
                )
                Text("\(zerosCut)")
                    .font(.headline)
                    .frame(width: 32, alignment: .trailing)
            }

            Text("Simulates a currency re-denomination where balances are divided by 10^N.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var explanatoryNote: some View {
        ExplanationSection(
            title: "About This Visualization",
            body: "This is an illustrative model of a hypothetical \"market total reset\" where nominal wealth is sharply reduced. It does not represent forecasts or official data, but is meant to spark discussion about how abrupt monetary resets can affect wealth brackets and global poverty."
        )
    }

    private func simulatorShareImage() -> UIImage? {
        let card = VStack(alignment: .leading, spacing: 16) {
            CardView {
                povertySectionContent(includeShareButton: false)
            }
            CardView {
                wealthBarsSectionContent()
            }
            Text("Zeros cut from all balances: \(zerosCut)")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 400)
        .background(Color(.systemBackground))

        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

#Preview {
    SimulatorView()
}
