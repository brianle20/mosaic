export type PublicLeaderboardRpcRow = {
  event_guest_id: string;
  public_display_name: string | null;
  total_points: number | null;
  hands_played: number | null;
  wins: number | null;
  self_draw_wins: number | null;
  discard_wins: number | null;
  discard_losses: number | null;
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
  public_slug?: string | null;
  title: string | null;
  [key: string]: unknown;
};

export type PublicEventResolutionRpcRow = {
  event_id: string;
  public_slug: string;
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
  discardLosses: number;
  rank: number;
};

export type PublicPrizePlacementRow = {
  row: PublicLeaderboardRow;
  placement: number;
};

export type PublicBonusResult = {
  eventGuestId: string;
  publicDisplayName: string;
  resultLabel: string;
  placement: number | null;
  pointsDelta: number;
};

export type PublicStandingsSnapshot = {
  eventId?: string;
  eventSlug?: string | null;
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
      | "get_public_event_bonus_results"
      | "resolve_public_event_id",
    args: { target_event_id: string } | { target_public_slug: string },
  ) => PromiseLike<{ data: unknown[] | null; error: { message?: string } | null }>;
};

export type PublicStandingsSnapshotRow = {
  event_id?: string;
  public_slug?: string | null;
  payload: unknown;
  updated_at: string | null;
};

export type PublicStandingsSnapshotClient = {
  from: (table: "public_event_standings_snapshots") => {
    select: (columns: "event_id, public_slug, payload, updated_at") => {
      eq: (column: "event_id" | "public_slug", value: string) => {
        maybeSingle: () => PromiseLike<{
          data: PublicStandingsSnapshotRow | null;
          error: { message?: string } | null;
        }>;
      };
    };
  };
};

export type PublicStandingsClient = PublicStandingsRpcClient &
  Partial<PublicStandingsSnapshotClient>;

export function mapLeaderboardRow(row: PublicLeaderboardRpcRow): PublicLeaderboardRow {
  return {
    eventGuestId: row.event_guest_id,
    publicDisplayName: row.public_display_name?.trim() || "Player",
    totalPoints: Number(row.total_points ?? 0),
    handsPlayed: Number(row.hands_played ?? 0),
    wins: Number(row.wins ?? 0),
    selfDrawWins: Number(row.self_draw_wins ?? 0),
    discardWins: Number(row.discard_wins ?? 0),
    discardLosses: Number(row.discard_losses ?? 0),
    rank: Number(row.rank ?? 0),
  };
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === "object"
    ? (value as Record<string, unknown>)
    : null;
}

function readString(value: unknown, fallback: string): string {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : fallback;
}

function readNumber(value: unknown, fallback = 0): number {
  const numericValue = Number(value ?? fallback);
  return Number.isFinite(numericValue) ? numericValue : fallback;
}

function readNullableNumber(value: unknown): number | null {
  if (value === null || value === undefined) {
    return null;
  }

  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : null;
}

function mapSnapshotLeaderboardRow(row: unknown): PublicLeaderboardRow {
  const record = asRecord(row) ?? {};

  return {
    eventGuestId: readString(record.eventGuestId, ""),
    publicDisplayName: readString(record.publicDisplayName, "Player"),
    totalPoints: readNumber(record.totalPoints),
    handsPlayed: readNumber(record.handsPlayed),
    wins: readNumber(record.wins),
    selfDrawWins: readNumber(record.selfDrawWins),
    discardWins: readNumber(record.discardWins),
    discardLosses: readNumber(record.discardLosses),
    rank: readNumber(record.rank),
  };
}

function mapSnapshotBonusResult(row: unknown): PublicBonusResult {
  const record = asRecord(row) ?? {};

  return {
    eventGuestId: readString(record.eventGuestId, ""),
    publicDisplayName: readString(record.publicDisplayName, "Player"),
    resultLabel: readString(record.resultLabel, "Finals result"),
    placement: readNullableNumber(record.placement),
    pointsDelta: readNumber(record.pointsDelta),
  };
}

