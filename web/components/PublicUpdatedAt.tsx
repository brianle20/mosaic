"use client";

import { useSyncExternalStore } from "react";
import {
  getPublicClockServerSnapshot,
  getPublicClockSnapshot,
  subscribeToPublicClock,
} from "../lib/public-clock";
import { formatPublicUpdatedAt } from "../lib/public-time";

const subscribeToHydration = () => () => {};

type PublicUpdatedAtProps = {
  value: string | null;
  pendingLabel: string;
  prefix?: string;
  now?: number;
};

export function PublicUpdatedAt({
  value,
  pendingLabel,
  prefix = "",
  now,
}: PublicUpdatedAtProps) {
  const currentTime = useSyncExternalStore(
    now === undefined ? subscribeToPublicClock : subscribeToHydration,
    now === undefined ? getPublicClockSnapshot : () => now,
    getPublicClockServerSnapshot,
  );
  const formatted =
    currentTime === null ? null : formatPublicUpdatedAt(value, currentTime);
  if (!formatted) {
    return <span>{pendingLabel}</span>;
  }

  return (
    <time dateTime={formatted.dateTime} title={formatted.exact}>
      {prefix}
      {formatted.relative}
    </time>
  );
}
