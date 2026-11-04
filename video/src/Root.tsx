import { Composition } from "remotion";
import { Promo } from "./Promo";
import { FPS, totalDuration } from "./theme";

export const Root = () => (
  <Composition id="CanIDeleteThisRepoPromo" component={Promo} durationInFrames={totalDuration} fps={FPS} width={1920} height={1080} />
);
