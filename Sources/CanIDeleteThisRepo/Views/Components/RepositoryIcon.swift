import SwiftUI

struct RepositoryIcon: View {
    let severity: Severity
    var size: CGFloat = 28

    var body: some View {
        let color = severity.style.color
        Image(systemName: "folder.fill")
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            )
            .shadow(color: color.opacity(0.3), radius: size * 0.1, y: size * 0.05)
    }
}
