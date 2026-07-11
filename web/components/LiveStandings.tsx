"use client";

import { useEffect, useRef, useState } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { PublicEventShell } from "./PublicEventShell";
import { PublicLoadErrorBanner } from "./PublicLoadErrorBanner";
import { StandingsTable, type ScoreChangeMap } from "./StandingsTable";
import {
  fetchPublicStandings,
  mapPublicStandingsSnapshotPayload,
  type PublicStandingsClient,
  type PublicLeaderboardRow,
  type PublicFinalsLeaderboardTable,
  type PublicStandingsSnapshot,
} from "../lib/public-standings";
import { captureAnalyticsEvent } from "../lib/analytics";
import { createPublicSupabaseClient } from "../lib/supabase";

type SupabaseRealtimeClient = PublicStandingsClient & {
  channel: (name: string) => RealtimeChannel;
  removeChannel?: (channel: RealtimeChannel) => Promise<unknown>;
};

type RealtimeSnapshotPayload = {
  new?: Record<string, unknown>;
  old?: Record<string, unknown>;
};

type LiveStandingsProps = {
  eventId: string;
  eventSlug: string;
  initialSnapshot: PublicStandingsSnapshot;
  initialLoadFailed?: boolean;
  supabaseClient?: SupabaseRealtimeClient;
  fetchStandings?: (
    client: PublicStandingsClient,
    eventId: string,
  ) => Promise<PublicStandingsSnapshot>;
};

const REALTIME_SNAPSHOT_TABLE = "public_event_standings_snapshots";

const REFRESH_DEBOUNCE_MS = 200;
const AUTO_REFRESH_INTERVAL_MS = 30_000;
const AUTO_REFRESH_JITTER_MS = 5_000;
const SCORE_CHANGE_VISIBLE_MS = 2500;

function payloadMatchesEvent(payload: RealtimeSnapshotPayload, eventId: string) {
  const eventIdFromPayload = payload.new?.event_id ?? payload.old?.event_id;
  return eventIdFromPayload === undefined || eventIdFromPayload === eventId;
}

function snapshotFromRealtimePayload(
  payload: RealtimeSnapshotPayload,
): PublicStandingsSnapshot | null {
  if (!payload.new || !("payload" in payload.new)) {
    return null;
  }

  return mapPublicStandingsSnapshotPayload(
    payload.new.payload,
    typeof payload.new.updated_at === "string" ? payload.new.updated_at : null,
  );
}

function createRealtimeClient(): SupabaseRealtimeClient {
  return createPublicSupabaseClient() as unknown as SupabaseRealtimeClient;
}

function signedPoints(points: number): string {
  if (points > 0) {
    return `+${points.toLocaleString()}`;
  }
  return points.toLocaleString();
}

function pluralize(count: number, singular: string): string {
  return `${count.toLocaleString()} ${singular}${count === 1 ? "" : "s"}`;
}

function seatLabel(seatIndex: number): string {
  if (seatIndex === 0) {
    return "East";
  }
  if (seatIndex === 1) {
    return "South";
  }
  if (seatIndex === 2) {
    return "West";
  }
  if (seatIndex === 3) {
    return "North";
  }
  return `Seat ${seatIndex + 1}`;
}

function getScoreChanges(
  previousRows: PublicLeaderboardRow[],
  nextRows: PublicLeaderboardRow[],
): ScoreChangeMap {
  const previousRowsByGuestId = new Map(
    previousRows.map((row) => [row.eventGuestId, row]),
  );

  return nextRows.reduce<ScoreChangeMap>((changes, row) => {
    const previousRow = previousRowsByGuestId.get(row.eventGuestId);
    if (!previousRow) {
      return changes;
    }

    const pointsDelta = row.totalPoints - previousRow.totalPoints;
    if (pointsDelta !== 0) {
      changes[row.eventGuestId] = { pointsDelta };
    }

    return changes;
  }, {});
}

