import { describe, expect, it } from "vitest";
import {
  PUBLIC_EVENTS_PATH,
  PUBLIC_HOME_PATH,
  publicEventPointsRacePath,
  publicEventStandingsPath,
} from "./public-routes";

describe("public routes", () => {
  it("builds canonical public navigation paths from one event slug", () => {
    expect(PUBLIC_HOME_PATH).toBe("/");
    expect(PUBLIC_EVENTS_PATH).toBe("/events");
    expect(publicEventStandingsPath("south-wind-6-copy")).toBe(
      "/events/south-wind-6-copy/standings",
    );
    expect(publicEventPointsRacePath("south-wind-6-copy")).toBe(
      "/events/south-wind-6-copy/points-race",
    );
  });
});
