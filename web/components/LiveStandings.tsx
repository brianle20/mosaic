"use client";

import { useEffect, useRef, useState } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { StandingsTable } from "./StandingsTable";
import {
  fetchPublicStandings,
  type PublicStandingsRpcClient,
  type PublicStandingsSnapshot,
} from "../lib/public-standings";
import { createPublicSupabaseClient } from "../lib/supabase";

type SupabaseRealtimeClient = PublicStandingsRpcClient & {
  channel: (name: string) => RealtimeChannel;
  removeChannel?: (channel: RealtimeChannel) => Promise<unknown>;
};

type LiveStandingsProps = {
  eventId: string;
  initialSnapshot: PublicStandingsSnapshot;
  supabaseClient?: SupabaseRealtimeClient;
  fetchStandings?: (
    client: PublicStandingsRpcClient,
    eventId: string,
  ) => Promise<PublicStandingsSnapshot>;
};

const REALTIME_TABLES = ["public_event_updates"] as const;

const REFRESH_DEBOUNCE_MS = 200;

function payloadMatchesEvent(payload: { new?: Record<string, unknown>; old?: Record<string, unknown> }, eventId: string) {
  const eventIdFromPayload = payload.new?.event_id ?? payload.old?.event_id;
  return eventIdFromPayload === undefined || eventIdFromPayload === eventId;
}

export function LiveStandings({
  eventId,
  initialSnapshot,
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
  const clientRef = useRef<SupabaseRealtimeClient | null>(supabaseClient ?? null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const snapshot =
    snapshotState.eventId === eventId ? snapshotState.snapshot : initialSnapshot;
  const status = statusState.eventId === eventId ? statusState.status : "idle";

  useEffect(() => {
    let isCurrentEvent = true;
    let client: SupabaseRealtimeClient;
    try {
      client = clientRef.current ?? createPublicSupabaseClient();
    } catch {
      queueMicrotask(() => {
        if (isCurrentEvent) {
          setStatusState({ eventId, status: "error" });
        }
      });
      return;
    }
    clientRef.current = client;

    const refresh = () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }

      timerRef.current = setTimeout(async () => {
        setStatusState({ eventId, status: "refreshing" });
        try {
          const refreshedSnapshot = await fetchStandings(client, eventId);
          if (isCurrentEvent) {
            setSnapshotState({ eventId, snapshot: refreshedSnapshot });
            setStatusState({ eventId, status: "idle" });
          }
        } catch {
          if (isCurrentEvent) {
            setStatusState({ eventId, status: "error" });
          }
        }
      }, REFRESH_DEBOUNCE_MS);
    };

    const channel = REALTIME_TABLES.reduce(
      (currentChannel, table) =>
        currentChannel.on(
          "postgres_changes",
          { event: "*", schema: "public", table },
          (payload) => {
            if (payloadMatchesEvent(payload, eventId)) {
              refresh();
            }
          },
        ),
      client.channel(`public-standings:${eventId}`),
    );

    channel.subscribe();

    return () => {
      isCurrentEvent = false;
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }
      void client.removeChannel?.(channel);
    };
  }, [eventId, fetchStandings]);

  return (
    <main className="standings-shell">
      <header className="standings-header">
        <div>
          <p className="eyebrow">Mosaic tournament</p>
          <h1>{snapshot.eventTitle}</h1>
        </div>
        <div className="updated-at">
          <span>Last updated</span>
          <time dateTime={snapshot.updatedAt ?? undefined}>
            {snapshot.updatedAt
              ? new Intl.DateTimeFormat(undefined, {
                  hour: "numeric",
                  minute: "2-digit",
                  second: "2-digit",
                }).format(new Date(snapshot.updatedAt))
              : "Waiting for scores"}
          </time>
        </div>
      </header>

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

      <StandingsTable rows={snapshot.leaderboard} />

      {status === "refreshing" ? <p className="status-line">Refreshing standings...</p> : null}
      {status === "error" ? (
        <p className="status-line error">
          Live refresh could not update. Showing the latest standings we have.
        </p>
      ) : null}
    </main>
  );
}
