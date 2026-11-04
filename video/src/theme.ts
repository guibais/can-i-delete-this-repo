export const theme = {
  background: "#0b0b0f",
  surface: "#16161d",
  text: "#f5f5f7",
  muted: "#a1a1aa",
  orange: "#ff7a3d",
  pink: "#e0365c",
  green: "#30d158",
  red: "#ff453a",
  amber: "#ff9f0a",
  purple: "#bf5af2",
  blue: "#0a84ff",
  font: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Helvetica Neue', sans-serif",
} as const;

export const FPS = 30;

export type SceneConfig = {
  id: string;
  duration: number;
};

export const scenes: SceneConfig[] = [
  { id: "intro", duration: 90 },
  { id: "problem", duration: 120 },
  { id: "overview", duration: 150 },
  { id: "status", duration: 150 },
  { id: "detail", duration: 150 },
  { id: "clean", duration: 120 },
  { id: "vault", duration: 150 },
  { id: "migrate", duration: 120 },
  { id: "outro", duration: 120 },
];

export const totalDuration = scenes.reduce((sum, scene) => sum + scene.duration, 0);
