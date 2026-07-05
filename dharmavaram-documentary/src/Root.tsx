import "./index.css";
import { Composition } from "remotion";
import { MainVideo, totalFrames } from "./MainVideo";

const TOTAL = totalFrames();

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="MainVideo"
      component={MainVideo}
      durationInFrames={TOTAL}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
