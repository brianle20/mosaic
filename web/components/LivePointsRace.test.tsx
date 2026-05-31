import { act, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { captureAnalyticsEvent } from "../lib/analytics";
import { LivePointsRace } from "./LivePointsRace";
import type { PublicStandingsSnapshot } from "../lib/public-standings";

vi.mock("../lib/analytics", () => ({
  captureAnalyticsEvent: vi.fn(),
}));

function createSupabaseClient() {
  const callbacks: Array<(payload: { new?: Record<string, unknown> }) => void> = [];
  const subscribe = vi.fn(() => ({ unsubscribe: vi.fn() }));
  const on = vi.fn((_event, _filter, callback) => {
    callbacks.push(callback);
    return channel;
  });
  const channel = { on, subscribe };

  return {
    client: {
      channel: vi.fn(() => channel),
      removeChannel: vi.fn(),
    },
    callbacks,
    on,
    subscribe,
  };
}

function snapshot(points: number, updatedAt: string): PublicStandingsSnapshot {
  return {
    eventId: "event-1",
    eventTitle: "Mosaic May Tournament",
    leaderboard: [],
    bonusResults: [],
    pointsTimeline: [
      {
        handIndex: 1,
        handResultId: "hand-1",
        recordedAt: updatedAt,
        tableLabel: "Table 1",
        players: [
          {
            eventGuestId: "player-1",
            publicDisplayName: "Caren L.",
            pointsDelta: points,
            totalPoints: points,
            rank: 1,
          },
        ],
      },
    ],
    updatedAt,
  };
}

describe("LivePointsRace", () => {
  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
    vi.clearAllMocks();
  });

  it("tracks a public points race view without player data", () => {
    const realtime = createSupabaseClient();

    render(
      <LivePointsRace
        eventId="event-1"
        eventSlug="fv-mahjong-1"
        initialSnapshot={snapshot(100, "2026-05-24T12:00:00.000Z")}
        supabaseClient={realtime.client}
        fetchStandings={vi.fn()}
      />,
    );

    expect(captureAnalyticsEvent).toHaveBeenCalledWith("points_race_viewed", {
      event_slug: "fv-mahjong-1",
    });
  });

  it("subscribes to public standings snapshots and applies streamed point timelines", async () => {
    vi.useFakeTimers();
    const realtime = createSupabaseClient();
    const fetchStandings = vi.fn();

    render(
      <LivePointsRace
        eventId="event-1"
        initialSnapshot={snapshot(100, "2026-05-24T12:00:00.000Z")}
        supabaseClient={realtime.client}
        fetchStandings={fetchStandings}
      />,
    );

    expect(realtime.client.channel).toHaveBeenCalledWith("public-points-race:event-1");
    expect(realtime.on).toHaveBeenCalledWith(
      "postgres_changes",
      {
        event: "*",
        schema: "public",
        table: "public_event_standings_snapshots",
      },
      expect.any(Function),
    );
    expect(screen.getAllByText("+100")[0]).toBeVisible();

    await act(async () => {
      realtime.callbacks[0]({
        new: {
          event_id: "event-1",
          updated_at: "2026-05-24T12:01:00.000Z",
          payload: {
            eventTitle: "Mosaic May Tournament",
            leaderboard: [],
            bonusResults: [],
            pointsTimeline: [
              {
                handIndex: 1,
                handResultId: "hand-1",
                recordedAt: "2026-05-24T12:01:00.000Z",
                tableLabel: "Table 1",
                players: [
                  {
                    eventGuestId: "player-1",
                    publicDisplayName: "Caren L.",
                    pointsDelta: 260,
                    totalPoints: 260,
                    rank: 1,
                  },
                ],
              },
            ],
          },
        },
      });
      vi.advanceTimersByTime(250);
    });

    expect(fetchStandings).not.toHaveBeenCalled();
    expect(screen.getAllByText("+260")[0]).toBeVisible();
  });

  it("polls for fresh standings when realtime events do not arrive", async () => {
    vi.useFakeTimers();
    vi.spyOn(Math, "random").mockReturnValue(0);
    const realtime = createSupabaseClient();
    const fetchStandings = vi
      .fn()
      .mockResolvedValue(snapshot(340, "2026-05-24T12:01:00.000Z"));

    render(
      <LivePointsRace
        eventId="event-1"
        initialSnapshot={snapshot(100, "2026-05-24T12:00:00.000Z")}
        supabaseClient={realtime.client}
        fetchStandings={fetchStandings}
      />,
    );

    await act(async () => {
      vi.advanceTimersByTime(30_000);
      vi.advanceTimersByTime(250);
      await Promise.resolve();
    });

    expect(fetchStandings).toHaveBeenCalledTimes(1);
    expect(screen.getAllByText("+340")[0]).toBeVisible();
  });
});
