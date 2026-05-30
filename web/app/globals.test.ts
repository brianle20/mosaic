import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const css = readFileSync("app/globals.css", "utf8");

describe("standings table readability styles", () => {
  it("keeps table headers sticky while rows scroll", () => {
    expect(css).toMatch(/\.standings-table th\s*\{[\s\S]*position:\s*sticky/);
    expect(css).toMatch(/\.standings-table th\s*\{[\s\S]*top:\s*0/);
    expect(css).toMatch(/\.standings-table th\s*\{[\s\S]*z-index:\s*1/);
    expect(css).toMatch(/--table-header:\s*#e4ebe7/);
    expect(css).toMatch(/\.standings-table th\s*\{[\s\S]*background:\s*var\(--table-header\)/);
    expect(css).toMatch(/\.standings-table th\s*\{[\s\S]*box-shadow:/);
  });

  it("adds subtle row striping and hover affordance", () => {
    expect(css).toMatch(/\.standings-table tbody tr:nth-child\(even\)/);
    expect(css).toMatch(/\.standings-table tbody tr:hover/);
  });

  it("keeps the page header compact for live standings", () => {
    expect(css).toMatch(/\.standings-shell\s*\{[\s\S]*padding:\s*28px 0 52px/);
    expect(css).toMatch(/\.standings-header\s*\{[\s\S]*align-items:\s*center/);
    expect(css).toMatch(/\.standings-header\s*\{[\s\S]*margin-bottom:\s*18px/);
    expect(css).toMatch(/\.standings-header h1\s*\{[\s\S]*font-size:\s*clamp\(1\.8rem,\s*4vw,\s*3\.2rem\)/);
  });

  it("styles top-four rows as a restrained highlight", () => {
    expect(css).toMatch(/\.standings-table tbody tr\.top-four-row/);
    expect(css).toMatch(/\.top-four-row \.rank-cell/);
    expect(css).toMatch(/\.mobile-card-rank\s*\{[\s\S]*color:\s*var\(--accent-strong\)/);
    expect(css).toMatch(/\.top-four-mobile-card \.mobile-card-rank\s*\{[\s\S]*color:\s*color-mix\(in srgb,\s*var\(--gold\)/);
  });

  it("makes points the most prominent numeric score", () => {
    expect(css).toMatch(/\.points-cell\s*\{[\s\S]*font-size:\s*1\.08rem/);
    expect(css).toMatch(/\.points-cell\s*\{[\s\S]*font-weight:\s*800/);
    expect(css).toMatch(/\.points-cell-positive\s*\{[\s\S]*color:\s*var\(--accent-strong\)/);
    expect(css).toMatch(/\.points-cell-negative\s*\{[\s\S]*color:\s*var\(--danger\)/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-points\s*\{[\s\S]*font-size:\s*1\.2rem/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-points\.points-cell-negative\s*\{[\s\S]*color:\s*var\(--danger\)/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-points-label\s*\{[\s\S]*font-size:\s*0\.62rem/);
  });

  it("switches standings tables to mobile cards", () => {
    expect(css).toMatch(/\.mobile-standings-cards\s*\{[\s\S]*display:\s*none/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.standings-table-wrap\s*\{[\s\S]*display:\s*none/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-standings-cards\s*\{[\s\S]*display:\s*grid/);
  });

  it("uses a compact scoreboard layout for mobile cards", () => {
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.updated-at\s*\{[\s\S]*padding:\s*8px 10px/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-toggle\s*\{[\s\S]*grid-template-columns:\s*auto minmax\(0,\s*1fr\) auto/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-toggle\s*\{[\s\S]*padding:\s*12px 14px/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-rank\s*\{[\s\S]*grid-row:\s*1 \/ 3/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-rank\s*\{[\s\S]*font-size:\s*1\.24rem/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-points\s*\{[\s\S]*grid-row:\s*1 \/ 3/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-summary\s*\{[\s\S]*grid-column:\s*2/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-points\s*\{[\s\S]*justify-self:\s*end/);
    expect(css).not.toMatch(/\.mobile-card-icon/);
  });

  it("keeps extra mobile stats collapsed until a row is expanded", () => {
    expect(css).toMatch(/\.mobile-card-details\s*\{[\s\S]*grid-template-rows:\s*0fr/);
    expect(css).toMatch(/\.mobile-card-details\s*\{[\s\S]*transition:/);
    expect(css).toMatch(/\.mobile-standings-card\.is-expanded \.mobile-card-details\s*\{[\s\S]*grid-template-rows:\s*1fr/);
    expect(css).toMatch(/@media \(prefers-reduced-motion:\s*reduce\)/);
  });

  it("animates changed standings subtly and respects reduced motion", () => {
    expect(css).not.toMatch(/\.is-live-updated\s*\{[\s\S]*animation:/);
    expect(css).toMatch(/@keyframes points-value-pulse/);
    expect(css).toMatch(/@keyframes points-delta-float/);
    expect(css).toMatch(/\.points-has-change\s*\{[\s\S]*animation:\s*points-value-pulse/);
    expect(css).toMatch(/\.points-delta\s*\{[\s\S]*position:\s*absolute/);
    expect(css).toMatch(/\.points-delta\s*\{[\s\S]*animation:\s*points-delta-float/);
    expect(css).toMatch(/\.points-delta-positive\s*\{[\s\S]*color:\s*var\(--accent-strong\)/);
    expect(css).toMatch(/\.points-delta-negative\s*\{[\s\S]*color:\s*var\(--danger\)/);
    expect(css).toMatch(/@media \(prefers-reduced-motion:\s*reduce\)\s*\{[\s\S]*\.points-has-change/);
    expect(css).toMatch(/@media \(prefers-reduced-motion:\s*reduce\)\s*\{[\s\S]*\.points-delta/);
    expect(css).toMatch(/@media \(prefers-reduced-motion:\s*reduce\)\s*\{[\s\S]*animation:\s*none/);
  });

  it("aligns expanded mobile stats in a label and numeric value grid", () => {
    expect(css).toMatch(/\.mobile-card-details-inner\s*\{[\s\S]*min-height:\s*0/);
    expect(css).toMatch(/\.mobile-card-details-inner\s*\{[\s\S]*overflow:\s*hidden/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-details dl\s*\{[\s\S]*grid-template-columns:\s*max-content minmax\(2ch,\s*auto\)/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-details dl\s*\{[\s\S]*align-items:\s*baseline/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-details dl > div\s*\{[\s\S]*display:\s*contents/);
    expect(css).not.toMatch(/\.mobile-card-details div\s*\{[\s\S]*display:\s*contents/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-details dt\s*\{[\s\S]*text-align:\s*left/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-details dt\s*\{[\s\S]*line-height:\s*1/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-details dd\s*\{[\s\S]*text-align:\s*right/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-details dd\s*\{[\s\S]*line-height:\s*1/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.mobile-card-details dd\s*\{[\s\S]*font-variant-numeric:\s*tabular-nums/);
  });
});

describe("landing page styles", () => {
  it("keeps the hero headline wrapping until wide desktop widths", () => {
    expect(css).toMatch(/\.landing-hero h1\s*\{[\s\S]*white-space:\s*normal/);
    expect(css).toMatch(/@media \(min-width:\s*1200px\)\s*\{[\s\S]*\.landing-hero h1\s*\{[\s\S]*font-size:\s*clamp\(3\.65rem,\s*4\.3vw,\s*4\.5rem\)/);
    expect(css).toMatch(/@media \(min-width:\s*1200px\)\s*\{[\s\S]*\.landing-hero h1\s*\{[\s\S]*white-space:\s*nowrap/);
    expect(css).not.toMatch(/@media \(max-width:\s*1023px\)\s*\{[\s\S]*\.landing-hero h1\s*\{[\s\S]*white-space:\s*normal/);
  });

  it("uses the real icon as a restrained watermark accent", () => {
    expect(css).toMatch(/\.landing-hero::after\s*\{[\s\S]*background-image:\s*url\("\/mosaic-app-icon\.png"\)/);
    expect(css).toMatch(/\.landing-hero::after\s*\{[\s\S]*opacity:\s*0\.07/);
  });

  it("hides the header email link on mobile", () => {
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.landing-header-email\s*\{[\s\S]*display:\s*none/);
  });

  it("switches the workflow strip to two columns on mobile", () => {
    expect(css).toMatch(/\.workflow-strip\s*\{[\s\S]*grid-template-columns:\s*repeat\(4,\s*minmax\(0,\s*1fr\)\)/);
    expect(css).toMatch(/@media \(max-width:\s*680px\)\s*\{[\s\S]*\.workflow-strip\s*\{[\s\S]*grid-template-columns:\s*repeat\(2,\s*minmax\(0,\s*1fr\)\)/);
  });
});
