export type PublicLeaderboardRpcRow = {
  event_guest_id: string;
  public_display_name: string | null;
  total_points: number | null;
  hands_played: number | null;
  wins: number | null;
  self_draw_wins: number | null;
  discard_wins: number | null;
  rank: number | null;
  [key: string]: unknown;
};

export type PublicBonusResultRpcRow = {
  event_guest_id: string;
  public_display_name: string | null;
  result_label: string | null;
  placement: number | null;
  points_delta: number | null;
  [key: string]: unknown;
};

export type PublicEventSummaryRpcRow = {
  event_id: string;
  title: string | null;
  [key: string]: unknown;
};

export type PublicLeaderboardRow = {
  eventGuestId: string;
  publicDisplayName: string;
  totalPoints: number;
  handsPlayed: number;
  wins: number;
  selfDrawWins: number;
  discardWins: number;
  rank: number;
};

export type PublicBonusResult = {
  eventGuestId: string;
  publicDisplayName: string;
  resultLabel: string;
  placement: number | null;
  pointsDelta: number;
};

export type PublicStandingsSnapshot = {
  eventTitle: string;
  leaderboard: PublicLeaderboardRow[];
  bonusResults: PublicBonusResult[];
  updatedAt: string | null;
};

export type PublicStandingsRpcClient = {
  rpc: (
    fn:
      | "get_public_event_summary"
      | "get_public_event_leaderboard"
      | "get_public_event_bonus_results",
    args: { target_event_id: string },
  ) => PromiseLike<{ data: unknown[] | null; error: { message?: string } | null }>;
};

export function mapLeaderboardRow(row: PublicLeaderboardRpcRow): PublicLeaderboardRow {
  return {
    eventGuestId: row.event_guest_id,
    publicDisplayName: row.public_display_name?.trim() || "Player",
    totalPoints: Number(row.total_points ?? 0),
    handsPlayed: Number(row.hands_played ?? 0),
    wins: Number(row.wins ?? 0),
    selfDrawWins: Number(row.self_draw_wins ?? 0),
    discardWins: Number(row.discard_wins ?? 0),
    rank: Number(row.rank ?? 0),
  };
}

export function mapBonusResultRow(row: PublicBonusResultRpcRow): PublicBonusResult {
  return {
    eventGuestId: row.event_guest_id,
    publicDisplayName: row.public_display_name?.trim() || "Player",
    resultLabel: row.result_label?.trim() || "Finals result",
    placement: row.placement,
    pointsDelta: Number(row.points_delta ?? 0),
  };
}

export async function fetchPublicStandings(
  client: PublicStandingsRpcClient,
  eventId: string,
): Promise<PublicStandingsSnapshot> {
  const [summaryResult, leaderboardResult, bonusResult] = await Promise.all([
    Promise.resolve(client.rpc("get_public_event_summary", { target_event_id: eventId })),
    Promise.resolve(client.rpc("get_public_event_leaderboard", { target_event_id: eventId })),
    Promise.resolve(client.rpc("get_public_event_bonus_results", { target_event_id: eventId })),
  ]);

  if (summaryResult.error) {
    throw new Error(summaryResult.error.message ?? "Unable to load public event.");
  }

  if (leaderboardResult.error) {
    throw new Error(leaderboardResult.error.message ?? "Unable to load public standings.");
  }

  if (bonusResult.error) {
    throw new Error(bonusResult.error.message ?? "Unable to load public bonus results.");
  }

  const eventSummary = (summaryResult.data?.[0] ?? null) as PublicEventSummaryRpcRow | null;

  return {
    eventTitle: eventSummary?.title?.trim() || "Mosaic tournament",
    leaderboard: (leaderboardResult.data ?? []).map((row) =>
      mapLeaderboardRow(row as PublicLeaderboardRpcRow),
    ),
    bonusResults: (bonusResult.data ?? []).map((row) =>
      mapBonusResultRow(row as PublicBonusResultRpcRow),
    ),
    updatedAt: new Date().toISOString(),
  };
}
