"use client";

import type { AnchorHTMLAttributes, ReactNode } from "react";
import { captureAnalyticsEvent } from "../lib/analytics";

const salesEmail = "sales@mosaicmahjong.com";
const salesHref = `mailto:${salesEmail}`;

type SalesEmailLinkProps = Omit<AnchorHTMLAttributes<HTMLAnchorElement>, "href"> & {
  children: ReactNode;
  location: "header" | "hero" | "closing";
};

export function SalesEmailLink({
  children,
  location,
  onClick,
  ...anchorProps
}: SalesEmailLinkProps) {
  return (
    <a
      {...anchorProps}
      href={salesHref}
      onClick={(event) => {
        captureAnalyticsEvent("sales_email_clicked", { location });
        onClick?.(event);
      }}
    >
      {children}
    </a>
  );
}
