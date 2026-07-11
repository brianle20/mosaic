"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { PUBLIC_EVENTS_PATH } from "../lib/public-routes";

export function PublicLoadErrorBanner() {
  const router = useRouter();

  return (
    <div className="load-error public-load-error" role="alert">
      <div>
        <strong>We couldn&apos;t load the latest public results.</strong>
        <p>Try again, or browse the other public Mosaic events.</p>
      </div>
      <div className="public-recovery-actions">
        <button type="button" onClick={() => router.refresh()}>
          Try again
        </button>
        <Link href={PUBLIC_EVENTS_PATH}>Browse events</Link>
      </div>
    </div>
  );
}
