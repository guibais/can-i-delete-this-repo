import SwiftUI

struct ActivityStack: View {
    @Environment(RepositoryStore.self) private var store

    var body: some View {
        VStack(spacing: 10) {
            ForEach(store.activities.suffix(3)) { activity in
                ActivityCard(activity: activity) { store.dismissActivity(activity.id) }
                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.94)))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: store.activities.map(\.id))
    }
}

struct ActivityCard: View {
    let activity: Activity
    let onDismiss: () -> Void

    private var tint: Color {
        activity.outcome.map { $0.isError ? Color.red : Color.green } ?? .accentColor
    }

    private var symbol: String {
        activity.outcome.map { $0.isError ? "xmark.circle.fill" : "checkmark.circle.fill" } ?? activity.symbol
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                icon
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.title)
                        .font(.headline)
                    Text(activity.outcome?.message ?? activity.detail)
                        .font(.caption)
                        .foregroundStyle(activity.outcome?.isError == true ? Color.red : Color.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .contentTransition(.interpolate)
                }
                Spacer(minLength: 8)
                trailing
            }
            if let freed = activity.freed {
                FreedCounter(bytes: freed, goal: activity.goal, isFinished: activity.isFinished)
            }
            progress
        }
        .padding(14)
        .frame(width: 400)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(tint.opacity(0.35)))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .animation(.smooth(duration: 0.35), value: activity)
    }

    private var icon: some View {
        Image(systemName: symbol)
            .font(.title2)
            .foregroundStyle(tint)
            .symbolRenderingMode(.hierarchical)
            .symbolEffect(.pulse, isActive: !activity.isFinished)
            .symbolEffect(.bounce, value: activity.isFinished)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 42, height: 42)
            .background(tint.opacity(0.14), in: Circle())
    }

    @ViewBuilder
    private var trailing: some View {
        if let counter = activity.counter {
            Text(counter)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        if activity.isFinished {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L("action.close"))
        }
    }

    @ViewBuilder
    private var progress: some View {
        if let value = activity.progress {
            ProgressView(value: value)
                .tint(tint)
        } else {
            ProgressView()
                .progressViewStyle(.linear)
                .tint(tint)
        }
    }
}

private struct FreedCounter: View {
    let bytes: Int64
    let goal: Int64?
    let isFinished: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
                .symbolEffect(.variableColor.iterative, isActive: !isFinished)
            CountingBytes(value: Double(bytes))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                .animation(.smooth(duration: 0.4), value: bytes)
            Text(goal.map { L("activity.freedOf", Format.bytes($0)) } ?? L("activity.freedLabel"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct CountingBytes: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(Format.bytes(Int64(max(value, 0))))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

private struct StatusOverlay: ViewModifier {
    @Environment(RepositoryStore.self) private var store

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    ActivityStack()
                    if let toast = store.toast {
                        ToastView(toast: toast)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 24)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.toast)
            .task(id: store.toast?.id) { await dismissToast() }
    }

    private func dismissToast() async {
        guard store.toast != nil else { return }
        try? await Task.sleep(for: .seconds(4))
        store.toast = nil
    }
}

extension View {
    func statusOverlay() -> some View {
        modifier(StatusOverlay())
    }
}
