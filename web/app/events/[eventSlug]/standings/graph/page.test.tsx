import { describe, expect, it, vi } from "vitest";

vi.mock("next/navigation", () => ({
  permanentRedirect: vi.fn(),
}));

import { permanentRedirect } from "next/navigation";
import LegacyPointsRacePage from "./page";

describe("legacy Points Race route", () => {
  it("permanently redirects the same event slug to the canonical sibling route", async () => {
    await LegacyPointsRacePage({
      params: Promise.resolve({ eventSlug: "south-wind-6-copy" }),
    });

    expect(permanentRedirect).toHaveBeenCalledWith(
      "/events/south-wind-6-copy/points-race",
    );
  });
});
