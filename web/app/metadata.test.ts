import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { generateMetadata } from "./events/[eventSlug]/standings/page";

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
});

describe("standings metadata", () => {
  it("uses live standings metadata instead of landing-page sales copy", async () => {
    await expect(
      generateMetadata({
        params: Promise.resolve({ eventSlug: "fv-mahjong-2-copy" }),
      }),
    ).resolves.toMatchObject({
      title: "Mosaic Live Standings",
      description: "Live mahjong standings for this Mosaic event.",
      alternates: {
        canonical: "/events/fv-mahjong-2-copy/standings",
      },
      openGraph: {
        title: "Mosaic Live Standings",
        description: "Live mahjong standings for this Mosaic event.",
        url: "/events/fv-mahjong-2-copy/standings",
        siteName: "Mosaic",
        type: "website",
      },
      twitter: {
        card: "summary",
        title: "Mosaic Live Standings",
        description: "Live mahjong standings for this Mosaic event.",
      },
    });
  });
});
