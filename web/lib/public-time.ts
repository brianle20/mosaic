export type FormattedPublicUpdatedAt = {
  dateTime: string;
  exact: string;
  relative: string;
};

export type FormattedPublicEventDateTime = {
  dateTime: string;
  label: string;
};

export function formatPublicEventDateTime(
  value: string | null,
  timeZone: string | null,
): FormattedPublicEventDateTime | null {
  if (!value || !timeZone) {
    return null;
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return null;
  }

  try {
    const formattedDate = new Intl.DateTimeFormat("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
      timeZone,
    }).format(date);
    const formattedTime = new Intl.DateTimeFormat("en-US", {
      hour: "numeric",
      minute: "2-digit",
      timeZone,
      timeZoneName: "short",
    }).format(date);

    return {
      dateTime: date.toISOString(),
      label: `${formattedDate} · ${formattedTime}`,
    };
  } catch (error) {
    if (error instanceof RangeError) {
      return null;
    }
    throw error;
  }
}

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
