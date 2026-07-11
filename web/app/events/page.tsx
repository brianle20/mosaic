import type { Metadata } from "next";
import Link from "next/link";
import { PublicSiteHeader } from "../../components/PublicSiteHeader";
import { PublicUpdatedAt } from "../../components/PublicUpdatedAt";
import {
  publicEventPointsRacePath,
  publicEventStandingsPath,
} from "../../lib/public-routes";
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
      <PublicSiteHeader className="public-site-header" eventsCurrent />

      <main id="main-content" className="events-shell">
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
            {events.map((event) => (
              <article className="event-directory-card" key={event.eventId}>
                <div>
                  <h2>
                    <Link href={publicEventStandingsPath(event.publicSlug)}>
                      {event.title}
                    </Link>
                  </h2>
                  <p>
                    <PublicUpdatedAt
                      value={event.standingsUpdatedAt}
                      pendingLabel="Standings update pending"
                      prefix="Updated "
                    />
                  </p>
                </div>
                <div className="event-directory-actions">
                  <Link
                    className="is-primary"
                    href={publicEventStandingsPath(event.publicSlug)}
                    aria-label={`${event.title} standings`}
                  >
                    Standings
                  </Link>
                  <Link
                    href={publicEventPointsRacePath(event.publicSlug)}
                    aria-label={`${event.title} points race`}
                  >
                    Points Race
                  </Link>
                </div>
              </article>
            ))}
          </section>
        )}
      </main>
    </div>
  );
}
