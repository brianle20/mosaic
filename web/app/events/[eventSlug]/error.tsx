"use client";

import Link from "next/link";
import { PublicSiteHeader } from "../../../components/PublicSiteHeader";
import { PUBLIC_EVENTS_PATH } from "../../../lib/public-routes";

export default function EventError({ reset }: { error: Error; reset: () => void }) {
  return (
    <div className="public-state-page">
      <PublicSiteHeader eventsLabel="All events" />
      <main id="main-content" className="public-state-card" role="alert">
        <p className="eyebrow">Mosaic public event</p>
        <h1>We couldn&apos;t open this event.</h1>
        <p>Try loading it again, or return to the public event list.</p>
        <div className="public-recovery-actions">
          <button className="is-primary" type="button" onClick={reset}>
            Try again
          </button>
          <Link href={PUBLIC_EVENTS_PATH}>Browse events</Link>
        </div>
      </main>
    </div>
  );
}
