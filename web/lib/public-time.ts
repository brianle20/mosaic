export type FormattedPublicUpdatedAt = {
  dateTime: string;
  exact: string;
  relative: string;
};

export function formatPublicUpdatedAt(
  value: string | null,
  now = Date.now(),
): FormattedPublicUpdatedAt | null {
  if (!value) {
    return null;
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return null;
  }

  const elapsedMs = Math.max(0, now - date.getTime());
  const elapsedMinutes = Math.floor(elapsedMs / 60_000);
  const elapsedHours = Math.floor(elapsedMs / 3_600_000);
  const exact = new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(date);

  const relative =
    elapsedMinutes < 1
      ? "moments ago"
      : elapsedMinutes < 60
        ? `${elapsedMinutes} min ago`
        : elapsedHours < 24
          ? `${elapsedHours} hr ago`
          : exact;

  return {
    dateTime: date.toISOString(),
    exact: `Updated ${exact}`,
    relative,
  };
}