export function LiveStandings({
  eventId,
  eventSlug,
  initialSnapshot,
  initialLoadFailed = false,
  supabaseClient,
  fetchStandings = fetchPublicStandings,
}: LiveStandingsProps) {
  const [snapshotState, setSnapshotState] = useState({
    eventId,
    snapshot: initialSnapshot,
  });
  const [statusState, setStatusState] = useState<{
    eventId: string;
    status: "idle" | "refreshing" | "error";
  }>({ eventId, status: "idle" });
  const [scoreChangesState, setScoreChangesState] = useState<{
    eventId: string;
    scoreChanges: ScoreChangeMap;
  }>({ eventId, scoreChanges: {} });
  const clientRef = useRef<SupabaseRealtimeClient | null>(supabaseClient ?? null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const realtimeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const scoreChangesTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const snapshotRef = useRef({
    eventId,
    snapshot: initialSnapshot,
  });
  const snapshot =
    snapshotState.eventId === eventId ? snapshotState.snapshot : initialSnapshot;
  const status = statusState.eventId === eventId ? statusState.status : "idle";
  const scoreChanges =
    scoreChangesState.eventId === eventId ? scoreChangesState.scoreChanges : {};

  useEffect(() => {
    if (eventSlug) {
      captureAnalyticsEvent("public_standings_viewed", { event_slug: eventSlug });
    }
  }, [eventSlug]);

  useEffect(() => {
    let isCurrentEvent = true;
    let client: SupabaseRealtimeClient;
    snapshotRef.current = { eventId, snapshot: initialSnapshot };
    try {
      client = clientRef.current ?? createRealtimeClient();
    } catch {
      queueMicrotask(() => {
        if (isCurrentEvent) {
          setStatusState({ eventId, status: "error" });
        }
      });
      return;
    }
    clientRef.current = client;

    const applySnapshot = (refreshedSnapshot: PublicStandingsSnapshot) => {
      if (!isCurrentEvent) {
        return;
      }

      const previousSnapshot = snapshotRef.current;
      const nextScoreChanges =
        previousSnapshot.eventId === eventId
          ? getScoreChanges(
              previousSnapshot.snapshot.leaderboard,
              refreshedSnapshot.leaderboard,
            )
          : {};

      if (scoreChangesTimerRef.current) {
        clearTimeout(scoreChangesTimerRef.current);
      }

      setScoreChangesState({ eventId, scoreChanges: nextScoreChanges });
      scoreChangesTimerRef.current = setTimeout(() => {
        if (isCurrentEvent) {
          setScoreChangesState({ eventId, scoreChanges: {} });
        }
      }, SCORE_CHANGE_VISIBLE_MS);

      snapshotRef.current = { eventId, snapshot: refreshedSnapshot };
      setSnapshotState({ eventId, snapshot: refreshedSnapshot });
      setStatusState({ eventId, status: "idle" });
    };

    const clearRealtimeTimer = () => {
      if (realtimeTimerRef.current) {
        clearTimeout(realtimeTimerRef.current);
        realtimeTimerRef.current = null;
      }
    };

    const scheduleRealtimeSnapshot = (
      streamedSnapshot: PublicStandingsSnapshot,
    ) => {
      clearRealtimeTimer();
      realtimeTimerRef.current = setTimeout(() => {
        realtimeTimerRef.current = null;
        applySnapshot(streamedSnapshot);
      }, REFRESH_DEBOUNCE_MS);
    };

    const refresh = () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }

      timerRef.current = setTimeout(async () => {
        setStatusState({ eventId, status: "refreshing" });
        try {
          const refreshedSnapshot = await fetchStandings(client, eventId);
          if (isCurrentEvent) {
            clearRealtimeTimer();
            applySnapshot(refreshedSnapshot);
          }
        } catch {
          if (isCurrentEvent) {
            setStatusState({ eventId, status: "error" });
          }
        }
      }, REFRESH_DEBOUNCE_MS);
    };

    const stopAutoRefresh = () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    };

    const startAutoRefresh = () => {
      if (document.visibilityState === "hidden" || intervalRef.current) {
        return;
      }

      intervalRef.current = setInterval(
        refresh,
        AUTO_REFRESH_INTERVAL_MS + Math.floor(Math.random() * AUTO_REFRESH_JITTER_MS),
      );
    };

    const handleVisibilityChange = () => {
      if (document.visibilityState === "hidden") {
        stopAutoRefresh();
      } else {
        startAutoRefresh();
        refresh();
      }
    };

    const channel = client
      .channel(`public-standings:${eventId}`)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: REALTIME_SNAPSHOT_TABLE },
        (payload) => {
          if (!payloadMatchesEvent(payload, eventId)) {
            return;
          }

          const streamedSnapshot = snapshotFromRealtimePayload(payload);
          if (streamedSnapshot) {
            scheduleRealtimeSnapshot(streamedSnapshot);
          }
        },
      );

    channel.subscribe((subscriptionStatus) => {
      if (
        isCurrentEvent &&
        (subscriptionStatus === "CHANNEL_ERROR" ||
          subscriptionStatus === "TIMED_OUT" ||
          subscriptionStatus === "CLOSED")
      ) {
        setStatusState({ eventId, status: "error" });
      }
    });
    startAutoRefresh();
    document.addEventListener("visibilitychange", handleVisibilityChange);

    return () => {
      isCurrentEvent = false;
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }
      clearRealtimeTimer();
      if (scoreChangesTimerRef.current) {
        clearTimeout(scoreChangesTimerRef.current);
      }
      stopAutoRefresh();
      document.removeEventListener("visibilitychange", handleVisibilityChange);
      void client.removeChannel?.(channel);
    };
  }, [eventId, fetchStandings, initialSnapshot]);

  return (
    <PublicEventShell
      eventSlug={eventSlug}
      eventTitle={snapshot.eventTitle}
      updatedAt={snapshot.updatedAt}
      activeView="standings"
    >
      {initialLoadFailed ? <PublicLoadErrorBanner /> : null}

      {snapshot.bonusResults.length > 0 ? (
        <section className="bonus-strip" aria-label="Finals results">
          {snapshot.bonusResults.map((result) => (
            <div key={`${result.eventGuestId}-${result.resultLabel}`} className="bonus-result">
              <span>{result.resultLabel}</span>
              <strong>{result.publicDisplayName}</strong>
              {result.pointsDelta !== 0 ? (
                <small>{result.pointsDelta > 0 ? "+" : ""}{result.pointsDelta.toLocaleString()}</small>
              ) : null}
            </div>
          ))}
        </section>
      ) : null}

      <FinalsLeaderboards tables={snapshot.finalsLeaderboards ?? []} />

      <StandingsTable rows={snapshot.leaderboard} scoreChanges={scoreChanges} />

      {status === "refreshing" ? <p className="status-line">Refreshing standings...</p> : null}
      {status === "error" ? (
        <p className="status-line error">
          Live refresh could not update. Showing the latest standings we have.
        </p>
      ) : null}
    </PublicEventShell>
  );
}

