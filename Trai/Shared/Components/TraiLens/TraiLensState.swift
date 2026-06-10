//
//  TraiLensState.swift
//  Trai
//
//  Animation states for Trai's visual identity
//

import SwiftUI

/// The focus states of Trai's lens
public enum TraiLensState: Equatable, Hashable {
    /// Gentle breathing - calm, waiting
    case idle

    /// Deep breath - receptive, user is typing
    case listening

    /// Fast breathing - processing, generating response
    case thinking

    /// Steady flow - streaming response
    case answering
}
