import type { CSSProperties, ReactNode } from "react";
import { AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { theme } from "./theme";

export const useSpring = (delay = 0, damping = 18) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return spring({ frame: frame - delay, fps, config: { damping, mass: 0.9 } });
};

export const Backdrop = ({ children, glow = theme.orange }: { children: ReactNode; glow?: string }) => {
  const frame = useCurrentFrame();
  const drift = interpolate(frame, [0, 300], [0, 60]);
  return (
    <AbsoluteFill style={{ background: theme.background, fontFamily: theme.font, color: theme.text, overflow: "hidden" }}>
      <div
        style={{
          position: "absolute",
          width: 1400,
          height: 1400,
          left: -300 + drift,
          top: -700,
          background: `radial-gradient(circle, ${glow}33 0%, transparent 60%)`,
        }}
      />
      {children}
    </AbsoluteFill>
  );
};

export const FadeUp = ({ children, delay = 0, style }: { children: ReactNode; delay?: number; style?: CSSProperties }) => {
  const progress = useSpring(delay);
  return (
    <div style={{ opacity: progress, transform: `translateY(${(1 - progress) * 40}px)`, ...style }}>{children}</div>
  );
};

export const Headline = ({ eyebrow, title, color = theme.orange, delay = 0 }: { eyebrow: string; title: ReactNode; color?: string; delay?: number }) => (
  <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
    <FadeUp delay={delay}>
      <div style={{ fontSize: 30, fontWeight: 600, color, letterSpacing: 1, textTransform: "uppercase" }}>{eyebrow}</div>
    </FadeUp>
    <FadeUp delay={delay + 6}>
      <div style={{ fontSize: 76, fontWeight: 800, lineHeight: 1.05, letterSpacing: -2 }}>{title}</div>
    </FadeUp>
  </div>
);

export const Screenshot = ({ src, delay = 0, zoom = [1, 1.08], origin = "50% 50%", width = 1100 }: { src: string; delay?: number; zoom?: [number, number]; origin?: string; width?: number }) => {
  const frame = useCurrentFrame();
  const enter = useSpring(delay, 20);
  const scale = interpolate(frame, [delay, delay + 150], zoom, { extrapolateRight: "clamp", extrapolateLeft: "clamp" });
  return (
    <div
      style={{
        width,
        borderRadius: 22,
        overflow: "hidden",
        boxShadow: "0 40px 120px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,255,255,0.08)",
        opacity: enter,
        transform: `translateY(${(1 - enter) * 80}px) scale(${0.94 + enter * 0.06})`,
      }}
    >
      <Img src={staticFile(src)} style={{ width: "100%", display: "block", transform: `scale(${scale})`, transformOrigin: origin }} />
    </div>
  );
};

export const Pill = ({ label, color, delay = 0 }: { label: string; color: string; delay?: number }) => {
  const progress = useSpring(delay, 14);
  return (
    <div
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 14,
        padding: "16px 28px",
        borderRadius: 999,
        background: `${color}22`,
        color,
        fontSize: 34,
        fontWeight: 700,
        transform: `scale(${progress})`,
        opacity: progress,
      }}
    >
      <div style={{ width: 16, height: 16, borderRadius: 8, background: color }} />
      {label}
    </div>
  );
};

export const AppIcon = ({ size = 180 }: { size?: number }) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: size * 0.23,
      background: `linear-gradient(180deg, ${theme.orange}, ${theme.pink})`,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      boxShadow: `0 30px 80px ${theme.pink}66`,
    }}
  >
    <svg width={size * 0.5} height={size * 0.5} viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round">
      <circle cx="6" cy="5" r="2.5" />
      <circle cx="18" cy="5" r="2.5" />
      <circle cx="12" cy="19" r="2.5" />
      <path d="M6 7.5v2a4 4 0 0 0 4 4h4a4 4 0 0 0 4-4v-2" />
      <path d="M12 13.5v3" />
    </svg>
  </div>
);
