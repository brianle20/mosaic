import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { metadata as eventsMetadata } from "./events/page";
import { generateMetadata as generatePointsRaceMetadata } from "./events/[eventSlug]/standings/graph/page";
import { generateMetadata as generateStandingsMetadata } from "./events/[eventSlug]/standings/page";

describe("site metadata assets", () => {
  it("ships browser favicon and web manifest assets", () => {
    const favicon = readFileSync("public/favicon.ico");
    expect(favicon.subarray(0, 4)).toEqual(Buffer.from([0x00, 0x00, 0x01, 0x00]));

    const manifest = JSON.parse(readFileSync("public/site.webmanifest", "utf8"));
    expect(manifest).toMatchObject({
      name: "Mosaic",
      short_name: "Mosaic",
      start_url: "/",
      display: "standalone",
      background_color: "#f5f0e6",
      theme_color: "#007c7f",
      icons: [
        {
          src: "/mosaic-app-icon.png",
          sizes: "1024x1024",
          type: "image/png",
          purpose: "any maskable",
        },
      ],
    });
  });

  it("defines public events directory metadata", () => {
    expect(eventsMetadata).toMatchObject({
      title: "Events",
      description: "Public Mosaic mahjong event standings and points races.",
      alternates: {
        canonical: "/events",
      },
      openGraph: {
        title: "Events",
        description: "Public Mosaic mahjong event standings and points races.",
        url: "/events",
        siteName: "Mosaic",
        type: "website",
      },
      twitter: {
        card: "summary",
        title: "Events",
        description: "Public Mosaic mahjong event standings and points races.",
      },
    });
  });
});

describe("standings metadata", () => {
  it("uses live standings metadata instead of landing-page sales copy", async () => {
    await expect(
      generateStandingsMetadata({
        params: Promise.resolve({ eventSlug: "fv-mahjong-2-copy" }),
      }),
    ).resolves.toMatchObject({
      title: "FV Mahjong 2 Copy Live Standings",
      description: "Live mahjong standings for FV Mahjong 2 Copy.",
      alternates: {
        canonical: "/events/fv-mahjong-2-copy/standings",
      },
      openGraph: {
        title: "FV Mahjong 2 Copy Live Standings",
        description: "Live mahjong standings for FV Mahjong 2 Copy.",
        url: "/events/fv-mahjong-2-copy/standings",
        siteName: "Mosaic",
        type: "website",
      },
      twitter: {
        card: "summary",
        title: "FV Mahjong 2 Copy Live Standings",
        description: "Live mahjong standings for FV Mahjong 2 Copy.",
      },
    });
  });

  it("uses event-specific points race metadata", async () => {
    await expect(
      generatePointsRaceMetadata({
        params: Promise.resolve({ eventSlug: "fv-mahjong-1" }),
      }),
    ).resolves.toMatchObject({
      title: "FV Mahjong 1 Points Race",
      description: "Live cumulative points graph for FV Mahjong 1.",
      alternates: {
        canonical: "/events/fv-mahjong-1/standings/graph",
      },
      openGraph: {
        title: "FV Mahjong 1 Points Race",
        description: "Live cumulative points graph for FV Mahjong 1.",
        url: "/events/fv-mahjong-1/standings/graph",
        siteName: "Mosaic",
        type: "website",
      },
      twitter: {
        card: "summary",
        title: "FV Mahjong 1 Points Race",
        description: "Live cumulative points graph for FV Mahjong 1.",
      },
    });
  });
});
