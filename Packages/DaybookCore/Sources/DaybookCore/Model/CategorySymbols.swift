import Foundation

/// The SF Symbols offered for categories: plain, recognisable at caption size, and present on
/// iOS 26 and macOS 26. Other symbols (from another device) are still drawn.
public enum CategorySymbols {
    public static let fallback = "tag"

    public static let offered: [String] = [
        "person.2", "brain.head.profile", "figure.and.child.holdinghands", "airplane", "heart",
        "briefcase", "house", "book", "graduationcap", "dumbbell",
        "fork.knife", "cart", "car", "phone", "envelope",
        "laptopcomputer", "music.note", "gift", "star", "flag",
        "leaf", "pawprint", "stethoscope", "banknote", "hammer",
        "paintbrush", "camera", "gamecontroller", "sun.max", "tag"
    ]
}
