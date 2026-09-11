import Core
import SwiftUI

/// The two screens that lead a diagnosis event toward `returned`: the further-level offer (diagnosis Q3,
/// "offered, never automatic") and the terminal line/hint/remediation (W5). Both reuse `RemediationView`; the
/// terminal never shows a `DoorAHintContent.internalCode` or a placeholder "no hint written" string
/// (arbiter-04-hint-fallback-reconciliation Rule 3, §3).
struct DiagnosisReturnView: View {
    enum Content: Equatable {
        case furtherLevelOffer(remediation: DoorARemediationContent, offer: DoorAFurtherLevelOfferContent)
        case terminal(DoorATerminalContent)
    }

    let content: Content
    let onFurtherLevelDecision: (Bool) -> Void
    let onReturn: () -> Void

    var body: some View {
        switch content {
        case .furtherLevelOffer(let remediation, let offer):
            VStack(spacing: 12) {
                RemediationView(content: remediation)
                Text(offer.question)
                Button("Yes") { onFurtherLevelDecision(true) }
                Button("Not now") { onFurtherLevelDecision(false) }
            }
            .padding()
        case .terminal(let terminal):
            VStack(spacing: 12) {
                if let line = terminal.line {
                    Text(line)
                }
                if let hint = terminal.hint {
                    Text(hint.prose)
                }
                if let remediation = terminal.remediation {
                    RemediationView(content: remediation)
                }
                Button("Continue") { onReturn() }
            }
            .padding()
        }
    }
}
