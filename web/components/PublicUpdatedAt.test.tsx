import { act, render, screen } from "@testing-library/react";
import { renderToString } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import { PublicUpdatedAt } from "./PublicUpdatedAt";

const NOW = Date.parse("2026-07-11T12:00:00.000Z");

describe("PublicUpdatedAt", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("server-renders stable fallback copy", () => {
    expect(
      renderToString(
        <PublicUpdatedAt
          value="2026-07-11T11:55:00.000Z"
          pendingLabel="Standings update pending"
          prefix="Updated "
          now={NOW}
        />,
      ),
    ).toContain("Standings update pending");
  });

  it("hydrates to relative browser-local freshness", () => {
    render(
      <PublicUpdatedAt
        value="2026-07-11T11:55:00.000Z"
        pendingLabel="Standings update pending"
        prefix="Updated "
        now={NOW}
      />,
    );

    expect(screen.getByText("Updated 5 min ago")).toHaveAttribute(
      "datetime",
      "2026-07-11T11:55:00.000Z",
    );
  });

  it("uses the pending label for an invalid timestamp", () => {
    render(
      <PublicUpdatedAt
        value="not-a-date"
        pendingLabel="Standings update pending"
        prefix="Updated "
        now={NOW}
      />,
    );

    expect(screen.getByText("Standings update pending")).toBeVisible();
    expect(screen.queryByRole("time")).not.toBeInTheDocument();
  });

  it("refreshes relative freshness while mounted and stops the shared clock on cleanup", async () => {
    vi.useFakeTimers();
    vi.setSystemTime("2026-07-11T12:00:00.000Z");

    const { unmount } = render(
      <PublicUpdatedAt
        value="2026-07-11T11:59:20.000Z"
        pendingLabel="Standings update pending"
        prefix="Updated "
      />,
    );

    expect(screen.getByText("Updated moments ago")).toBeVisible();

    await act(async () => {
      vi.advanceTimersByTime(30_000);
    });

    expect(screen.getByText("Updated 1 min ago")).toBeVisible();
    expect(vi.getTimerCount()).toBe(1);

    unmount();

    expect(vi.getTimerCount()).toBe(0);
  });
});
