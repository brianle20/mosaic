import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { StandingsTable } from "./StandingsTable";

describe("StandingsTable", () => {
  it("renders rank, public display name, total points, hands, and wins", () => {
    render(
      <StandingsTable
        rows={[
          {
            eventGuestId: "guest-1",
            publicDisplayName: "Brian L.",
            totalPoints: 42500,
            handsPlayed: 8,
            wins: 3,
            selfDrawWins: 1,
            discardWins: 2,
            rank: 1,
          },
        ]}
      />,
    );

    expect(screen.getByRole("columnheader", { name: /rank/i })).toBeVisible();
    expect(screen.getByText("Brian L.")).toBeVisible();
    expect(screen.getByText("42,500")).toBeVisible();
    expect(screen.getByText("8")).toBeVisible();
    expect(screen.getByText("3")).toBeVisible();
  });

  it("does not render hidden internal fields", () => {
    render(
      <StandingsTable
        rows={[
          {
            eventGuestId: "guest-2",
            publicDisplayName: "Alice C.",
            totalPoints: 12000,
            handsPlayed: 2,
            wins: 1,
            selfDrawWins: 0,
            discardWins: 1,
            rank: 2,
          },
        ]}
      />,
    );

    expect(screen.queryByText("Alice Chen")).not.toBeInTheDocument();
    expect(screen.queryByText("alice@example.com")).not.toBeInTheDocument();
    expect(screen.queryByText(/qualification/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/payment/i)).not.toBeInTheDocument();
  });

  it("shows an empty state when no standings exist", () => {
    render(<StandingsTable rows={[]} />);

    expect(screen.getByText(/no public tournament standings yet/i)).toBeVisible();
  });
});
