import type React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { AppIcon, Backdrop, FadeUp, Headline, Pill, Screenshot, useSpring } from "./components";
import { theme } from "./theme";

const split = { display: "flex", alignItems: "center", gap: 80, padding: "0 120px", height: "100%" } as const;

const Intro = () => {
  const pop = useSpring(0, 12);
  return (
    <Backdrop>
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 40 }}>
        <div style={{ transform: `scale(${pop})` }}>
          <AppIcon size={200} />
        </div>
        <FadeUp delay={10}>
          <div style={{ fontSize: 104, fontWeight: 800, letterSpacing: -3 }}>Can I Delete This Repo?</div>
        </FadeUp>
        <FadeUp delay={18}>
          <div style={{ fontSize: 40, color: theme.muted }}>Every repo on your Mac. One clear answer.</div>
        </FadeUp>
      </AbsoluteFill>
    </Backdrop>
  );
};

const Problem = () => {
  const frame = useCurrentFrame();
  const count = Math.round(interpolate(frame, [10, 70], [0, 75], { extrapolateRight: "clamp" }));
  return (
    <Backdrop glow={theme.red}>
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 30, textAlign: "center" }}>
        <FadeUp>
          <div style={{ fontSize: 220, fontWeight: 900, color: theme.orange, letterSpacing: -6 }}>{count}</div>
        </FadeUp>
        <FadeUp delay={8}>
          <div style={{ fontSize: 64, fontWeight: 800 }}>projects. 100 GB. Zero clarity.</div>
        </FadeUp>
        <FadeUp delay={30}>
          <div style={{ fontSize: 40, color: theme.muted, maxWidth: 1300 }}>
            Which ones are safely on GitHub? Which still hide unpushed work or a lonely .env?
          </div>
        </FadeUp>
      </AbsoluteFill>
    </Backdrop>
  );
};

const Overview = () => (
  <Backdrop>
    <div style={split}>
      <div style={{ width: 620 }}>
        <Headline eyebrow="Scan" title={<>Finds every repo. In seconds.</>} />
        <FadeUp delay={20} style={{ fontSize: 34, color: theme.muted, marginTop: 30, lineHeight: 1.4 }}>
          Size on disk, last commit and how much space you can reclaim, for each project.
        </FadeUp>
      </div>
      <Screenshot src="overview.png" delay={8} origin="20% 30%" />
    </div>
  </Backdrop>
);

const Status = () => (
  <Backdrop glow={theme.green}>
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 60 }}>
      <Headline eyebrow="The answer" title="So, can you delete it?" color={theme.green} />
      <div style={{ display: "flex", flexDirection: "column", gap: 28, alignItems: "flex-start" }}>
        <Pill label="Safe to remove · everything is in the cloud" color={theme.green} delay={20} />
        <Pill label="Needs attention · something would be lost" color={theme.amber} delay={35} />
        <Pill label="At risk · it only lives on this Mac" color={theme.red} delay={50} />
      </div>
    </AbsoluteFill>
  </Backdrop>
);

const Detail = () => (
  <Backdrop glow={theme.amber}>
    <div style={split}>
      <Screenshot src="detail.png" delay={4} zoom={[1, 1.35]} origin="85% 75%" />
      <div style={{ width: 620 }}>
        <Headline eyebrow="Details" title="Know exactly what's left." color={theme.amber} />
        <FadeUp delay={20} style={{ fontSize: 34, color: theme.muted, marginTop: 30, lineHeight: 1.4 }}>
          Uncommitted changes, unpushed commits on any branch, stashes and ignored secrets.
        </FadeUp>
      </div>
    </div>
  </Backdrop>
);

const Clean = () => {
  const frame = useCurrentFrame();
  const freed = interpolate(frame, [20, 90], [0, 73.2], { extrapolateRight: "clamp" }).toFixed(1);
  return (
    <Backdrop glow={theme.purple}>
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 30, textAlign: "center" }}>
        <Headline eyebrow="Clean" title="node_modules, builds, caches. Gone." color={theme.purple} />
        <FadeUp delay={14}>
          <div style={{ fontSize: 180, fontWeight: 900, color: theme.purple, letterSpacing: -4 }}>{freed} GB</div>
        </FadeUp>
        <FadeUp delay={24}>
          <div style={{ fontSize: 36, color: theme.muted }}>reclaimed with one click. Your source code stays untouched.</div>
        </FadeUp>
      </AbsoluteFill>
    </Backdrop>
  );
};

const Vault = () => {
  const lock = useSpring(30, 10);
  return (
    <Backdrop glow={theme.blue}>
      <div style={split}>
        <div style={{ width: 820 }}>
          <Headline eyebrow="Secrets Vault" title="Your .env files, encrypted in a private repo." color={theme.blue} />
          <FadeUp delay={24} style={{ fontSize: 34, color: theme.muted, marginTop: 30, lineHeight: 1.4 }}>
            AES-256 on your Mac before anything leaves. Back up one, many or all. Restore anytime. Free.
          </FadeUp>
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 18, fontFamily: "SF Mono, Menlo, monospace", fontSize: 30 }}>
          {[".env", ".env.local", "certs/server.pem", "GoogleService-Info.plist"].map((file, index) => (
            <FadeUp key={file} delay={10 + index * 6}>
              <div style={{ padding: "18px 28px", borderRadius: 16, background: theme.surface, display: "flex", gap: 20, alignItems: "center" }}>
                <span style={{ color: theme.amber }}>{file}</span>
                <span style={{ color: theme.muted }}>→</span>
                <span style={{ color: theme.blue, opacity: lock }}>{file}.enc</span>
              </div>
            </FadeUp>
          ))}
        </div>
      </div>
    </Backdrop>
  );
};

const Migrate = () => (
  <Backdrop glow={theme.green}>
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 40, textAlign: "center" }}>
      <Headline eyebrow="New Mac?" title="Clone & restore. Nothing left behind." color={theme.green} />
      <FadeUp delay={20}>
        <div style={{ fontSize: 36, color: theme.muted, maxWidth: 1300 }}>
          Every project comes back from Git, every secret comes back from your vault.
        </div>
      </FadeUp>
    </AbsoluteFill>
  </Backdrop>
);

const Outro = () => (
  <Backdrop>
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 36 }}>
      <AppIcon size={150} />
      <FadeUp delay={6}>
        <div style={{ fontSize: 86, fontWeight: 800, letterSpacing: -2 }}>Can I Delete This Repo?</div>
      </FadeUp>
      <FadeUp delay={14}>
        <div style={{ fontSize: 38, color: theme.muted }}>Free & open source · macOS 14+ · English & Português</div>
      </FadeUp>
      <FadeUp delay={24}>
        <div style={{ fontSize: 36, fontWeight: 700, color: theme.orange }}>github.com/guibais/can-i-delete-this-repo</div>
      </FadeUp>
    </AbsoluteFill>
  </Backdrop>
);

export const sceneComponents: Record<string, () => React.JSX.Element> = {
  intro: Intro,
  problem: Problem,
  overview: Overview,
  status: Status,
  detail: Detail,
  clean: Clean,
  vault: Vault,
  migrate: Migrate,
  outro: Outro,
};
