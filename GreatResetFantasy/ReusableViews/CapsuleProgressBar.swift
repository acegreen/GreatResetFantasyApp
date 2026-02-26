//
//  CapsuleProgressBar.swift
//  GreatResetFantasy
//

import SwiftUI

/// A horizontal capsule-shaped progress bar (background + fill by ratio).
struct CapsuleProgressBar<Fill: ShapeStyle>: View {
    var ratio: Double
    var fill: Fill
    var background: Color = Color.secondary.opacity(0.2)
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(background)
                    .frame(height: height)
                Capsule()
                    .fill(fill)
                    .frame(width: max(0, min(1, ratio)) * proxy.size.width, height: height)
            }
        }
        .frame(height: height + 2)
    }
}

extension CapsuleProgressBar where Fill == Color {
    init(ratio: Double, fill: Color = .red, background: Color = Color.secondary.opacity(0.2), height: CGFloat = 10) {
        self.ratio = ratio
        self.fill = fill
        self.background = background
        self.height = height
    }
}
