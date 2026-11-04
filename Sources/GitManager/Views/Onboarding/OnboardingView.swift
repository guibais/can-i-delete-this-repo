import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case fullDisk
    case folders
    case git
    case backup

    var isLast: Bool { self == Self.allCases.last }
    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
}

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: OnboardingStep = .welcome
    @State private var forward = true
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                content
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            Divider()
            footer
        }
        .frame(width: 620, height: 520)
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: step)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: WelcomeStep()
        case .fullDisk: FullDiskStep()
        case .folders: FoldersStep()
        case .git: GitStep()
        case .backup: BackupStep()
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: item == step ? 18 : 7, height: 7)
                }
            }
            Spacer()
            if let previous = step.previous {
                Button(L("onboarding.back")) { move(to: previous, forward: false) }
            }
            Button(step.isLast ? L("onboarding.start") : L("onboarding.continue"), action: advance)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .controlSize(.large)
        .padding(20)
    }

    private func advance() {
        guard let next = step.next else {
            onFinish()
            dismiss()
            return
        }
        move(to: next, forward: true)
    }

    private func move(to target: OnboardingStep, forward isForward: Bool) {
        forward = isForward
        step = target
    }
}
