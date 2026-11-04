import SwiftUI

struct CommitSheet: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let repository: Repository
    @State private var message = ""

    private var trimmed: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("commit.title"), systemImage: "checkmark.circle.fill")
                .font(.title3.weight(.semibold))
            Text(L("commit.files", repository.snapshot.changes))
                .foregroundStyle(.secondary)
            TextField(L("commit.placeholder"), text: $message, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(L("action.cancel"), role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L("action.commit")) {
                    let text = trimmed
                    dismiss()
                    Task { await store.commitAndPush(repository, message: text) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(trimmed.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}
