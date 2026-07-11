import { fireEvent, render, screen, within } from "@testing-library/react";
import { renderToString } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import { captureAnalyticsEvent } from "../lib/analytics";
import { PointsRaceChart, type PointsTimelineHand } from "./PointsRaceChart";

vi.mock("../lib/analytics", () => ({
  captureAnalyticsEvent: vi.fn(),
}));

const originalMatchMedia = window.matchMedia;

function createTimeline(playerCount: number, handCount = 3): PointsTimelineHand[] {
  return Array.from({ length: handCount }, (_, handIndex) => ({
    handNumber: handIndex + 1,
    players: Array.from({ length: playerCount }, (__, playerIndex) => {
      const rank = playerIndex + 1;
      return {
        eventGuestId: `player-${rank}`,
        publicDisplayName: `Player ${rank}`,
        totalPoints: (playerCount - playerIndex) * 100 + handIndex * (rank % 3 === 0 ? -20 : 30),
        rank,
      };
    }),
  }));
}

function mockMatchMedia(matches: boolean) {
  const listeners = new Set<(event: MediaQueryListEvent) => void>();

  Object.defineProperty(window, "matchMedia", {
    configurable: true,
    writable: true,
    value: vi.fn().mockImplementation((query: string) => ({
      matches,
      media: query,
      onchange: null,
      addEventListener: vi.fn((_event: string, listener) => {
        listeners.add(listener);
      }),
      removeEventListener: vi.fn((_event: string, listener) => {
        listeners.delete(listener);
      }),
      addListener: vi.fn(),
      removeListener: vi.fn(),
      dispatchEvent: vi.fn(),
    })),
  });
}

function axisLabels(container: HTMLElement) {
  return Array.from(container.querySelectorAll(".points-race-axis-label")).map(
    (label) => label.textContent ?? "",
  );
}

