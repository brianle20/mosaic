import { act, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { LiveStandings } from "./LiveStandings";
import type { PublicStandingsSnapshot } from "../lib/public-standings";

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

describe("LiveStandings", () => {
  it("subscribes to the public standings snapshot and applies streamed payloads without refetching", async () => {
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
    });

    expect(fetchStandings).not.toHaveBeenCalled();
    expect(screen.getByRole("heading", { name: "FV Mahjong 1" })).toBeVisible();
    expect(screen.getAllByText("Brian L.")[0]).toBeVisible();
  });

  it("ignores realtime payloads for other events when event_id is present", async () => {
    vi.useFakeTimers();
    const realtime = createSupabaseClient();
    const fetchStandings = vi.fn();

    render(
      <LiveStandings
        eventId="event-1"
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
    expect(screen.getAllByText("+384")).toHaveLength(2);

    await act(async () => {
      vi.advanceTimersByTime(2600);
    });

    expect(screen.queryByText("+384")).not.toBeInTheDocument();
    vi.useRealTimers();
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
