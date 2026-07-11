import { describe, expect, it } from "vitest";
import { formatPublicUpdatedAt } from "./public-time";

const NOW = Date.parse("2026-07-11T12:00:00.000Z");

describe("formatPublicUpdatedAt", () => {
  it("formats recent timestamps concisely", () => {
    expect(formatPublicUpdatedAt("2026-07-11T11:59:40.000Z", NOW)?.relative).toBe(
      "moments ago",
    );
    expect(formatPublicUpdatedAt("2026-07-11T11:55:00.000Z", NOW)?.relative).toBe(
      "5 min ago",
    );
    expect(formatPublicUpdatedAt("2026-07-11T10:00:00.000Z", NOW)?.relative).toBe(
      "2 hr ago",
    );
  });

  it("returns null for missing or invalid timestamps", () => {
    expect(formatPublicUpdatedAt(null, NOW)).toBeNull();
    expect(formatPublicUpdatedAt("not-a-date", NOW)).toBeNull();
  });
});
