import { act, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { captureAnalyticsEvent } from "../lib/analytics";
import { LiveStandings } from "./LiveStandings";
import type { PublicStandingsSnapshot } from "../lib/public-standings";

vi.mock("../lib/analytics", () => ({
  captureAnalyticsEvent: vi.fn(),
}));

vi.mock("next/navigation", () => ({
  useRouter: () => ({ refresh: vi.fn() }),
}));

function createSupabaseClient() {
  const callbacks: Array<(payload: { new?: Record<string, unknown> }) => void> = [];
  const statusCallbacks: Array<(status: string) => void> = [];
  const subscribe = vi.fn((callback?: (status: string) => void) => {
    if (callback) {
      statusCallbacks.push(callback);
    }
    return channel;
  });
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
    statusCallbacks,
    on,
    subscribe,
  };
}

describe("LiveStandings", () => {
  it("keeps a controlled initial-load failure inside the event shell", () => {
    const realtime = createSupabaseClient();

    render(
      <LiveStandings
        eventId="south-wind-6-copy"
        eventSlug="south-wind-6-copy"
        initialSnapshot={{
          eventTitle: "South Wind 6 Copy",
          leaderboard: [],
          bonusResults: [],
          pointsTimeline: [],
          updatedAt: null,
        }}
        initialLoadFailed
        supabaseClient={realtime.client}
        fetchStandings={vi.fn()}
      />,
    );

    expect(screen.getByRole("alert")).toHaveTextContent(
      "We couldn't load the latest public results.",
    );
    expect(screen.getByRole("heading", { name: "South Wind 6 Copy" })).toBeVisible();
    expect(screen.getByRole("link", { name: "Browse events" })).toHaveAttribute(
      "href",
      "/events",
    );
  });

  it("tracks a public standings view without player data", () => {
    const realtime = createSupabaseClient();

    render(
      <LiveStandings
        eventId="event-1"
        eventSlug="fv-mahjong-1"
        initialSnapshot={{
          eventTitle: "Mosaic May Tournament",
          leaderboard: [],
          bonusResults: [],
          updatedAt: null,
        }}
        supabaseClient={realtime.client}
        fetchStandings={vi.fn()}
      />,
    );

    expect(captureAnalyticsEvent).toHaveBeenCalledWith("public_standings_viewed", {
      event_slug: "fv-mahjong-1",
    });
    expect(screen.getByRole("link", { name: "Mosaic home" })).toHaveAttribute("href", "/");
    expect(screen.getByRole("link", { name: "All events" })).toHaveAttribute("href", "/events");
    expect(screen.getByRole("link", { name: "Standings" })).toHaveAttribute(
      "aria-current",
      "page",
    );
    expect(screen.getByRole("link", { name: "Points race" })).toHaveAttribute(
      "href",
      "/events/fv-mahjong-1/points-race",
    );
  });

  it("subscribes to the public standings snapshot and applies streamed payloads without refetching", async () => {
    vi.useFakeTimers();
    const realtime = createSupabaseClient();
    const initial: PublicStandingsSnapshot = {
      eventTitle: "Mosaic May Tournament",
      leaderboard: [],
      bonusResults: [],
      updatedAt: "2026-05-24T12:00:00.000Z",
    };
    const fetchStandings = vi.fn();

    render(
      <LiveStandings
        eventId="event-1"
        eventSlug="fv-mahjong-1"
        initialSnapshot={initial}
        supabaseClient={realtime.client}
        fetchStandings={fetchStandings}
      />,
    );

    expect(screen.getByRole("heading", { name: "Mosaic May Tournament" })).toBeVisible();
    expect(realtime.client.channel).toHaveBeenCalledWith("public-standings:event-1");
    expect(realtime.on).toHaveBeenCalledTimes(1);
    expect(realtime.on).toHaveBeenCalledWith(
      "postgres_changes",
      {
        event: "*",
        schema: "public",
        table: "public_event_standings_snapshots",
      },
      expect.any(Function),
    );

    await act(async () => {
      realtime.callbacks[0]({
        new: {
          event_id: "event-1",
          updated_at: "2026-05-24T12:01:00.000Z",
          payload: {
            eventTitle: "FV Mahjong 1",
            leaderboard: [
              {
                eventGuestId: "guest-1",
                publicDisplayName: "Brian L.",
                totalPoints: 1000,
                handsPlayed: 1,
                wins: 1,
                selfDrawWins: 0,
                discardWins: 1,
                discardLosses: 0,
                rank: 1,
              },
            ],
            bonusResults: [],
          },
        },
      });
      vi.advanceTimersByTime(250);
    });

    expect(fetchStandings).not.toHaveBeenCalled();
    expect(screen.getByRole("heading", { name: "FV Mahjong 1" })).toBeVisible();
    expect(screen.getByRole("time")).toHaveAttribute(
      "datetime",
      "2026-05-24T12:01:00.000Z",
    );
    expect(screen.getAllByText("Brian L.")[0]).toBeVisible();
    vi.useRealTimers();
  });

  it("ignores realtime payloads for other events when event_id is present", async () => {
    vi.useFakeTimers();
    const realtime = createSupabaseClient();
    const fetchStandings = vi.fn();

    render(
      <LiveStandings
        eventId="event-1"
        eventSlug="fv-mahjong-1"
        initialSnapshot={{
          eventTitle: "Mosaic May Tournament",
          leaderboard: [],
          bonusResults: [],
          updatedAt: null,
        }}
        supabaseClient={realtime.client}
        fetchStandings={fetchStandings}
      />,
    );

    await act(async () => {
      realtime.callbacks[0]({ new: { event_id: "event-2" } });
      vi.advanceTimersByTime(250);
    });

    expect(fetchStandings).not.toHaveBeenCalled();
    vi.useRealTimers();
  });

  it("auto-refreshes standings on an interval when realtime events do not arrive", async () => {
    vi.useFakeTimers();
    vi.spyOn(Math, "random").mockReturnValue(0);
    const realtime = createSupabaseClient();
    const initial: PublicStandingsSnapshot = {
      eventTitle: "Mosaic May Tournament",
      leaderboard: [],
      bonusResults: [],
      updatedAt: "2026-05-24T12:00:00.000Z",
    };
    const refreshed: PublicStandingsSnapshot = {
      eventTitle: "Mosaic May Tournament",
      leaderboard: [
        {
          eventGuestId: "guest-1",
          publicDisplayName: "Caren L.",
          totalPoints: 1024,
          handsPlayed: 15,
          wins: 7,
          selfDrawWins: 2,
          discardWins: 5,
          discardLosses: 0,
          rank: 1,
        },
      ],
      bonusResults: [],
      updatedAt: "2026-05-24T12:01:00.000Z",
    };
    const fetchStandings = vi.fn().mockResolvedValue(refreshed);

    render(
      <LiveStandings
        eventId="event-1"
        eventSlug="fv-mahjong-1"
        initialSnapshot={initial}
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
    expect(screen.getAllByText("Caren L.")[0]).toBeVisible();
    vi.mocked(Math.random).mockRestore();
    vi.useRealTimers();
  });

  it("keeps the latest standings visible when a refresh fails", async () => {
    vi.useFakeTimers();
    vi.spyOn(Math, "random").mockReturnValue(0);
    const realtime = createSupabaseClient();
    const fetchStandings = vi.fn().mockRejectedValue(new Error("network unavailable"));

    render(
      <LiveStandings
        eventId="event-1"
        eventSlug="fv-mahjong-1"
        initialSnapshot={{
          eventTitle: "Mosaic May Tournament",
          leaderboard: [
            {
              eventGuestId: "guest-1",
              publicDisplayName: "Caren L.",
              totalPoints: 1024,
              handsPlayed: 15,
              wins: 7,
              selfDrawWins: 2,
              discardWins: 5,
              discardLosses: 0,
              rank: 1,
            },
          ],
          bonusResults: [],
          updatedAt: "2026-05-24T12:00:00.000Z",
        }}
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
    expect(screen.getAllByText("Caren L.")[0]).toBeVisible();
    expect(screen.getAllByText("1,024")[0]).toBeVisible();
    expect(screen.getByText(/Live refresh could not update/)).toHaveTextContent(
      "Showing the latest standings we have.",
    );
    vi.mocked(Math.random).mockRestore();
    vi.useRealTimers();
  });

  it("keeps the latest standings visible when realtime subscription fails", async () => {
    const realtime = createSupabaseClient();

    render(
      <LiveStandings
        eventId="event-1"
        eventSlug="fv-mahjong-1"
        initialSnapshot={{
          eventTitle: "Mosaic May Tournament",
          leaderboard: [
            {
              eventGuestId: "guest-1",
              publicDisplayName: "Caren L.",
              totalPoints: 1024,
              handsPlayed: 15,
              wins: 7,
              selfDrawWins: 2,
              discardWins: 5,
              discardLosses: 0,
              rank: 1,
            },
          ],
          bonusResults: [],
          updatedAt: "2026-05-24T12:00:00.000Z",
        }}
        supabaseClient={realtime.client}
        fetchStandings={vi.fn()}
      />,
    );

    await act(async () => {
      realtime.statusCallbacks[0]("CHANNEL_ERROR");
    });

    expect(screen.getAllByText("Caren L.")[0]).toBeVisible();
    expect(screen.getAllByText("1,024")[0]).toBeVisible();
    expect(screen.getByText(/Live refresh could not update/)).toHaveTextContent(
      "Showing the latest standings we have.",
    );
  });

  it("shows a temporary points delta when streamed standings change", async () => {
    vi.useFakeTimers();
    const realtime = createSupabaseClient();
    const initial: PublicStandingsSnapshot = {
      eventTitle: "Mosaic May Tournament",
      leaderboard: [
        {
          eventGuestId: "guest-1",
          publicDisplayName: "Caren L.",
          totalPoints: 1024,
          handsPlayed: 15,
          wins: 7,
          selfDrawWins: 2,
          discardWins: 5,
          discardLosses: 0,
          rank: 1,
        },
      ],
      bonusResults: [],
      updatedAt: "2026-05-24T12:00:00.000Z",
    };
    const fetchStandings = vi.fn();

    render(
      <LiveStandings
        eventId="event-1"
        eventSlug="fv-mahjong-1"
        initialSnapshot={initial}
        supabaseClient={realtime.client}
        fetchStandings={fetchStandings}
      />,
    );

    await act(async () => {
      realtime.callbacks[0]({
        new: {
          event_id: "event-1",
          updated_at: "2026-05-24T12:01:00.000Z",
          payload: {
            eventTitle: "Mosaic May Tournament",
            leaderboard: [
              {
                eventGuestId: "guest-1",
                publicDisplayName: "Caren L.",
                totalPoints: 1408,
                handsPlayed: 16,
                wins: 8,
                selfDrawWins: 2,
                discardWins: 6,
                discardLosses: 0,
                rank: 1,
              },
            ],
            bonusResults: [],
          },
        },
      });
    });

    expect(fetchStandings).not.toHaveBeenCalled();
    expect(screen.queryByText("+384")).not.toBeInTheDocument();

    await act(async () => {
      vi.advanceTimersByTime(250);
    });

    expect(screen.getByText("+384")).toBeVisible();

    await act(async () => {
      vi.advanceTimersByTime(2600);
    });

    expect(screen.queryByText("+384")).not.toBeInTheDocument();
    vi.useRealTimers();
  });

  it("coalesces bursty streamed standings into one visible points change", async () => {
    vi.useFakeTimers();
    const realtime = createSupabaseClient();
    const initial: PublicStandingsSnapshot = {
      eventTitle: "Mosaic May Tournament",
      leaderboard: [
        {
          eventGuestId: "guest-1",
          publicDisplayName: "Caren L.",
          totalPoints: 1024,
          handsPlayed: 15,
          wins: 7,
          selfDrawWins: 2,
          discardWins: 5,
          discardLosses: 0,
          rank: 1,
        },
      ],
      bonusResults: [],
      updatedAt: "2026-05-24T12:00:00.000Z",
    };

    render(
      <LiveStandings
        eventId="event-1"
        eventSlug="fv-mahjong-1"
        initialSnapshot={initial}
        supabaseClient={realtime.client}
        fetchStandings={vi.fn()}
      />,
    );

    await act(async () => {
      realtime.callbacks[0]({
        new: {
          event_id: "event-1",
          updated_at: "2026-05-24T12:01:00.000Z",
          payload: {
            eventTitle: "Mosaic May Tournament",
            leaderboard: [
              {
                eventGuestId: "guest-1",
                publicDisplayName: "Caren L.",
                totalPoints: 1408,
                handsPlayed: 16,
                wins: 8,
                selfDrawWins: 2,
                discardWins: 6,
                discardLosses: 0,
                rank: 1,
              },
            ],
            bonusResults: [],
          },
        },
      });
      vi.advanceTimersByTime(100);
      realtime.callbacks[0]({
        new: {
          event_id: "event-1",
          updated_at: "2026-05-24T12:01:01.000Z",
          payload: {
            eventTitle: "Mosaic May Tournament",
            leaderboard: [
              {
                eventGuestId: "guest-1",
                publicDisplayName: "Caren L.",
                totalPoints: 1500,
                handsPlayed: 16,
                wins: 8,
                selfDrawWins: 2,
                discardWins: 6,
                discardLosses: 0,
                rank: 1,
              },
            ],
            bonusResults: [],
          },
        },
      });
      vi.advanceTimersByTime(250);
    });

    expect(screen.queryByText("+384")).not.toBeInTheDocument();
    expect(screen.getByText("+476")).toBeVisible();
    vi.useRealTimers();
  });

  it("renders finals leaderboards above tournament standings", () => {
    render(
      <LiveStandings
        eventId="event-1"
        eventSlug="fv-mahjong-1"
        initialSnapshot={{
          eventTitle: "Mosaic May Tournament",
          leaderboard: [
            {
              eventGuestId: "guest-3",
              publicDisplayName: "Caren W.",
              totalPoints: 400,
              handsPlayed: 5,
              wins: 2,
              selfDrawWins: 1,
              discardWins: 1,
              discardLosses: 0,
              rank: 1,
            },
          ],
          bonusResults: [],
          finalsLeaderboards: [
            {
              tableRole: "table_of_champions",
              title: "Table of Champions",
              tableLabel: "Table 1",
              hasScores: true,
              rows: [
                {
                  eventGuestId: "guest-1",
                  publicDisplayName: "Alice C.",
                  seatIndex: 0,
                  totalPoints: 128,
                  handsPlayed: 3,
                  wins: 2,
                  rank: 1,
                },
                {
                  eventGuestId: "guest-2",
                  publicDisplayName: "Brian L.",
                  seatIndex: 1,
                  totalPoints: 64,
                  handsPlayed: 3,
                  wins: 1,
                  rank: 2,
                },
              ],
            },
          ],
          updatedAt: "2026-05-24T12:00:00.000Z",
        }}
        supabaseClient={createSupabaseClient().client}
        fetchStandings={vi.fn()}
      />,
    );

    expect(screen.getByRole("heading", { name: "Finals Leaderboards" })).toBeVisible();
    expect(screen.getByRole("heading", { name: "Table of Champions" })).toBeVisible();
    expect(screen.getByText("Table 1")).toBeVisible();
    expect(screen.getByText("Alice C.")).toBeVisible();
    expect(screen.getByText("+128")).toBeVisible();
    expect(screen.getByText("3 hands · 2 wins")).toBeVisible();
  });

  it("resets visible standings and ignores stale refreshes when event changes", async () => {
    vi.useFakeTimers();
    vi.spyOn(Math, "random").mockReturnValue(0);
    const realtime = createSupabaseClient();
    let resolveFirstRefresh:
      | ((snapshot: PublicStandingsSnapshot) => void)
      | undefined;
    const firstRefresh = new Promise<PublicStandingsSnapshot>((resolve) => {
      resolveFirstRefresh = resolve;
    });
    const fetchStandings = vi.fn().mockReturnValueOnce(firstRefresh);

    const { rerender } = render(
      <LiveStandings
        eventId="event-1"
        eventSlug="fv-mahjong-1"
        initialSnapshot={{
          eventTitle: "Mosaic May Tournament",
          leaderboard: [
            {
              eventGuestId: "guest-1",
              publicDisplayName: "Brian L.",
              totalPoints: 1000,
              handsPlayed: 1,
              wins: 1,
                selfDrawWins: 0,
                discardWins: 1,
                discardLosses: 0,
                rank: 1,
            },
          ],
          bonusResults: [],
          updatedAt: "2026-05-24T12:00:00.000Z",
        }}
        supabaseClient={realtime.client}
        fetchStandings={fetchStandings}
      />,
    );

    await act(async () => {
      vi.advanceTimersByTime(30_000);
      vi.advanceTimersByTime(250);
      await Promise.resolve();
    });

    await act(async () => {
      rerender(
        <LiveStandings
          eventId="event-2"
          eventSlug="fv-mahjong-2"
        initialSnapshot={{
          eventTitle: "Mosaic June Tournament",
          leaderboard: [
              {
                eventGuestId: "guest-2",
                publicDisplayName: "Alice C.",
                totalPoints: 2000,
                handsPlayed: 2,
                wins: 2,
                selfDrawWins: 1,
                discardWins: 1,
                discardLosses: 0,
                rank: 1,
              },
            ],
            bonusResults: [],
            updatedAt: "2026-05-24T12:02:00.000Z",
          }}
          supabaseClient={realtime.client}
          fetchStandings={fetchStandings}
        />,
      );
    });

    expect(screen.queryByText("Brian L.")).not.toBeInTheDocument();
    expect(screen.getAllByText("Alice C.")[0]).toBeVisible();

    await act(async () => {
      resolveFirstRefresh?.({
        eventTitle: "Mosaic May Tournament",
        leaderboard: [
          {
            eventGuestId: "guest-3",
            publicDisplayName: "Stale Player",
            totalPoints: 9999,
            handsPlayed: 9,
            wins: 9,
            selfDrawWins: 0,
            discardWins: 9,
            discardLosses: 0,
            rank: 1,
          },
        ],
        bonusResults: [],
        updatedAt: "2026-05-24T12:03:00.000Z",
      });
      await firstRefresh;
    });

    expect(screen.queryByText("Stale Player")).not.toBeInTheDocument();
    expect(screen.getAllByText("Alice C.")[0]).toBeVisible();
    vi.mocked(Math.random).mockRestore();
    vi.useRealTimers();
  });
});
