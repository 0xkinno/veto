import React from "react";
import { Composition } from "remotion";
import { VetoDemo, TOTAL_FRAMES } from "./VetoDemo";
import "./fonts.css";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="VetoDemo"
      component={VetoDemo}
      durationInFrames={TOTAL_FRAMES}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
