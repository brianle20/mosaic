import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import {
  fetchPublicEvents,
  type PublicEventDirectoryRow,
  type PublicStandingsClient,
} from "../../lib/public-standings";
import { publicEventMetadata } from "../../lib/public-metadata";
import { createPublicSupabaseClient } from "../../lib/supabase";

export const dynamic = "force-dynamic";

export const metadata: Metadata = publicEventMetadata({
  title: "Events",
  description: "Public Mosaic mahjong event standings and points races.",
  canonicalPath: "/events",
});

function formatUpdatedAt(value: string | null): string {
  if (!value) {
    return "Standings update pending";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "Standings update pending";
  }

  return `Updated ${new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZone: "UTC",
    timeZoneName: "short",
  }).format(date)}`;
}

function eventLinks(event: PublicEventDirectoryRow) {
  return {
    standings: `/events/${event.publicSlug}/standings`,
    pointsRace: `/events/${event.publicSlug}/standings/graph`,
  };
}

export default async function EventsPage() {
  let events: PublicEventDirectoryRow[] = [];
  let loadError: string | null = null;

  try {
    const publicClient = createPublicSupabaseClient() as unknown as PublicStandingsClient;
    events = (await fetchPublicEvents(publicClient)).filter(
      (event) => event.publicSlug.trim().length > 0,
    );
  } catch (error) {
    console.error(error);
    loadError = "Unable to load public events.";
  }

  return (
    <div className="events-page">
      <header className="landing-header public-site-header">
        <Link className="landing-brand" href="/" aria-label="Mosaic home">
          <Image src="/mosaic-app-icon.png" alt="" width={40} height={40} priority />
          <span>Mosaic</span>
        </Link>
        <nav className="public-nav" aria-label="Public navigation">
          <Link href="/events">Events</Link>
        </nav>
      </header>

      <main className="events-shell">
        <section className="events-hero" aria-labelledby="events-title">
          <p className="eyebrow">Public results</p>
          <h1 id="events-title">Events</h1>
          <p>Find live standings and points races for public Mosaic mahjong events.</p>
        </section>

        {loadError ? (
          <div className="load-error" role="alert">
            {loadError}
          </div>
        ) : null}

        {events.length === 0 ? (
          <section className="events-empty" aria-label="No public events">
            No public events are available.
          </section>
        ) : (
          <section className="events-list" aria-label="Public events">
            {events.map((event) => {
              const links = eventLinks(event);
              return (
                <article className="event-directory-card" key={event.eventId}>
                  <div>
                    <h2>{event.title}</h2>
                    <p>{formatUpdatedAt(event.standingsUpdatedAt)}</p>
                  </div>
                  <div className="event-directory-actions">
                    <Link href={links.standings} aria-label={`${event.title} standings`}>
                      Standings
                    </Link>
                    <Link href={links.pointsRace} aria-label={`${event.title} points race`}>
                      Points Race
                    </Link>
                  </div>
                </article>
              );
            })}
          </section>
        )}
      </main>
    </div>
  );
}