describe("PointsRaceChart", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.clearAllMocks();
    Object.defineProperty(window, "matchMedia", {
      configurable: true,
      writable: true,
      value: originalMatchMedia,
    });
  });

  it("shows a graceful empty state when no timeline hands are recorded", () => {
    render(
      <PointsRaceChart eventTitle="Mosaic May Tournament" pointsTimeline={[]} />,
    );

    expect(screen.getByText(/points race will appear once scored hands arrive/i)).toBeVisible();
    expect(screen.queryByRole("heading", { level: 1 })).not.toBeInTheDocument();
    const stats = screen.getByLabelText(/points race stats/i);
    expect(within(stats).getByText(/hands recorded/i)).toBeVisible();
    expect(within(stats).getAllByText("0")).toHaveLength(2);
  });

  it("shows the top 12 players by default and can reveal everyone", () => {
    render(
      <PointsRaceChart
        eventTitle="Mosaic May Tournament"
        eventSlug="mosaic-may-tournament"
        pointsTimeline={createTimeline(14)}
      />,
    );

    const legend = screen.getByRole("list", { name: /players/i });
    expect(within(legend).getByText("Player 1")).toBeVisible();
    expect(within(legend).getByText("Player 12")).toBeVisible();
    expect(within(legend).queryByText("Player 13")).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: /show everyone/i })).toBeVisible();

    fireEvent.click(screen.getByRole("button", { name: /show everyone/i }));

    expect(within(legend).getByText("Player 13")).toBeVisible();
    expect(within(legend).getByText("Player 14")).toBeVisible();
    expect(screen.getByRole("button", { name: /show top players/i })).toBeVisible();
    expect(captureAnalyticsEvent).toHaveBeenCalledWith(
      "points_race_show_everyone_clicked",
      {
        event_slug: "mosaic-may-tournament",
        visible_players: 14,
      },
    );
  });

  it("shows the top 8 players by default on mobile", () => {
    mockMatchMedia(true);

    render(
      <PointsRaceChart
        eventTitle="Mosaic May Tournament"
        pointsTimeline={createTimeline(10)}
      />,
    );

    const legend = screen.getByRole("list", { name: /players/i });
    expect(window.matchMedia).toHaveBeenCalledWith("(max-width: 680px)");
    expect(within(legend).getByText("Player 8")).toBeVisible();
    expect(within(legend).queryByText("Player 9")).not.toBeInTheDocument();
  });

  it("scales the default chart to visible players instead of hidden outliers", () => {
    const pointsTimeline: PointsTimelineHand[] = [
      {
        handNumber: 1,
        players: Array.from({ length: 13 }, (_, index) => {
          const rank = index + 1;
          return {
            eventGuestId: `player-${rank}`,
            publicDisplayName: `Player ${rank}`,
            totalPoints: rank === 13 ? -2_000 : 1_300 - rank * 50,
            rank,
          };
        }),
      },
    ];

    const { container } = render(
      <PointsRaceChart
        eventTitle="Mosaic May Tournament"
        pointsTimeline={pointsTimeline}
      />,
    );

    const legend = screen.getByRole("list", { name: /players/i });
    expect(within(legend).queryByText("Player 13")).not.toBeInTheDocument();
    expect(axisLabels(container).join(" ")).not.toMatch(/-2,?\d{3}/);
  });

  it("does not server-render a desktop-limited chart before viewport is known", () => {
    const html = renderToString(
      <PointsRaceChart
        eventTitle="Mosaic May Tournament"
        pointsTimeline={createTimeline(14)}
      />,
    );

    expect(html).toContain("Preparing points race");
    expect(html).not.toContain("<h1");
    expect(html).not.toContain("Player 12");
  });

  it("labels the chart with a richer accessible title and data summary", () => {
    render(
      <PointsRaceChart
        eventTitle="Mosaic May Tournament"
        pointsTimeline={createTimeline(2, 2)}
      />,
    );

    expect(
      screen.getByRole("img", {
        name: /points race for mosaic may tournament across 2 recorded hands/i,
      }),
    ).toBeVisible();

    const summary = screen.getByRole("table", { name: /points race data summary/i });
    expect(within(summary).getByRole("columnheader", { name: /player/i })).toBeVisible();
    expect(within(summary).getByRole("columnheader", { name: /hand 1/i })).toBeVisible();
    expect(within(summary).getByRole("row", { name: /player 1/i })).toHaveTextContent(
      /230/,
    );
  });

  it("renders a stable chart for a single hand with negative-only scores", () => {
    const { container } = render(
      <PointsRaceChart
        eventTitle="Mosaic May Tournament"
        pointsTimeline={[
          {
            handNumber: 1,
            players: [
              {
                eventGuestId: "player-1",
                publicDisplayName: "Negative Leader",
                totalPoints: -100,
                rank: 1,
              },
              {
                eventGuestId: "player-2",
                publicDisplayName: "Deeper Negative",
                totalPoints: -900,
                rank: 2,
              },
            ],
          },
        ]}
      />,
    );

    const leaderStat = screen.getByText("Leader").closest(".points-race-stat");
    expect(leaderStat).toHaveTextContent("Negative Leader");
    expect(leaderStat).toHaveTextContent("-100");
    expect(container.querySelector('[data-player-id="player-1"]')).toHaveAttribute(
      "d",
      expect.not.stringMatching(/NaN|Infinity/),
    );
  });

  it("spotlights a clicked player and dims the rest", () => {
    const { container } = render(
      <PointsRaceChart
        eventTitle="Mosaic May Tournament"
        pointsTimeline={createTimeline(5)}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: /spotlight player 3/i }));

    expect(screen.getByRole("button", { name: /clear player 3 spotlight/i })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    expect(container.querySelector('[data-player-id="player-3"]')).toHaveClass(
      "is-spotlighted",
    );
    expect(container.querySelector('[data-player-id="player-1"]')).toHaveClass("is-dimmed");
  });

  it("does not keep a spotlighted lower revealed player muted", () => {
    render(
      <PointsRaceChart
        eventTitle="Mosaic May Tournament"
        pointsTimeline={createTimeline(14)}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: /show everyone/i }));
    const lowerPlayer = screen.getByRole("button", { name: /spotlight player 13/i });
    expect(lowerPlayer).toHaveClass("is-muted-chip");

    fireEvent.click(lowerPlayer);

    expect(screen.getByRole("button", { name: /clear player 13 spotlight/i })).not.toHaveClass(
      "is-muted-chip",
    );
  });
});
