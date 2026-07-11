import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { PublicEventUnavailableError } from "../../../lib/public-standings";
import PointsRacePage from "./points-race/page";
import StandingsPage from "./standings/page";

const { notFound } = vi.hoisted(() => ({
  notFound: vi.fn(() => {
    throw new Error("NEXT_NOT_FOUND");
  }),
}));

vi.mock("next/navigation", () => ({ notFound }));
vi.mock("../../../lib/supabase", () => ({
  createPublicSupabaseClient: vi.fn(() => ({ rpc: vi.fn() })),
}));
vi.mock("../../../lib/public-standings", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../../../lib/public-standings")>();
  return { ...actual, fetchPublicStandings: vi.fn() };
});
vi.mock("../../../components/LiveStandings", () => ({
  LiveStandings: ({
    initialLoadFailed,
    initialSnapshot,
  }: {
    initialLoadFailed?: boolean;
    initialSnapshot: { eventTitle: string };
  }) => (
    <div
      data-testid="standings-live"
      data-event-title={initialSnapshot.eventTitle}
      data-initial-load-failed={initialLoadFailed}
    />
  ),
}));
vi.mock("../../../components/LivePointsRace", () => ({
  LivePointsRace: ({
    initialLoadFailed,
    initialSnapshot,
  }: {
    initialLoadFailed?: boolean;
    initialSnapshot: { eventTitle: string };
  }) => (
    <div
      data-testid="points-race-live"
      data-event-title={initialSnapshot.eventTitle}
      data-initial-load-failed={initialLoadFailed}
    />
  ),
}));

import { fetchPublicStandings } from "../../../lib/public-standings";

const mockedFetchPublicStandings = vi.mocked(fetchPublicStandings);
const params = Promise.resolve({ eventSlug: "south-wind-6-copy" });

describe("public event server pages", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it.each([
    ["Standings", StandingsPage],
    ["Points Race", PointsRacePage],
  ] as const)("routes an unavailable %s event through notFound", async (_label, Page) => {
    mockedFetchPublicStandings.mockRejectedValueOnce(new PublicEventUnavailableError());

    await expect(Page({ params })).rejects.toThrow("NEXT_NOT_FOUND");
    expect(notFound).toHaveBeenCalledTimes(1);
  });

  it.each([
    ["standings-live", StandingsPage],
    ["points-race-live", PointsRacePage],
  ] as const)("passes a controlled initial failure to %s", async (testId, Page) => {
    mockedFetchPublicStandings.mockRejectedValueOnce(
      new Error("private database detail"),
    );

    render(await Page({ params }));

    expect(screen.getByTestId(testId)).toHaveAttribute(
      "data-initial-load-failed",
      "true",
    );
    expect(screen.getByTestId(testId)).toHaveAttribute(
      "data-event-title",
      "South Wind 6 Copy",
    );
    expect(screen.queryByText("private database detail")).not.toBeInTheDocument();
  });
});
