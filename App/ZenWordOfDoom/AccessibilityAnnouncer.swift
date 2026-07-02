import SwiftUI

/// Seam for VoiceOver announcements so the view model stays testable.
protocol AccessibilityAnnouncing {
    func announce(_ message: String)
}

/// Posts a real VoiceOver announcement (no-op when VoiceOver is off — the
/// notification is simply unheard).
struct SystemAnnouncer: AccessibilityAnnouncing {
    func announce(_ message: String) {
        var announcement = AttributedString(message)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }
}
