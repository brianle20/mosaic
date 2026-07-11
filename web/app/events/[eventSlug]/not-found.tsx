import Link from "next/link";
import { PublicSiteHeader } from "../../../components/PublicSiteHeader";
import { PUBLIC_EVENTS_PATH, PUBLIC_HOME_PATH } from "../../../lib/public-routes";

export default function EventNotFound() {
  return (
    <div className="public-state-page">
      <PublicSiteHeader eventsLabel="All events" />
      <main id="main-content" className="public-state-card">
        <p className="eyebrow">Mosaic public event</p>
        <h1>This event isn&apos;t available.</h1>
        <p>It may have been archived, made private, or the shared link may be incorrect.</p>
        <div className="public-recovery-actions">
          <Link className="is-primary" href={PUBLIC_EVENTS_PATH}>
            Browse events
          </Link>
          <Link href={PUBLIC_HOME_PATH}>Mosaic home</Link>
        </div>
      </main>
    </div>
  );
}
