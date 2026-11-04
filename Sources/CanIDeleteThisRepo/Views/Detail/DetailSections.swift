import SwiftUI

struct IssuesSection: View {
    let issues: [RepoIssue]

    var body: some View {
        SectionCard(title: L("section.issues"), symbol: "exclamationmark.bubble") {
            ForEach(issues) { issue in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: issue.kind.symbol)
                        .foregroundStyle(issue.kind.severity.style.color)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L(issue.kind.titleKey, issue.count)).fontWeight(.medium)
                        Text(L(issue.kind.detailKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

struct RemotesSection: View {
    let remotes: [GitRemote]

    var body: some View {
        SectionCard(title: L("section.remotes"), symbol: "icloud") {
            if remotes.isEmpty {
                EmptyHint(text: L("section.remotes.empty"))
            }
            ForEach(remotes) { remote in
                HStack(spacing: 10) {
                    Text(remote.name)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
                    Text(remote.url)
                        .font(.callout.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

struct SecretsSection: View {
    @Environment(RepositoryStore.self) private var store
    let repository: Repository

    var body: some View {
        SectionCard(title: L("section.secrets"), symbol: "key") {
            HStack(spacing: 6) {
                if store.isVaultReady && !repository.restorableSecrets.isEmpty {
                    Button(L("vault.action.restore")) { Task { await store.restoreFromVault([repository]) } }
                }
                Button(L("action.backup")) { store.requestBackup([repository]) }
                    .disabled(repository.sensitiveFiles.isEmpty)
            }
            .controlSize(.small)
        } content: {
            if !repository.hasSecrets {
                EmptyHint(text: L("section.secrets.empty"))
            }
            ForEach(repository.secretItems) { item in
                SecretRow(item: item)
            }
        }
    }
}

private struct SecretRow: View {
    let item: SecretItem

    private static let styles: [SecretSyncState: (symbol: String, color: Color)] = [
        .synced: ("checkmark.icloud", .green),
        .notBackedUp: ("exclamationmark.icloud", .orange),
        .localNewer: ("arrow.up.circle", .orange),
        .vaultNewer: ("arrow.down.circle", .blue),
        .missingLocally: ("icloud.and.arrow.down", .blue)
    ]

    var body: some View {
        let style = Self.styles[item.state] ?? ("questionmark.circle", .secondary)
        HStack(spacing: 10) {
            Image(systemName: "doc.badge.ellipsis")
                .foregroundStyle(.yellow)
            Text(item.relativePath)
                .font(.callout.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let encrypted = item.encrypted {
                Image(systemName: encrypted ? "lock.fill" : "lock.open")
                    .font(.caption)
                    .foregroundStyle(encrypted ? Color.secondary : Color.orange)
                    .help(L(encrypted ? "vault.mode.encrypted" : "vault.mode.plain"))
            }
            Label(L("secret.state.\(item.state.rawValue)"), systemImage: style.symbol)
                .font(.caption)
                .foregroundStyle(style.color)
        }
    }
}

struct CleanableSection: View {
    let repository: Repository
    let onClean: () -> Void

    private var maxSize: Int64 { repository.cleanables.first?.size ?? 1 }

    var body: some View {
        SectionCard(title: L("section.cleanable"), symbol: "shippingbox") {
            Button(L("action.clean"), action: onClean)
                .controlSize(.small)
                .disabled(repository.cleanables.isEmpty)
        } content: {
            if repository.cleanables.isEmpty {
                EmptyHint(text: L("section.cleanable.empty"))
            }
            ForEach(repository.cleanables) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.relativePath)
                            .font(.callout.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(Format.bytes(item.size))
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(item.size), total: Double(max(maxSize, 1)))
                        .tint(.purple)
                        .controlSize(.small)
                }
            }
        }
    }
}

struct DangerSection: View {
    let onTrash: () -> Void

    var body: some View {
        SectionCard(title: L("section.danger"), symbol: "trash") {
            HStack {
                EmptyHint(text: L("section.danger.message"))
                Spacer()
                Button(role: .destructive, action: onTrash) {
                    Label(L("action.trash"), systemImage: "trash")
                }
            }
        }
    }
}
