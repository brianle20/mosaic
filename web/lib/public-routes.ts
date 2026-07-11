export const PUBLIC_HOME_PATH = "/";
export const PUBLIC_EVENTS_PATH = "/events";

export function publicEventStandingsPath(eventSlug: string): string {
  return `/events/${eventSlug}/standings`;
}

export function publicEventPointsRacePath(eventSlug: string): string {
  return `/events/${eventSlug}/points-race`;
}
