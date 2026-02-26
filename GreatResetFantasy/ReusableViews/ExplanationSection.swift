//
//  ExplanationSection.swift
//  GreatResetFantasy
//

import SwiftUI

/// A reusable section with a bold title and secondary body text (e.g. "How to use", "About").
struct ExplanationSection: View {
    let title: String
    let bodyText: String

    init(title: String, body: String) {
        self.title = title
        self.bodyText = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
            Text(bodyText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
