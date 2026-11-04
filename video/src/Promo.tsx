import type React from "react";
import { AbsoluteFill, interpolate, Series, useCurrentFrame } from "remotion";
import { sceneComponents } from "./scenes";
import { scenes } from "./theme";

const Transition = ({ duration, children }: { duration: number; children: React.ReactNode }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 10, duration - 10, duration], [0, 1, 1, 0], { extrapolateRight: "clamp" });
  return <AbsoluteFill style={{ opacity }}>{children}</AbsoluteFill>;
};

export const Promo = () => (
  <AbsoluteFill style={{ background: "#0b0b0f" }}>
    <Series>
      {scenes.map(({ id, duration }) => {
        const Scene = sceneComponents[id];
        return (
          <Series.Sequence key={id} durationInFrames={duration}>
            <Transition duration={duration}>
              <Scene />
            </Transition>
          </Series.Sequence>
        );
      })}
    </Series>
  </AbsoluteFill>
);
