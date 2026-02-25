//
//  TraiCoachAdaptivePreferences.swift
//  Trai
//
//  Infers coaching preferences from user behavior and recent context.
//

import Foundation

enum TraiCoachTone: String, CaseIterable, Identifiable, Sendable {
    case encouraging
    case balanced
    case direct

    var id: String { rawValue }

    var title: String {
        switch self {
        case .encouraging: "Encouraging"
        case .balanced: "Balanced"
        case .direct: "Direct"
        }
    }
}
