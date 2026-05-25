import { describe, expect, it, vi } from "vitest";
import {
  fetchPublicStandings,
  mapPublicStandingsSnapshotPayload,
  mapBonusResultRow,
  mapLeaderboardRow,
  type PublicLeaderboardRow,
} from "./public-standings";

describe("public standings data mapping", () => {
  it("maps public leaderboard RPC rows to UI rows", () => {
    const row = mapLeaderboardRow({
      event_guest_id: "guest-1",
      public_display_name: "Brian L.",
      total_points: 42500,
      hands_played: 8,
      wins: 3,
      self_draw_wins: 1,
      discard_wins: 2,
      discard_losses: 4,
      rank: 1,
    });

    expect(row).toEqual({
      eventGuestId: "guest-1",
      publicDisplayName: "Brian L.",
      totalPoints: 42500,
      handsPlayed: 8,
      wins: 3,
      selfDrawWins: 1,
      discardWins: 2,
      discardLosses: 4,
      rank: 1,
    });
  });

  it("keeps full names out of the public row type", () => {
    const row: PublicLeaderboardRow = mapLeaderboardRow({
      event_guest_id: "guest-2",
      public_display_name: "Alice C.",
      full_name: "Alice Chen",
      email: "alice@example.com",
      phone: "555-0100",
      qualification_points: 9000,
      payment_status: "paid",
      total_points: 12000,
      hands_played: 2,
      wins: 1,
      self_draw_wins: 0,
      discard_wins: 1,
      discard_losses: 0,
      rank: 2,
    });

    expect(row.publicDisplayName).toBe("Alice C.");
    expect(row).not.toHaveProperty("fullName");
    expect(row).not.toHaveProperty("email");
    expect(row).not.toHaveProperty("phone");
    expect(row).not.toHaveProperty("qualificationPoints");
    expect(row).not.toHaveProperty("paymentStatus");
  });

  it("returns empty lists for empty RPC results", async () => {
    const rpc = vi
      .fn()
      .mockResolvedValueOnce({
        data: [{ event_id: "event-1", title: "Mosaic May Tournament" }],
        error: null,
      })
      .mockResolvedValue({ data: [], error: null });

    const result = await fetchPublicStandings({ rpc }, "event-1");

    expect(result.eventTitle).toBe("Mosaic May Tournament");
    expect(result.leaderboard).toEqual([]);
    expect(result.bonusResults).toEqual([]);
    expect(rpc).toHaveBeenCalledWith("get_public_event_summary", {
      target_event_id: "event-1",
    });
    expect(rpc).toHaveBeenCalledWith("get_public_event_leaderboard", {
      target_event_id: "event-1",
    });
    expect(rpc).toHaveBeenCalledWith("get_public_event_bonus_results", {
      target_event_id: "event-1",
    });
  });

  it("loads public standings snapshots by event slug and exposes the resolved event id", async () => {
    const maybeSingle = vi.fn().mockResolvedValue({
      data: {
        event_id: "event-1",
        public_slug: "fv-mahjong-1",
        payload: {
          eventTitle: "FV Mahjong 1",
          leaderboard: [],
          bonusResults: [],
          updatedAt: "2026-05-24T12:01:00.000Z",
        },
        updated_at: "2026-05-24T12:01:01.000Z",
      },
      error: null,
    });
    const eq = vi.fn(() => ({ maybeSingle }));
    const select = vi.fn(() => ({ eq }));
    const from = vi.fn(() => ({ select }));
    const rpc = vi.fn();

    const result = await fetchPublicStandings({ from, rpc }, "fv-mahjong-1");

    expect(select).toHaveBeenCalledWith("event_id, public_slug, payload, updated_at");
    expect(eq).toHaveBeenCalledWith("public_slug", "fv-mahjong-1");
    expect(rpc).not.toHaveBeenCalled();
    expect(result.eventId).toBe("event-1");
    expect(result.eventSlug).toBe("fv-mahjong-1");
  });

  it("loads public standings from the cached snapshot before falling back to RPCs", async () => {
    const maybeSingle = vi.fn().mockResolvedValue({
      data: {
        event_id: "event-1",
        public_slug: "fv-mahjong-1",
        payload: {
          eventTitle: "FV Mahjong 1",
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
        },
        updated_at: "2026-05-24T12:01:01.000Z",
      },
      error: null,
    });
    const eq = vi.fn(() => ({ maybeSingle }));
    const select = vi.fn(() => ({ eq }));
    const from = vi.fn(() => ({ select }));
    const rpc = vi.fn();

    const result = await fetchPublicStandings({ from, rpc }, "event-1");

    expect(from).toHaveBeenCalledWith("public_event_standings_snapshots");
    expect(select).toHaveBeenCalledWith("event_id, public_slug, payload, updated_at");
    expect(eq).toHaveBeenCalledWith("event_id", "event-1");
    expect(rpc).not.toHaveBeenCalled();
    expect(result).toEqual({
      eventId: "event-1",
      eventSlug: "fv-mahjong-1",
      eventTitle: "FV Mahjong 1",
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
    });
  });

  it("maps public standings snapshot payloads defensively", () => {
    expect(
      mapPublicStandingsSnapshotPayload(
        {
          eventTitle: "  FV Mahjong 1  ",
          leaderboard: [
            {
              eventGuestId: "guest-1",
              publicDisplayName: "  Caren L.  ",
              totalPoints: "1024",
              handsPlayed: "15",
              wins: "7",
              selfDrawWins: "2",
              discardWins: "5",
              discardLosses: "0",
              rank: "1",
            },
          ],
          bonusResults: [
            {
              eventGuestId: "guest-2",
              publicDisplayName: "  CJ  ",
              resultLabel: "  Table of Champions  ",
              placement: "1",
              pointsDelta: "384",
            },
          ],
        },
        "2026-05-24T12:02:00.000Z",
      ),
    ).toEqual({
      eventTitle: "FV Mahjong 1",
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
      bonusResults: [
        {
          eventGuestId: "guest-2",
          publicDisplayName: "CJ",
          resultLabel: "Table of Champions",
          placement: 1,
          pointsDelta: 384,
        },
      ],
      updatedAt: "2026-05-24T12:02:00.000Z",
    });
  });

  it("maps public bonus result RPC rows", () => {
    expect(
      mapBonusResultRow({
        event_guest_id: "guest-3",
        public_display_name: "Cher",
        result_label: "Table of Champions",
        placement: 1,
        points_delta: 5000,
      }),
    ).toEqual({
      eventGuestId: "guest-3",
      publicDisplayName: "Cher",
      resultLabel: "Table of Champions",
      placement: 1,
      pointsDelta: 5000,
    });
  });
});
