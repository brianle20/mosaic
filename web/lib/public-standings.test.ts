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
    expect(result.finalsLeaderboards).toEqual([]);
    expect(rpc).toHaveBeenCalledWith("get_public_event_summary", {
      target_event_id: "event-1",
    });
    expect(rpc).toHaveBeenCalledWith("get_public_event_leaderboard", {
      target_event_id: "event-1",
    });
    expect(rpc).toHaveBeenCalledWith("get_public_event_bonus_results", {
      target_event_id: "event-1",
    });
    expect(rpc).toHaveBeenCalledWith("get_public_event_finals_leaderboard", {
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
          finalsLeaderboards: [],
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
          finalsLeaderboards: [
            {
              tableRole: "table_of_champions",
              title: "Table of Champions",
              tableLabel: "Table 1",
              hasScores: true,
              rows: [
                {
                  eventGuestId: "guest-2",
                  publicDisplayName: "Brian L.",
                  seatIndex: 1,
                  totalPoints: 64,
                  handsPlayed: 2,
                  wins: 1,
                  rank: 1,
                },
              ],
            },
          ],
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
      finalsLeaderboards: [
        {
          tableRole: "table_of_champions",
          title: "Table of Champions",
          tableLabel: "Table 1",
          hasScores: true,
          rows: [
            {
              eventGuestId: "guest-2",
              publicDisplayName: "Brian L.",
              seatIndex: 1,
              totalPoints: 64,
              handsPlayed: 2,
              wins: 1,
              rank: 1,
            },
          ],
        },
      ],
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
          finalsLeaderboards: [
            {
              tableRole: "table_of_redemption",
              title: "  Table of Redemption  ",
              tableLabel: "  Table 2  ",
              rows: [
                {
                  eventGuestId: "guest-3",
                  publicDisplayName: "  Dana P.  ",
                  seatIndex: "2",
                  totalPoints: "-16",
                  handsPlayed: "3",
                  wins: "1",
                  rank: "2",
                },
              ],
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
      finalsLeaderboards: [
        {
          tableRole: "table_of_redemption",
          title: "Table of Redemption",
          tableLabel: "Table 2",
          hasScores: true,
          rows: [
            {
              eventGuestId: "guest-3",
              publicDisplayName: "Dana P.",
              seatIndex: 2,
              totalPoints: -16,
              handsPlayed: 3,
              wins: 1,
              rank: 2,
            },
          ],
        },
      ],
      updatedAt: "2026-05-24T12:02:00.000Z",
    });
  });

  it("groups public finals leaderboard RPC rows into finals tables", async () => {
    const rpc = vi
      .fn()
      .mockResolvedValueOnce({
        data: [{ event_id: "event-1", title: "Mosaic May Tournament" }],
        error: null,
      })
      .mockResolvedValueOnce({ data: [], error: null })
      .mockResolvedValueOnce({ data: [], error: null })
      .mockResolvedValueOnce({
        data: [
          {
            bonus_table_role: "table_of_champions",
            table_label: "Table 1",
            event_guest_id: "guest-1",
            public_display_name: "Alice C.",
            seat_index: 0,
            total_points: 128,
            hands_played: 3,
            wins: 2,
            rank: 1,
          },
          {
            bonus_table_role: "table_of_champions",
            table_label: "Table 1",
            event_guest_id: "guest-2",
            public_display_name: "Brian L.",
            seat_index: 1,
            total_points: 64,
            hands_played: 3,
            wins: 1,
            rank: 2,
          },
          {
            bonus_table_role: "table_of_redemption",
            table_label: "Table 2",
            event_guest_id: "guest-3",
            public_display_name: "Caren W.",
            seat_index: 0,
            total_points: 0,
            hands_played: 0,
            wins: 0,
            rank: 1,
          },
        ],
        error: null,
      });

    const result = await fetchPublicStandings({ rpc }, "event-1");

    expect(result.finalsLeaderboards).toEqual([
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
      {
        tableRole: "table_of_redemption",
        title: "Table of Redemption",
        tableLabel: "Table 2",
        hasScores: false,
        rows: [
          {
            eventGuestId: "guest-3",
            publicDisplayName: "Caren W.",
            seatIndex: 0,
            totalPoints: 0,
            handsPlayed: 0,
            wins: 0,
            rank: 1,
          },
        ],
      },
    ]);
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
