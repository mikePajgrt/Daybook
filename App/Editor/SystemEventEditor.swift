#if os(iOS)
import EventKit
import EventKitUI
import SwiftUI

/// The system event in the system editor, the one public way to invite people (iOS and iPadOS).
struct InviteRequest: Identifiable {
    let id = UUID()
    let store: EKEventStore
    let event: EKEvent
}

/// `EKEventEditViewController` for SwiftUI. Saving and invitations happen inside it;
/// `onFinish` runs when it closes, however it closed.
struct SystemEventEditor: UIViewControllerRepresentable {
    let store: EKEventStore
    let event: EKEvent
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            onFinish()
        }
    }
}
#endif
