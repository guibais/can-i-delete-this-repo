import SwiftUI

struct SavingsHero: View {
    @Environment(RepositoryStore.self) private var store
    @State private var displayed: Double = 0

    private static let equivalents: [(unit: Int64, key: String)] = [
        (4_000_000_000, "dashboard.equivalent.movies"),
        (5_000_000, "dashboard.equivalent.songs"),
        (3_000_000, "dashboard.equivalent.photos")
    ]

    private var freed: Int64 { store.savings.totalFreed }
    private var isFreeing: Bool { store.activities.contains { $0.freed != nil && !$0.isFinished } }

    private var ratio: Double {
        let footprint = Double(freed + store.totalSize)
        return footprint > 0 ? Double(freed) / footprint : 0
    }

    private var equivalent: String {
        guard freed > 0, let match = Self.equivalents.first(where: { freed >= $0.unit }) ?? Self.equivalents.last else {
            return L("dashboard.freed.empty")
        }
        return L(match.key, max(Int(freed / match.unit), 1))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
                Label(L("dashboard.freed.title"), systemImage: "leaf.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                CountingBytes(value: displayed)
                    .font(.system(size: 58, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                Text(equivalent)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                HStack(spacing: 10) {
                    HeroPill(symbol: "sparkles", text: L("dashboard.freed.cleanups", store.savings.count(.cleaned)))
                    HeroPill(symbol: "trash", text: L("dashboard.freed.removed", store.savings.count(.trashed)))
                }
            }
            Spacer(minLength: 0)
            SavingsRing(ratio: ratio, isActive: isFreeing)
                .frame(width: 150, height: 150)
        }
        .padding(28)
        .background {
            ZStack {
                LinearGradient(colors: [Color(red: 0.45, green: 0.2, blue: 0.95), .indigo, Color(red: 0.1, green: 0.45, blue: 0.95)], startPoint: .topLeading, endPoint: .bottomTrailing)
                SparkleField(isActive: isFreeing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .indigo.opacity(0.3), radius: 20, y: 10)
        .onAppear { withAnimation(.easeOut(duration: 1.8)) { displayed = Double(freed) } }
        .onChange(of: freed) { _, value in
            withAnimation(.smooth(duration: 0.5)) { displayed = Double(value) }
        }
    }
}

private struct HeroPill: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.18), in: Capsule())
    }
}

private struct SavingsRing: View {
    let ratio: Double
    let isActive: Bool
    @State private var animatedRatio: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 14)
            Circle()
                .trim(from: 0, to: animatedRatio)
                .stroke(
                    AngularGradient(colors: [.mint, .white, .mint], center: .center),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: .mint.opacity(0.6), radius: isActive ? 10 : 4)
            TimelineView(.animation(paused: !isActive || reduceMotion)) { context in
                Circle()
                    .trim(from: 0, to: 0.12)
                    .stroke(.white.opacity(isActive ? 0.9 : 0), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .padding(-12)
                    .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4 * 360))
            }
            VStack(spacing: 2) {
                Text(animatedRatio, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: animatedRatio))
                Text(L("dashboard.freed.ofFootprint"))
                    .font(.caption2.weight(.medium))
                    .multilineTextAlignment(.center)
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(18)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.6).delay(0.2)) { animatedRatio = ratio } }
        .onChange(of: ratio) { _, value in withAnimation(.smooth) { animatedRatio = value } }
    }
}

private struct SparkleField: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let particles: [(x: Double, speed: Double, offset: Double, size: Double)] = (0..<36).map { index in
        let seed = Double(index)
        return (
            x: (seed * 0.618).truncatingRemainder(dividingBy: 1),
            speed: 0.05 + (seed * 0.37).truncatingRemainder(dividingBy: 1) * 0.08,
            offset: (seed * 0.293).truncatingRemainder(dividingBy: 1),
            size: 2 + (seed * 0.71).truncatingRemainder(dividingBy: 1) * 5
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            Canvas { canvas, size in
                let time = context.date.timeIntervalSinceReferenceDate
                let boost = isActive ? 4.0 : 1.0
                for particle in Self.particles {
                    let progress = (time * particle.speed * boost + particle.offset).truncatingRemainder(dividingBy: 1)
                    let wobble = sin(time * 1.3 + particle.offset * 12) * 10
                    let point = CGPoint(x: particle.x * size.width + wobble, y: (1 - progress) * (size.height + 20) - 10)
                    let alpha = sin(progress * .pi) * (isActive ? 0.9 : 0.45)
                    canvas.opacity = alpha
                    canvas.fill(sparkle(at: point, radius: particle.size * (isActive ? 1.4 : 1)), with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func sparkle(at center: CGPoint, radius: Double) -> Path {
        Path { path in
            path.move(to: CGPoint(x: center.x, y: center.y - radius))
            path.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: center)
            path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: center)
            path.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: center)
            path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: center)
        }
    }
}