function FinalsLeaderboards({ tables }: { tables: PublicFinalsLeaderboardTable[] }) {
  if (tables.length === 0) {
    return null;
  }

  return (
    <section className="finals-leaderboards" aria-labelledby="finals-leaderboards-heading">
      <h2 id="finals-leaderboards-heading" className="section-heading">
        Finals Leaderboards
      </h2>
      <div className="finals-leaderboard-grid">
        {tables.map((table) => (
          <article
            key={`${table.tableRole}-${table.tableLabel}`}
            className="finals-leaderboard-card"
          >
            <header>
              <h3>{table.title}</h3>
              <p>{table.tableLabel}</p>
            </header>
            <div className="finals-row-list">
              {table.rows.map((row) => (
                <div className="finals-row" key={row.eventGuestId}>
                  <span className="finals-rank">
                    {table.hasScores ? `#${row.rank}` : seatLabel(row.seatIndex)}
                  </span>
                  <span className="finals-player">
                    <strong>{row.publicDisplayName}</strong>
                    <small>
                      {pluralize(row.handsPlayed, "hand")} · {pluralize(row.wins, "win")}
                    </small>
                  </span>
                  <span className={`finals-points ${row.totalPoints < 0 ? "negative" : "positive"}`}>
                    {signedPoints(row.totalPoints)}
                  </span>
                </div>
              ))}
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}
