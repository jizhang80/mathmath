import Core
import SwiftUI

/// The `PLATFORM_SNAPSHOT_REFUSED` screen (`LaunchOutcome.refused`). `refusal.internalCode`/`refusal.report`
/// are never read here — internal codes never reach a student surface (`contracts/error-codes.md` § Rules).
struct RefusalView: View {
    let refusal: BundleRefusal

    var body: some View {
        VStack(spacing: 12) {
            Text(CoreErrorText.text(for: refusal.studentCode) ?? "")
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
