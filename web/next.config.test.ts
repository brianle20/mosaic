import { describe, expect, it } from "vitest";

import nextConfig from "./next.config";

describe("Next.js redirects", () => {
  it("permanently redirects the legacy standings graph route", async () => {
    const redirects = await nextConfig.redirects?.();

    expect(redirects).toContainEqual({
      source: "/events/:eventSlug/standings/graph",
      destination: "/events/:eventSlug/points-race",
      permanent: true,
    });
  });
});
