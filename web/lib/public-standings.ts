export type PublicLeaderboardRpcRow = {
  event_guest_id: string;
  public_display_name: string | null;
  tournament_status?: string | null;
  prize_eligible?: boolean | null;
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

export type PublicFinalsLeaderboardRpcRow = {
  bonus_table_role: string | null;
  table_label: string | null;
  event_guest_id: string;
  public_display_name: string | null;
  seat_index: number | null;
  total_points: number | null;
  hands_played: number | null;
  wins: number | null;
  rank: number | null;
  [key: string]: unknown;
};

export type PublicPointsTimelineRpcRow = {
  hand_index: number | string | null;
  hand_result_id: string | null;
  recorded_at: string | null;
  table_label: string | null;
  event_guest_id: string;
  public_display_name: string | null;
  points_delta: number | string | null;
  total_points: number | string | null;
  rank: number | string | null;
  [key: string]: unknown;
};

export type PublicEventSummaryRpcRow = {
  event_id: string;
  public_slug?: string | null;
  title: string | null;
  [key: string]: unknown;
};

export type PublicEventDirectoryRpcRow = {
  event_id: string;
  public_slug: string | null;
  title: string | null;
  event_starts_at: string | null;
  event_timezone: string | null;
  standings_updated_at: string | null;
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
  tournamentStatus?: PublicTournamentStatus;
  prizeEligible?: boolean;
  totalPoints: number;
  handsPlayed: number;
  wins: number;
  selfDrawWins: number;
  discardWins: number;
  discardLosses: number;
  rank: number;
};

export type PublicTournamentStatus = "qualified" | "withdrawn";

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

export type PublicFinalsLeaderboardRow = {
  eventGuestId: string;
  publicDisplayName: string;
  seatIndex: number;
  totalPoints: number;
  handsPlayed: number;
  wins: number;
  rank: number;
};

export type PublicFinalsLeaderboardTable = {
  tableRole: string;
  title: string;
  tableLabel: string;
  hasScores: boolean;
  rows: PublicFinalsLeaderboardRow[];
};

export type PublicPointsTimelinePlayerPoint = {
  eventGuestId: string;
  publicDisplayName: string;
  pointsDelta: number;
  totalPoints: number;
  rank: number;
};

export type PublicPointsTimelineHand = {
  handIndex: number;
  handResultId: string;
  recordedAt: string | null;
  tableLabel: string;
  players: PublicPointsTimelinePlayerPoint[];
};

export type PublicStandingsSnapshot = {
  eventId?: string;
  eventSlug?: string | null;
  eventTitle: string;
  leaderboard: PublicLeaderboardRow[];
  bonusResults: PublicBonusResult[];
  finalsLeaderboards?: PublicFinalsLeaderboardTable[];
  pointsTimeline: PublicPointsTimelineHand[];
  updatedAt: string | null;
};

export type PublicEventDirectoryRow = {
  eventId: string;
  publicSlug: string;
  title: string;
  startsAt: string | null;
  timezone: string | null;
  standingsUpdatedAt: string | null;
};

export type PublicStandingsRpcClient = {
  rpc: {
    (fn: "get_public_events"): PromiseLike<{
      data: unknown[] | null;
      error: { message?: string } | null;
    }>;
    (
      fn:
        | "get_public_event_summary"
        | "get_public_event_leaderboard"
        | "get_public_event_bonus_results"
        | "get_public_event_finals_leaderboard"
        | "get_public_event_points_timeline",
      args: { target_event_id: string },
    ): PromiseLike<{ data: unknown[] | null; error: { message?: string } | null }>;
    (
      fn: "resolve_public_event_id",
      args: { target_public_slug: string },
    ): PromiseLike<{ data: unknown[] | null; error: { message?: string } | null }>;
  };
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

export class PublicEventUnavailableError extends Error {
  constructor(message = "Public event not found.") {
    super(message);
    this.name = "PublicEventUnavailableError";
  }
}

export function isPublicEventUnavailableError(
  error: unknown,
): error is PublicEventUnavailableError {
  return error instanceof PublicEventUnavailableError;
}

export function mapLeaderboardRow(row: PublicLeaderboardRpcRow): PublicLeaderboardRow {
  return withLeaderboardEligibility({
    eventGuestId: row.event_guest_id,
    publicDisplayName: row.public_display_name?.trim() || "Player",
    totalPoints: Number(row.total_points ?? 0),
    handsPlayed: Number(row.hands_played ?? 0),
    wins: Number(row.wins ?? 0),
    selfDrawWins: Number(row.self_draw_wins ?? 0),
    discardWins: Number(row.discard_wins ?? 0),
    discardLosses: Number(row.discard_losses ?? 0),
    rank: Number(row.rank ?? 0),
  }, row.tournament_status, row.prize_eligible);
}

export function mapPublicEventRow(
  row: PublicEventDirectoryRpcRow,
): PublicEventDirectoryRow {
  return {
    eventId: row.event_id,
    publicSlug: row.public_slug?.trim() || "",
    title: row.title?.trim() || "Mosaic event",
    startsAt: readNullableString(row.event_starts_at),
    timezone: readNullableString(row.event_timezone),
    standingsUpdatedAt: readNullableString(row.standings_updated_at),
  };
}

export async function fetchPublicEvents(
  client: PublicStandingsRpcClient,
): Promise<PublicEventDirectoryRow[]> {
  const result = await Promise.resolve(client.rpc("get_public_events"));

  if (result.error) {
    throw new Error(result.error.message ?? "Unable to load public events.");
  }

  return (result.data ?? [])
    .map((row) => mapPublicEventRow(row as PublicEventDirectoryRpcRow))
    .filter((event) => event.publicSlug.length > 0);
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

function readNullableString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function readTournamentStatus(value: unknown): PublicTournamentStatus | undefined {
  if (value === "withdrawn") {
    return "withdrawn";
  }

  if (value === "qualified") {
    return "qualified";
  }

  return undefined;
}

function withLeaderboardEligibility<T extends PublicLeaderboardRow>(
  row: Omit<T, "tournamentStatus" | "prizeEligible">,
  status: unknown,
  prizeEligibleValue: unknown,
): T {
  const tournamentStatus = readTournamentStatus(status);
  const prizeEligible =
    typeof prizeEligibleValue === "boolean" ? prizeEligibleValue : undefined;

  return {
    ...row,
    ...(tournamentStatus === undefined ? {} : { tournamentStatus }),
    ...(prizeEligible === undefined ? {} : { prizeEligible }),
  } as T;
}

function mapSnapshotLeaderboardRow(row: unknown): PublicLeaderboardRow {
  const record = asRecord(row) ?? {};

  return withLeaderboardEligibility({
    eventGuestId: readString(record.eventGuestId, ""),
    publicDisplayName: readString(record.publicDisplayName, "Player"),
    totalPoints: readNumber(record.totalPoints),
    handsPlayed: readNumber(record.handsPlayed),
    wins: readNumber(record.wins),
    selfDrawWins: readNumber(record.selfDrawWins),
    discardWins: readNumber(record.discardWins),
    discardLosses: readNumber(record.discardLosses),
    rank: readNumber(record.rank),
  }, record.tournamentStatus, record.prizeEligible);
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

function mapSnapshotPointsTimelinePlayer(row: unknown): PublicPointsTimelinePlayerPoint {
  const record = asRecord(row) ?? {};

  return {
    eventGuestId: readString(record.eventGuestId, ""),
    publicDisplayName: readString(record.publicDisplayName, "Player"),
    pointsDelta: readNumber(record.pointsDelta),
    totalPoints: readNumber(record.totalPoints),
    rank: readNumber(record.rank),
  };
}

function mapSnapshotPointsTimelineHand(row: unknown): PublicPointsTimelineHand {
  const record = asRecord(row) ?? {};
  const players = Array.isArray(record.players) ? record.players : [];

  return {
    handIndex: readNumber(record.handIndex),
    handResultId: readString(record.handResultId, ""),
    recordedAt: readNullableString(record.recordedAt),
    tableLabel: readString(record.tableLabel, "Table"),
    players: players.map(mapSnapshotPointsTimelinePlayer),
  };
}

function isFlatSnapshotPointsTimelineRow(row: unknown): boolean {
  const record = asRecord(row);
  return record !== null && Object.prototype.hasOwnProperty.call(record, "eventGuestId");
}

function pointsTimelineHandSort(
  left: PublicPointsTimelineHand,
  right: PublicPointsTimelineHand,
): number {
  const handCompare = left.handIndex - right.handIndex;
  if (handCompare !== 0) {
    return handCompare;
  }

  const recordedCompare = (left.recordedAt ?? "").localeCompare(right.recordedAt ?? "");
  if (recordedCompare !== 0) {
    return recordedCompare;
  }

  return left.tableLabel.localeCompare(right.tableLabel);
}

function mapFlatSnapshotPointsTimelineRows(rows: unknown[]): PublicPointsTimelineHand[] {
  const handsByKey = new Map<
    string,
    {
      handIndex: number;
      handResultId: string;
      recordedAt: string | null;
      tableLabel: string;
      players: PublicPointsTimelinePlayerPoint[];
    }
  >();

  for (const row of rows) {
    const record = asRecord(row) ?? {};
    const handIndex = readNumber(record.handIndex);
    const handResultId = readString(record.handResultId, "");
    const recordedAt = readNullableString(record.recordedAt);
    const tableLabel = readString(record.tableLabel, "Table");
    const key = handResultId || `${handIndex}\u0000${recordedAt ?? ""}\u0000${tableLabel}`;
    const hand = handsByKey.get(key) ?? {
      handIndex,
      handResultId,
      recordedAt,
      tableLabel,
      players: [],
    };

    hand.players.push(mapSnapshotPointsTimelinePlayer(row));
    handsByKey.set(key, hand);
  }

  return Array.from(handsByKey.values()).map((hand) => ({
    handIndex: hand.handIndex,
    handResultId: hand.handResultId,
    recordedAt: hand.recordedAt,
    tableLabel: hand.tableLabel,
    players: [...hand.players].sort(pointsTimelinePlayerSort),
  }));
}

function mapSnapshotPointsTimelineRows(rows: unknown[]): PublicPointsTimelineHand[] {
  const groupedRows: unknown[] = [];
  const flatRows: unknown[] = [];

  for (const row of rows) {
    if (isFlatSnapshotPointsTimelineRow(row)) {
      flatRows.push(row);
    } else {
      groupedRows.push(row);
    }
  }

  if (flatRows.length === 0) {
    return groupedRows.map(mapSnapshotPointsTimelineHand);
  }

  return [
    ...groupedRows.map(mapSnapshotPointsTimelineHand),
    ...mapFlatSnapshotPointsTimelineRows(flatRows),
  ].sort(pointsTimelineHandSort);
}

function mapSnapshotFinalsLeaderboardRow(row: unknown): PublicFinalsLeaderboardRow {
  const record = asRecord(row) ?? {};

  return {
    eventGuestId: readString(record.eventGuestId, ""),
    publicDisplayName: readString(record.publicDisplayName, "Player"),
    seatIndex: readNumber(record.seatIndex),
    totalPoints: readNumber(record.totalPoints),
    handsPlayed: readNumber(record.handsPlayed),
    wins: readNumber(record.wins),
    rank: readNumber(record.rank),
  };
}

function finalsTitleForRole(role: string): string {
  if (role === "table_of_champions") {
    return "Table of Champions";
  }
  if (role === "table_of_redemption") {
    return "Table of Redemption";
  }
  return "Finals Table";
}

function finalsRoleSort(role: string): number {
  if (role === "table_of_champions") {
    return 0;
  }
  if (role === "table_of_redemption") {
    return 1;
  }
  return 2;
}

function mapSnapshotFinalsLeaderboardTable(
  table: unknown,
): PublicFinalsLeaderboardTable {
  const record = asRecord(table) ?? {};
  const rows = Array.isArray(record.rows)
    ? record.rows.map(mapSnapshotFinalsLeaderboardRow)
    : [];
  const tableRole = readString(record.tableRole, "");
  const hasScores =
    typeof record.hasScores === "boolean"
      ? record.hasScores
      : rows.some((row) => row.handsPlayed > 0);

  return {
    tableRole,
    title: readString(record.title, finalsTitleForRole(tableRole)),
    tableLabel: readString(record.tableLabel, "Finals table"),
    hasScores,
    rows,
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
  const finalsLeaderboards = Array.isArray(record.finalsLeaderboards)
    ? record.finalsLeaderboards
    : [];
  const pointsTimeline = Array.isArray(record.pointsTimeline)
    ? record.pointsTimeline
    : [];
  const hasPayloadUpdatedAt = Object.prototype.hasOwnProperty.call(
    record,
    "updatedAt",
  );
  const payloadUpdatedAt =
    typeof record.updatedAt === "string" && record.updatedAt.trim().length > 0
      ? record.updatedAt
      : null;

  const snapshot: PublicStandingsSnapshot = {
    eventTitle: readString(record.eventTitle, "Mosaic tournament"),
    leaderboard: leaderboard.map(mapSnapshotLeaderboardRow),
    bonusResults: bonusResults.map(mapSnapshotBonusResult),
    finalsLeaderboards: finalsLeaderboards.map(mapSnapshotFinalsLeaderboardTable),
    pointsTimeline: mapSnapshotPointsTimelineRows(pointsTimeline),
    updatedAt: hasPayloadUpdatedAt ? payloadUpdatedAt : updatedAt,
  };

  if (eventId) {
    snapshot.eventId = eventId;
  }

  if (eventSlug !== undefined) {
    snapshot.eventSlug = eventSlug;
  }

  return snapshot;
}

export function getPrizeEligibleRows(rows: PublicLeaderboardRow[]): PublicLeaderboardRow[] {
  return rows.filter(canQualifyForPrize);
}

export function getNotPrizeEligibleRows(rows: PublicLeaderboardRow[]): PublicLeaderboardRow[] {
  return rows.filter((row) => !canQualifyForPrize(row));
}

function canQualifyForPrize(row: PublicLeaderboardRow): boolean {
  return (
    row.tournamentStatus !== "withdrawn" &&
    (row.prizeEligible ?? row.handsPlayed > 0)
  );
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

function mapFinalsLeaderboardRow(
  row: PublicFinalsLeaderboardRpcRow,
): PublicFinalsLeaderboardRow {
  return {
    eventGuestId: row.event_guest_id,
    publicDisplayName: row.public_display_name?.trim() || "Player",
    seatIndex: Number(row.seat_index ?? 0),
    totalPoints: Number(row.total_points ?? 0),
    handsPlayed: Number(row.hands_played ?? 0),
    wins: Number(row.wins ?? 0),
    rank: Number(row.rank ?? 0),
  };
}

export function mapFinalsLeaderboardRows(
  rows: PublicFinalsLeaderboardRpcRow[],
): PublicFinalsLeaderboardTable[] {
  const tablesByKey = new Map<
    string,
    {
      tableRole: string;
      tableLabel: string;
      rows: PublicFinalsLeaderboardRow[];
    }
  >();

  for (const row of rows) {
    const tableRole = row.bonus_table_role?.trim() || "";
    const tableLabel = row.table_label?.trim() || "Finals table";
    const key = `${tableRole}\u0000${tableLabel}`;
    const table = tablesByKey.get(key) ?? {
      tableRole,
      tableLabel,
      rows: [],
    };
    table.rows.push(mapFinalsLeaderboardRow(row));
    tablesByKey.set(key, table);
  }

  return Array.from(tablesByKey.values())
    .map((table) => {
      const hasScores = table.rows.some((row) => row.handsPlayed > 0);
      const sortedRows = [...table.rows].sort((left, right) => {
        if (!hasScores) {
          return left.seatIndex - right.seatIndex;
        }
        const rankCompare = left.rank - right.rank;
        if (rankCompare !== 0) {
          return rankCompare;
        }
        return left.publicDisplayName.localeCompare(right.publicDisplayName);
      });
      return {
        tableRole: table.tableRole,
        title: finalsTitleForRole(table.tableRole),
        tableLabel: table.tableLabel,
        hasScores,
        rows: sortedRows,
      };
    })
    .sort((left, right) => {
      const roleCompare = finalsRoleSort(left.tableRole) - finalsRoleSort(right.tableRole);
      if (roleCompare !== 0) {
        return roleCompare;
      }
      return left.tableLabel.localeCompare(right.tableLabel);
    });
}

function mapPointsTimelinePlayerRow(
  row: PublicPointsTimelineRpcRow,
): PublicPointsTimelinePlayerPoint {
  return {
    eventGuestId: row.event_guest_id,
    publicDisplayName: row.public_display_name?.trim() || "Player",
    pointsDelta: readNumber(row.points_delta),
    totalPoints: readNumber(row.total_points),
    rank: readNumber(row.rank),
  };
}

function pointsTimelinePlayerSort(
  left: PublicPointsTimelinePlayerPoint,
  right: PublicPointsTimelinePlayerPoint,
): number {
  const leftRank = left.rank > 0 ? left.rank : Number.MAX_SAFE_INTEGER;
  const rightRank = right.rank > 0 ? right.rank : Number.MAX_SAFE_INTEGER;
  const rankCompare = leftRank - rightRank;
  if (rankCompare !== 0) {
    return rankCompare;
  }

  const pointsCompare = right.totalPoints - left.totalPoints;
  if (pointsCompare !== 0) {
    return pointsCompare;
  }

  return left.publicDisplayName.localeCompare(right.publicDisplayName);
}

export function mapPointsTimelineRows(
  rows: PublicPointsTimelineRpcRow[],
): PublicPointsTimelineHand[] {
  const handsByKey = new Map<
    string,
    {
      handIndex: number;
      handResultId: string;
      recordedAt: string | null;
      tableLabel: string;
      players: PublicPointsTimelinePlayerPoint[];
    }
  >();

  for (const row of rows) {
    const handIndex = readNumber(row.hand_index);
    const handResultId = row.hand_result_id?.trim() || "";
    const recordedAt = row.recorded_at?.trim() || null;
    const tableLabel = row.table_label?.trim() || "Table";
    const key = handResultId || `${handIndex}\u0000${recordedAt ?? ""}\u0000${tableLabel}`;
    const hand = handsByKey.get(key) ?? {
      handIndex,
      handResultId,
      recordedAt,
      tableLabel,
      players: [],
    };

    hand.players.push(mapPointsTimelinePlayerRow(row));
    handsByKey.set(key, hand);
  }

  return Array.from(handsByKey.values())
    .map((hand) => ({
      handIndex: hand.handIndex,
      handResultId: hand.handResultId,
      recordedAt: hand.recordedAt,
      tableLabel: hand.tableLabel,
      players: [...hand.players].sort(pointsTimelinePlayerSort),
    }))
    .sort(pointsTimelineHandSort);
}

function looksLikeEventId(value: string): boolean {
  return (
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      value,
    ) || /^event[-_]/.test(value)
  );
}

function latestPointsTimelineRecordedAt(
  pointsTimeline: PublicPointsTimelineHand[],
): string | null {
  let latestValue: string | null = null;
  let latestTime = Number.NEGATIVE_INFINITY;

  for (const hand of pointsTimeline) {
    if (!hand.recordedAt) {
      continue;
    }

    const recordedTime = Date.parse(hand.recordedAt);
    if (Number.isNaN(recordedTime) || recordedTime <= latestTime) {
      continue;
    }

    latestValue = hand.recordedAt;
    latestTime = recordedTime;
  }

  return latestValue;
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
    throw new PublicEventUnavailableError();
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

  const [
    summaryResult,
    leaderboardResult,
    bonusResult,
    finalsResult,
    pointsTimelineResult,
  ] = await Promise.all([
    Promise.resolve(client.rpc("get_public_event_summary", { target_event_id: eventId })),
    Promise.resolve(client.rpc("get_public_event_leaderboard", { target_event_id: eventId })),
    Promise.resolve(client.rpc("get_public_event_bonus_results", { target_event_id: eventId })),
    Promise.resolve(
      client.rpc("get_public_event_finals_leaderboard", { target_event_id: eventId }),
    ),
    Promise.resolve(
      client.rpc("get_public_event_points_timeline", { target_event_id: eventId }),
    ),
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

  if (finalsResult.error) {
    throw new Error(
      finalsResult.error.message ?? "Unable to load public finals leaderboards.",
    );
  }

  if (pointsTimelineResult.error) {
    throw new Error(
      pointsTimelineResult.error.message ?? "Unable to load public points timeline.",
    );
  }

  const eventSummary = (summaryResult.data?.[0] ?? null) as PublicEventSummaryRpcRow | null;
  if (!eventSummary?.event_id) {
    throw new PublicEventUnavailableError();
  }

  const pointsTimeline = mapPointsTimelineRows(
    (pointsTimelineResult.data ?? []) as PublicPointsTimelineRpcRow[],
  );

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
    finalsLeaderboards: mapFinalsLeaderboardRows(
      (finalsResult.data ?? []) as PublicFinalsLeaderboardRpcRow[],
    ),
    pointsTimeline,
    updatedAt: latestPointsTimelineRecordedAt(pointsTimeline),
  };
}
