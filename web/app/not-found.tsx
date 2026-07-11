import Link from "next/link";
import { PublicSiteHeader } from "../components/PublicSiteHeader";
import { PUBLIC_EVENTS_PATH, PUBLIC_HOME_PATH } from "../lib/public-routes";

export default function SiteNotFound() {
  return (
    <div className="public-state-page">
      <PublicSiteHeader />
      <main id="main-content" className="public-state-card">
        <p className="eyebrow">Mosaic</p>
        <h1>Page not found.</h1>
        <p>The page may have moved or the link may be incorrect.</p>
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
