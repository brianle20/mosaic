"use client";

import { useEffect, useRef, useState } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { PointsRaceChart } from "./PointsRaceChart";
import { PublicEventShell } from "./PublicEventShell";
import { PublicLoadErrorBanner } from "./PublicLoadErrorBanner";
import {
  fetchPublicStandings,
  mapPublicStandingsSnapshotPayload,
  type PublicStandingsClient,
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

type LivePointsRaceProps = {
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
  eventSlug,
  initialSnapshot,
  initialLoadFailed = false,
  supabaseClient,
  fetchStandings = fetchPublicStandings,
}: LivePointsRaceProps) {
  const [snapshotState, setSnapshotState] = useState({ eventId, snapshot: initialSnapshot });
  const [statusState, setStatusState] = useState<{
    eventId: string;
    status: "idle" | "refreshing" | "error";
  }>({ eventId, status: "idle" });
  const [realtimeIdentityState, setRealtimeIdentityState] = useState({
    eventId,
    realtimeEventId: eventId,
  });
  const [initialLoadFailureState, setInitialLoadFailureState] = useState({
    eventId,
    failed: initialLoadFailed,
  });
  const clientRef = useRef<SupabaseRealtimeClient | null>(supabaseClient ?? null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const realtimeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const snapshot =
    snapshotState.eventId === eventId ? snapshotState.snapshot : initialSnapshot;
  const status = statusState.eventId === eventId ? statusState.status : "idle";
  const realtimeEventId =
    realtimeIdentityState.eventId === eventId
      ? realtimeIdentityState.realtimeEventId
      : eventId;
  const initialLoadFailure =
    initialLoadFailureState.eventId === eventId
      ? initialLoadFailureState.failed
      : initialLoadFailed;

  useEffect(() => {
    if (eventSlug) {
      captureAnalyticsEvent("points_race_viewed", { event_slug: eventSlug });
    }
  }, [eventSlug]);

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
      setInitialLoadFailureState({ eventId, failed: false });
      if (refreshedSnapshot.eventId) {
        setRealtimeIdentityState({
          eventId,
          realtimeEventId: refreshedSnapshot.eventId,
        });
      }
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
          const refreshedSnapshot = await fetchStandings(client, realtimeEventId);
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
      .channel(`public-points-race:${realtimeEventId}`)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: REALTIME_SNAPSHOT_TABLE },
        (payload) => {
          if (!payloadMatchesEvent(payload, realtimeEventId)) {
            return;
          }

          const streamedSnapshot = snapshotFromRealtimePayload(payload);
          if (streamedSnapshot) {
            scheduleRealtimeSnapshot(streamedSnapshot);
          }
        },
      );

    channel.subscribe((subscriptionStatus) => {
      if (isCurrentEvent && subscriptionStatus === "SUBSCRIBED") {
        setStatusState((current) =>
          current.eventId === eventId && current.status === "error"
            ? { eventId, status: "idle" }
            : current,
        );
      }
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
      stopAutoRefresh();
      document.removeEventListener("visibilitychange", handleVisibilityChange);
      void client.removeChannel?.(channel);
    };
  }, [
    eventId,
    fetchStandings,
    initialSnapshot,
    realtimeEventId,
  ]);

  return (
    <PublicEventShell
      eventSlug={eventSlug}
      eventTitle={snapshot.eventTitle}
      updatedAt={snapshot.updatedAt}
      activeView="points-race"
    >
      {initialLoadFailure ? <PublicLoadErrorBanner /> : null}

      <PointsRaceChart
        eventSlug={eventSlug}
        eventTitle={snapshot.eventTitle}
        pointsTimeline={snapshot.pointsTimeline}
      />
      {status === "refreshing" ? <p className="status-line">Refreshing points race...</p> : null}
      {status === "error" ? (
        <p className="status-line error">
          Live refresh could not update. Showing the latest points race we have.
        </p>
      ) : null}
    </PublicEventShell>
  );
}
