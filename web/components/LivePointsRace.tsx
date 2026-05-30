"use client";

import { useEffect, useRef, useState } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { PointsRaceChart } from "./PointsRaceChart";
import {
  fetchPublicStandings,
  mapPublicStandingsSnapshotPayload,
  type PublicStandingsClient,
  type PublicStandingsSnapshot,
} from "../lib/public-standings";
import { createPublicSupabaseClient } from "../lib/supabase";

type SupabaseRealtimeClient = PublicStandingsClient & {
  channel: (name: string) => RealtimeChannel;
  removeChannel?: (channel: RealtimeChannel) => Promise<unknown>;
};

type RealtimeSnapshotPayload = {
  new?: Record<string, unknown>;
  old?: Record<string, unknown>;
};

type LivePointsRaceProps = {
  eventId: string;
  initialSnapshot: PublicStandingsSnapshot;
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

export function LivePointsRace({
  eventId,
  initialSnapshot,
  supabaseClient,
  fetchStandings = fetchPublicStandings,
}: LivePointsRaceProps) {
  const [snapshotState, setSnapshotState] = useState({ eventId, snapshot: initialSnapshot });
  const [statusState, setStatusState] = useState<{
    eventId: string;
    status: "idle" | "refreshing" | "error";
  }>({ eventId, status: "idle" });
  const clientRef = useRef<SupabaseRealtimeClient | null>(supabaseClient ?? null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const realtimeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const snapshot =
    snapshotState.eventId === eventId ? snapshotState.snapshot : initialSnapshot;
  const status = statusState.eventId === eventId ? statusState.status : "idle";

  useEffect(() => {
    let isCurrentEvent = true;
    let client: SupabaseRealtimeClient;

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

      setSnapshotState({ eventId, snapshot: refreshedSnapshot });
      setStatusState({ eventId, status: "idle" });
    };

    const clearRealtimeTimer = () => {
      if (realtimeTimerRef.current) {
        clearTimeout(realtimeTimerRef.current);
        realtimeTimerRef.current = null;
      }
    };

    const scheduleRealtimeSnapshot = (streamedSnapshot: PublicStandingsSnapshot) => {
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
      .channel(`public-points-race:${eventId}`)
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

    channel.subscribe();
    startAutoRefresh();
    document.addEventListener("visibilitychange", handleVisibilityChange);

    return () => {
      isCurrentEvent = false;
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }
      clearRealtimeTimer();
      stopAutoRefresh();
      document.removeEventListener("visibilitychange", handleVisibilityChange);
      void client.removeChannel?.(channel);
    };
  }, [eventId, fetchStandings, initialSnapshot]);

  return (
    <>
      <PointsRaceChart
        eventTitle={snapshot.eventTitle}
        updatedAt={snapshot.updatedAt}
        pointsTimeline={snapshot.pointsTimeline}
      />
      {status === "refreshing" ? <p className="status-line">Refreshing points race...</p> : null}
      {status === "error" ? (
        <p className="status-line error">
          Live refresh could not update. Showing the latest points race we have.
        </p>
      ) : null}
    </>
  );
}
