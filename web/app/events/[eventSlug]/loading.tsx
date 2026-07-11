import { PublicSiteHeader } from "../../../components/PublicSiteHeader";

export default function EventLoading() {
  return (
    <div className="public-state-page" aria-busy="true">
      <PublicSiteHeader eventsLabel="All events" />
      <main id="main-content" className="standings-shell event-loading-shell">
        <p className="eyebrow">Mosaic public event</p>
        <h1>Loading event</h1>
        <div className="event-loading-block" aria-hidden="true" />
        <div className="event-loading-block is-wide" aria-hidden="true" />
      </main>
    </div>
  );
}
