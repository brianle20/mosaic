import Link from "next/link";
import type { ReactNode } from "react";
import {
  publicEventPointsRacePath,
  publicEventStandingsPath,
} from "../lib/public-routes";
import { PublicSiteHeader } from "./PublicSiteHeader";
import { PublicUpdatedAt } from "./PublicUpdatedAt";

export type PublicEventView = "standings" | "points-race";

type PublicEventShellProps = {
  eventSlug: string;
  eventTitle: string;
  updatedAt: string | null;
  activeView: PublicEventView;
  children: ReactNode;
};

export function PublicEventShell({
  eventSlug,
  eventTitle,
  updatedAt,
  activeView,
  children,
}: PublicEventShellProps) {
  const mainClassName = [
    "standings-shell",
    activeView === "points-race" ? "points-race-shell" : null,
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <div className="public-event-page">
      <PublicSiteHeader className="public-event-site-header" eventsLabel="All events" />
      <main id="main-content" className={mainClassName}>
        <header className="standings-header">
          <div>
            <p className="eyebrow">Live tournament</p>
            <h1>{eventTitle}</h1>
          </div>
          <div className="updated-at">
            <span>Last updated</span>
            <PublicUpdatedAt value={updatedAt} pendingLabel="Waiting for scores" />
          </div>
        </header>
        <nav className="event-view-nav" aria-label="Event views">
          <Link
            href={publicEventStandingsPath(eventSlug)}
            aria-current={activeView === "standings" ? "page" : undefined}
          >
            Standings
          </Link>
          <Link
            href={publicEventPointsRacePath(eventSlug)}
            aria-current={activeView === "points-race" ? "page" : undefined}
          >
            Points race
          </Link>
        </nav>
        {children}
      </main>
    </div>
  );
}
