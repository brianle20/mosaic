"use client";

import { useSyncExternalStore } from "react";
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
  const hydrated = useSyncExternalStore(
    subscribeToHydration,
    () => true,
    () => false,
  );
  const formatted = hydrated ? formatPublicUpdatedAt(value, now) : null;
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
