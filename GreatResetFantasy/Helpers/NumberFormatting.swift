//
//  NumberFormatting.swift
//  GreatResetFantasy
//

import Foundation

enum NumberFormatting {
    /// Short form for wealth (e.g. 1.2K, 3.4M, 5.6B, 7.8T). Handles negative values.
    static func wealth(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        switch absValue {
        case 0..<1_000:
            return "\(sign)\(Int(absValue))"
        case 1_000..<1_000_000:
            return String(format: "\(sign)%.1fK", absValue / 1_000)
        case 1_000_000..<1_000_000_000:
            return String(format: "\(sign)%.1fM", absValue / 1_000_000)
        case 1_000_000_000..<1_000_000_000_000:
            return String(format: "\(sign)%.1fB", absValue / 1_000_000_000)
        default:
            return String(format: "\(sign)%.1fT", absValue / 1_000_000_000_000)
        }
    }

    /// Word form for people counts (e.g. 1.2 Thousand, 3.4 Million, 5.6 Billion). Handles negative values.
    static func people(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        switch absValue {
        case 0..<1_000:
            return "\(sign)\(Int(absValue))"
        case 1_000..<1_000_000:
            return String(format: "\(sign)%.1f Thousand", absValue / 1_000)
        case 1_000_000..<1_000_000_000:
            return String(format: "\(sign)%.1f Million", absValue / 1_000_000)
        default:
            return String(format: "\(sign)%.1f Billion", absValue / 1_000_000_000)
        }
    }

    /// Admin/config: very large numbers (T, B, M or plain).
    static func large(_ n: Double) -> String {
        if n >= 1_000_000_000_000 {
            return String(format: "%.1fT", n / 1_000_000_000_000)
        }
        if n >= 1_000_000_000 {
            return String(format: "%.1fB", n / 1_000_000_000)
        }
        if n >= 1_000_000 {
            return String(format: "%.1fM", n / 1_000_000)
        }
        return String(format: "%.0f", n)
    }

    /// Admin/config: thousands or plain number.
    static func compact(_ n: Double) -> String {
        if n >= 1000 {
            return String(format: "%.1fK", n / 1000)
        }
        return String(format: "%.0f", n)
    }
}