export function mapPublicStandingsSnapshotPayload(
  payload: unknown,
  updatedAt: string | null,
  eventId?: string,
  eventSlug?: string | null,
): PublicStandingsSnapshot {
  const record = asRecord(payload) ?? {};
  const leaderboard = Array.isArray(record.leaderboard) ? record.leaderboard : [];
  const bonusResults = Array.isArray(record.bonusResults) ? record.bonusResults : [];
  const payloadUpdatedAt =
    typeof record.updatedAt === "string" && record.updatedAt.trim().length > 0
      ? record.updatedAt
      : null;

  const snapshot: PublicStandingsSnapshot = {
    eventTitle: readString(record.eventTitle, "Mosaic tournament"),
    leaderboard: leaderboard.map(mapSnapshotLeaderboardRow),
    bonusResults: bonusResults.map(mapSnapshotBonusResult),
    updatedAt: payloadUpdatedAt ?? updatedAt,
  };

  if (eventId) {
    snapshot.eventId = eventId;
  }

  if (eventSlug !== undefined) {
    snapshot.eventSlug = eventSlug;
  }

  return snapshot;
}

export function getMinimumHandsForPrize(rows: PublicLeaderboardRow[]): number {
  const scoredHands = rows
    .map((row) => row.handsPlayed)
    .filter((handsPlayed) => handsPlayed > 0)
    .sort((a, b) => a - b);

  if (scoredHands.length === 0) {
    return 0;
  }

  const midpoint = Math.floor(scoredHands.length / 2);
  const medianHands =
    scoredHands.length % 2 === 1
      ? scoredHands[midpoint]
      : (scoredHands[midpoint - 1] + scoredHands[midpoint]) / 2;
  return Math.max(1, Math.ceil(medianHands * 0.5));
}

export function getPrizeEligibleRows(rows: PublicLeaderboardRow[]): PublicLeaderboardRow[] {
  const minimumHands = getMinimumHandsForPrize(rows);
  if (minimumHands <= 0) {
    return [];
  }

  return rows.filter((row) => row.handsPlayed >= minimumHands);
}

export function getNotPrizeEligibleRows(rows: PublicLeaderboardRow[]): PublicLeaderboardRow[] {
  const minimumHands = getMinimumHandsForPrize(rows);
  if (minimumHands <= 0) {
    return [];
  }

  return rows.filter((row) => row.handsPlayed < minimumHands);
}

export function getPrizePlacementRows(rows: PublicLeaderboardRow[]): PublicPrizePlacementRow[] {
  const placements: PublicPrizePlacementRow[] = [];
  let placement = 0;
  let previousPoints: number | null = null;

  getPrizeEligibleRows(rows).forEach((row, index) => {
    if (previousPoints !== row.totalPoints) {
      placement = index + 1;
      previousPoints = row.totalPoints;
    }

    placements.push({ row, placement });
  });

  return placements;
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

function looksLikeEventId(value: string): boolean {
  return (
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      value,
    ) || /^event[-_]/.test(value)
  );
}

async function resolvePublicEventId(
  client: PublicStandingsRpcClient,
  eventSlug: string,
): Promise<PublicEventResolutionRpcRow> {
  const result = await Promise.resolve(
    client.rpc("resolve_public_event_id", { target_public_slug: eventSlug }),
  );

  if (result.error) {
    throw new Error(result.error.message ?? "Unable to resolve public event.");
  }

  const resolution = (result.data?.[0] ?? null) as PublicEventResolutionRpcRow | null;
  if (!resolution?.event_id) {
    throw new Error("Public event not found.");
  }

  return resolution;
}

export async function fetchPublicStandings(
  client: PublicStandingsClient,
  eventRef: string,
): Promise<PublicStandingsSnapshot> {
  const isEventId = looksLikeEventId(eventRef);

  if (typeof client.from === "function") {
    const snapshotColumn = isEventId ? "event_id" : "public_slug";
    const snapshotResult = await Promise.resolve(
      client
        .from("public_event_standings_snapshots")
        .select("event_id, public_slug, payload, updated_at")
        .eq(snapshotColumn, eventRef)
        .maybeSingle(),
    );

    if (!snapshotResult.error && snapshotResult.data) {
      return mapPublicStandingsSnapshotPayload(
        snapshotResult.data.payload,
        snapshotResult.data.updated_at,
        snapshotResult.data.event_id,
        snapshotResult.data.public_slug,
      );
    }
  }

  const eventResolution =
    !isEventId && typeof client.from === "function"
      ? await resolvePublicEventId(client, eventRef)
      : null;
  const eventId = eventResolution?.event_id ?? eventRef;
  const eventSlug = eventResolution?.public_slug ?? null;

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
    eventId: eventSummary?.event_id ?? eventId,
    eventSlug: eventSummary?.public_slug ?? eventSlug,
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
