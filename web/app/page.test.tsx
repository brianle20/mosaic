import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { metadata as layoutMetadata, viewport } from "./layout";
import LandingPage, { metadata as pageMetadata } from "./page";

describe("LandingPage", () => {
  it("keeps complete landing metadata on the root page instead of the shared layout", () => {
    expect(pageMetadata).toMatchObject({
      title: "Mosaic | Mahjong event software",
      description:
        "Host polished mahjong events with check-in, seating, scoring, standings, finals, and prizes in one calm tool.",
      alternates: { canonical: "/" },
      keywords: [
        "mahjong event software",
        "mahjong tournament software",
        "mahjong event management",
        "live mahjong standings",
      ],
      openGraph: {
        title: "Mosaic | Mahjong event software",
        description:
          "Host polished mahjong events with check-in, seating, scoring, standings, finals, and prizes in one calm tool.",
        url: "/",
        siteName: "Mosaic",
        type: "website",
        locale: "en_US",
        images: [
          {
            url: "/mosaic-app-icon.png",
            width: 1024,
            height: 1024,
            alt: "Mosaic app icon",
          },
        ],
      },
      twitter: {
        card: "summary",
        title: "Mosaic | Mahjong event software",
        description:
          "Host polished mahjong events with check-in, seating, scoring, standings, finals, and prizes in one calm tool.",
        images: ["/mosaic-app-icon.png"],
      },
    });
    expect(layoutMetadata).toMatchObject({
      applicationName: "Mosaic",
      metadataBase: new URL("https://mosaicmahjong.com"),
      title: {
        default: "Mosaic",
        template: "%s | Mosaic",
      },
      icons: {
        icon: [
          { url: "/favicon.ico", sizes: "32x32", type: "image/x-icon" },
          { url: "/mosaic-app-icon.png", sizes: "1024x1024", type: "image/png" },
        ],
        shortcut: [{ url: "/favicon.ico" }],
        apple: [
          { url: "/mosaic-app-icon.png", sizes: "1024x1024", type: "image/png" },
        ],
      },
      manifest: "/site.webmanifest",
      robots: {
        index: true,
        follow: true,
      },
    });
    expect(viewport).toMatchObject({
      themeColor: "#f5f0e6",
      colorScheme: "light",
    });
  });

  it("renders the public landing page content and email calls to action", () => {
    render(<LandingPage />);

    expect(screen.getByRole("banner")).toHaveTextContent("Mosaic");
    expect(screen.getByRole("link", { name: "Mosaic home" })).toHaveAttribute(
      "href",
      "/",
    );
    expect(screen.getByRole("link", { name: "Skip to content" })).toHaveAttribute(
      "href",
      "#main-content",
    );
    expect(screen.getByRole("link", { name: "Events" })).toHaveAttribute(
      "href",
      "/events",
    );
    expect(screen.getByRole("main")).toHaveAttribute("id", "main-content");
    expect(
      screen.getByRole("heading", {
        level: 1,
        name: "Host polished mahjong events.",
      }),
    ).toBeInTheDocument();
    expect(
      screen.getByText(
        "Check-in, seating, scoring, standings, finals, and prizes in one calm tool.",
      ),
    ).toBeInTheDocument();
    expect(screen.getByText("Mahjong event software")).toBeInTheDocument();
    expect(
      screen.getByText("For clubs, leagues, pop-ups, and private events."),
    ).toBeInTheDocument();

    const salesLinks = screen.getAllByRole("link", {
      name: /email sales|sales@mosaicmahjong\.com/i,
    });
    expect(salesLinks).toHaveLength(3);
    salesLinks.forEach((link) => {
      expect(link).toHaveAttribute("href", "mailto:sales@mosaicmahjong.com");
    });
  });

  it("shows the requested workflow and benefit sections without payment language", () => {
    const { container } = render(<LandingPage />);

    ["Check in", "Seat tables", "Score hands", "Publish standings"].forEach((label) => {
      expect(screen.getByText(label)).toBeInTheDocument();
    });

    expect(screen.getByText("Event-day control")).toBeInTheDocument();
    expect(screen.getByText("Keep guests, tables, and rounds moving.")).toBeInTheDocument();
    expect(screen.getByText("Live leaderboards")).toBeInTheDocument();
    expect(screen.getByText("Share standings as the room plays.")).toBeInTheDocument();
    expect(screen.getByText("Finals and prizes")).toBeInTheDocument();
    expect(screen.getByText("Close the event with clear results.")).toBeInTheDocument();
    expect(screen.getByText("Interested in Mosaic?")).toBeInTheDocument();

    expect(container).not.toHaveTextContent(/money|payout|payouts|payment|payments/i);
  });
});
