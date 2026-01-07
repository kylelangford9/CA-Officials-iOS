//
//  HapticManager.swift
//  California Voters
//
//  Centralized haptic feedback for improved tactile experience
//

import UIKit
import SwiftUI

/**
 Provides consistent haptic feedback throughout the app.
 
 Haptic feedback enhances the user experience by providing tactile confirmation
 of actions, especially useful for accessibility and user engagement.
 */
class HapticManager {
    
    static let shared = HapticManager()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()
    
    private init() {
        // Prepare generators for faster response
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
        selection.prepare()
    }
    
    // MARK: - Impact Feedback
    
    /// Light tap feedback for subtle interactions
    func light() {
        impactLight.impactOccurred()
        impactLight.prepare() // Prepare for next use
    }
    
    /// Medium tap feedback for standard button presses
    func medium() {
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }
    
    /// Heavy tap feedback for important actions
    func heavy() {
        impactHeavy.impactOccurred()
        impactHeavy.prepare()
    }
    
    // MARK: - Selection Feedback
    
    /// Selection changed feedback (like picker scrolling)
    func selectionChanged() {
        selection.selectionChanged()
        selection.prepare()
    }
    
    // MARK: - Notification Feedback
    
    /// Success notification (e.g., data loaded successfully)
    func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }
    
    /// Warning notification (e.g., caution message)
    func warning() {
        notification.notificationOccurred(.warning)
        notification.prepare()
    }
    
    /// Error notification (e.g., operation failed)
    func error() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }
    
    // MARK: - Contextual Feedback
    
    /// Button tap feedback
    func buttonTap() {
        medium()
    }
    
    /// Tab switched feedback
    func tabSwitch() {
        light()
    }
    
    /// Location selected on map
    func locationSelected() {
        medium()
    }
    
    /// Search completed
    func searchCompleted(success: Bool) {
        success ? self.success() : warning()
    }
    
    /// Message sent in chat
    func messageSent() {
        light()
    }
    
    /// Data refreshed
    func dataRefreshed() {
        light()
    }
}

// MARK: - View Extension for Easy Haptic Feedback

extension View {
    /// Adds haptic feedback to button tap
    func withHapticFeedback(_ type: HapticFeedbackType = .medium) -> some View {
        self.simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    switch type {
                    case .light:
                        HapticManager.shared.light()
                    case .medium:
                        HapticManager.shared.medium()
                    case .heavy:
                        HapticManager.shared.heavy()
                    case .selection:
                        HapticManager.shared.selectionChanged()
                    }
                }
        )
    }
}

enum HapticFeedbackType {
    case light
    case medium
    case heavy
    case selection
}

