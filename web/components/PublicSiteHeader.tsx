import Image from "next/image";
import Link from "next/link";
import type { ReactNode } from "react";
import { PUBLIC_EVENTS_PATH, PUBLIC_HOME_PATH } from "../lib/public-routes";

export type PublicSiteHeaderProps = {
  className?: string;
  navClassName?: string;
  eventsCurrent?: boolean;
  eventsLabel?: string;
  children?: ReactNode;
};

export function PublicSiteHeader({
  className,
  navClassName,
  eventsCurrent = false,
  eventsLabel = "Events",
  children,
}: PublicSiteHeaderProps) {
  return (
    <header className={["landing-header", className].filter(Boolean).join(" ")}>
      <a className="skip-link" href="#main-content">
        Skip to content
      </a>
      <Link className="landing-brand" href={PUBLIC_HOME_PATH} aria-label="Mosaic home">
        <Image src="/mosaic-app-icon.png" alt="" width={40} height={40} priority />
        <span>Mosaic</span>
      </Link>
      <nav
        className={["public-nav", navClassName].filter(Boolean).join(" ")}
        aria-label="Public navigation"
      >
        <Link href={PUBLIC_EVENTS_PATH} aria-current={eventsCurrent ? "page" : undefined}>
          {eventsLabel}
        </Link>
        {children}
      </nav>
    </header>
  );
}
