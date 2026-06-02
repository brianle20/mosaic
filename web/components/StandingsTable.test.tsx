import { fireEvent, render, screen } from "@testing-library/react";
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
            discardLosses: 4,
            rank: 1,
          },
        ]}
      />,
    );

    expect(screen.getByRole("columnheader", { name: /place/i })).toBeVisible();
    expect(screen.getAllByText("Brian L.")[0]).toBeVisible();
    expect(screen.getAllByText("42,500")[0]).toBeVisible();
    expect(screen.getAllByText("8")[0]).toBeVisible();
    expect(screen.getAllByText("3")[0]).toBeVisible();
    expect(screen.getByRole("columnheader", { name: /discard wins/i })).toBeVisible();
    expect(screen.getByRole("columnheader", { name: /discard losses/i })).toBeVisible();
  });

  it("splits prize eligible rows from low-hand rows using competition placement", () => {
    const { container } = render(
      <StandingsTable
        rows={[
          {
            eventGuestId: "guest-1",
            publicDisplayName: "Alice C.",
            totalPoints: 40,
            handsPlayed: 4,
            wins: 2,
            selfDrawWins: 1,
            discardWins: 1,
            discardLosses: 0,
            rank: 1,
          },
          {
            eventGuestId: "guest-2",
            publicDisplayName: "Brian L.",
            totalPoints: 40,
            handsPlayed: 4,
            wins: 2,
            selfDrawWins: 0,
            discardWins: 2,
            discardLosses: 1,
            rank: 1,
          },
          {
            eventGuestId: "guest-3",
            publicDisplayName: "Chris N.",
            totalPoints: 8,
            handsPlayed: 4,
            wins: 1,
            selfDrawWins: 0,
            discardWins: 1,
            discardLosses: 2,
            rank: 3,
          },
          {
            eventGuestId: "guest-4",
            publicDisplayName: "Dana K.",
            totalPoints: 200,
            handsPlayed: 1,
            wins: 1,
            selfDrawWins: 1,
            discardWins: 0,
            discardLosses: 0,
            rank: 4,
          },
        ]}
      />,
    );

    expect(screen.getByText(/minimum hands for prize eligibility: 2/i)).toBeVisible();
    expect(screen.getByRole("heading", { name: /prize eligible standings/i })).toBeVisible();
    expect(screen.getByRole("heading", { name: /not prize eligible/i })).toBeVisible();
    expect(
      Array.from(container.querySelectorAll(".standings-table .rank-cell")).map((cell) =>
        cell.textContent?.trim(),
      ),
    ).toEqual(["#1", "#1", "#3", "N/A"]);
    expect(screen.getAllByText("#3")[0]).toBeVisible();
    expect(screen.getAllByText("Dana K.")[0]).toBeVisible();
  });

  it("renders withdrawn players in the not prize eligible section", () => {
    const { container } = render(
      <StandingsTable
        rows={[
          {
            eventGuestId: "guest-1",
            publicDisplayName: "Alice C.",
            tournamentStatus: "qualified",
            totalPoints: 40,
            handsPlayed: 8,
            wins: 2,
            selfDrawWins: 1,
            discardWins: 1,
            discardLosses: 0,
            rank: 1,
          },
          {
            eventGuestId: "guest-2",
            publicDisplayName: "Brian L.",
            tournamentStatus: "withdrawn",
            totalPoints: 64,
            handsPlayed: 8,
            wins: 3,
            selfDrawWins: 1,
            discardWins: 2,
            discardLosses: 1,
            rank: 2,
          },
        ]}
      />,
    );

    expect(screen.getByRole("heading", { name: /prize eligible standings/i })).toBeVisible();
    expect(screen.getByRole("heading", { name: /not prize eligible/i })).toBeVisible();
    expect(screen.getAllByText("Alice C.")[0]).toBeVisible();
    expect(screen.getAllByText("Brian L.")[0]).toBeVisible();
    expect(
      Array.from(container.querySelectorAll(".standings-table .rank-cell")).map((cell) =>
        cell.textContent?.trim(),
      ),
    ).toEqual(["#1", "N/A"]);
  });

  it("marks top-four prize placements for visual emphasis", () => {
    render(
      <StandingsTable
        rows={[
          {
            eventGuestId: "guest-1",
            publicDisplayName: "Alice C.",
            totalPoints: 80,
            handsPlayed: 4,
            wins: 2,
            selfDrawWins: 1,
            discardWins: 1,
            discardLosses: 0,
            rank: 1,
          },
          {
            eventGuestId: "guest-2",
            publicDisplayName: "Brian L.",
            totalPoints: 40,
            handsPlayed: 4,
            wins: 1,
            selfDrawWins: 0,
            discardWins: 1,
            discardLosses: 1,
            rank: 2,
          },
          {
            eventGuestId: "guest-3",
            publicDisplayName: "Chris N.",
            totalPoints: 8,
            handsPlayed: 4,
            wins: 1,
            selfDrawWins: 0,
            discardWins: 1,
            discardLosses: 2,
            rank: 3,
          },
          {
            eventGuestId: "guest-4",
            publicDisplayName: "Dana K.",
            totalPoints: 4,
            handsPlayed: 4,
            wins: 1,
            selfDrawWins: 1,
            discardWins: 0,
            discardLosses: 0,
            rank: 4,
          },
          {
            eventGuestId: "guest-5",
            publicDisplayName: "Evan S.",
            totalPoints: 0,
            handsPlayed: 4,
            wins: 0,
            selfDrawWins: 0,
            discardWins: 0,
            discardLosses: 2,
            rank: 5,
          },
        ]}
      />,
    );

    for (const name of ["Alice C.", "Brian L.", "Chris N.", "Dana K."]) {
      expect(screen.getAllByText(name)[0].closest("tr")).toHaveClass("top-four-row");
    }
    expect(screen.getAllByText("Evan S.")[0].closest("tr")).not.toHaveClass("top-four-row");
  });

  it("adds cell labels for mobile card layout", () => {
    render(
      <StandingsTable
        rows={[
          {
            eventGuestId: "guest-1",
            publicDisplayName: "Brian L.",
            totalPoints: 12000,
            handsPlayed: 2,
            wins: 1,
            selfDrawWins: 0,
            discardWins: 1,
            discardLosses: 0,
            rank: 1,
          },
        ]}
      />,
    );

    expect(screen.getAllByText("Brian L.")[0].closest("td")).toHaveAttribute(
      "data-label",
      "Player",
    );
    expect(screen.getAllByText("12,000")[0].closest("td")).toHaveAttribute(
      "data-label",
      "Points",
    );
    expect(screen.getAllByText("#1")[0].closest("td")).toHaveAttribute("data-label", "Place");
  });

  it("marks points as the primary positive or negative score", () => {
    render(
      <StandingsTable
        rows={[
          {
            eventGuestId: "guest-1",
            publicDisplayName: "Brian L.",
            totalPoints: 12000,
            handsPlayed: 4,
            wins: 2,
            selfDrawWins: 1,
            discardWins: 1,
            discardLosses: 0,
            rank: 1,
          },
          {
            eventGuestId: "guest-2",
            publicDisplayName: "Alice C.",
            totalPoints: -8000,
            handsPlayed: 4,
            wins: 0,
            selfDrawWins: 0,
            discardWins: 0,
            discardLosses: 2,
            rank: 2,
          },
        ]}
      />,
    );

    expect(screen.getAllByText("12,000")[0].closest("td")).toHaveClass(
      "points-cell",
      "points-cell-positive",
    );
    expect(screen.getAllByText("-8,000")[0].closest("td")).toHaveClass(
      "points-cell",
      "points-cell-negative",
    );
  });

  it("marks secondary stats for the compact mobile stat grid", () => {
    const { container } = render(
      <StandingsTable
        rows={[
          {
            eventGuestId: "guest-1",
            publicDisplayName: "Brian L.",
            totalPoints: 12000,
            handsPlayed: 4,
            wins: 2,
            selfDrawWins: 1,
            discardWins: 1,
            discardLosses: 0,
            rank: 1,
          },
        ]}
      />,
    );

    for (const label of [
      "Hands",
      "Wins",
      "Self-draw",
      "Discard wins",
      "Discard losses",
    ]) {
      expect(container.querySelector(`td[data-label="${label}"]`)).toHaveClass("stat-cell");
    }
    expect(container.querySelector('td[data-label="Discard wins"]')).toHaveAttribute(
      "data-short-label",
      "Discard W",
    );
    expect(container.querySelector('td[data-label="Discard losses"]')).toHaveAttribute(
      "data-short-label",
      "Discard L",
    );
    expect(container.querySelector('td[data-label="Hands"]')).toHaveClass("summary-stat-cell");
    expect(container.querySelector('td[data-label="Wins"]')).toHaveClass("summary-stat-cell");
    expect(container.querySelector('td[data-label="Self-draw"]')).toHaveClass("detail-stat-cell");
    expect(container.querySelector('td[data-label="Discard wins"]')).toHaveClass(
      "detail-stat-cell",
    );
    expect(container.querySelector('td[data-label="Discard losses"]')).toHaveClass(
      "detail-stat-cell",
    );
  });

  it("expands and collapses extra mobile stats per player", () => {
    render(
      <StandingsTable
        rows={[
          {
            eventGuestId: "guest-1",
            publicDisplayName: "Brian L.",
            totalPoints: 12000,
            handsPlayed: 4,
            wins: 2,
            selfDrawWins: 1,
            discardWins: 1,
            discardLosses: 0,
            rank: 1,
          },
        ]}
      />,
    );

    const toggle = screen.getByRole("button", { name: "Show details for Brian L." });
    const card = toggle.closest("article");
    const details = card?.querySelector(".mobile-card-details");

    expect(toggle).toHaveAttribute("aria-expanded", "false");
    expect(card).not.toHaveClass("is-expanded");
    expect(details).toHaveAttribute("aria-hidden", "true");

    fireEvent.click(toggle);

    expect(toggle).toHaveAttribute("aria-expanded", "true");
    expect(toggle).toHaveAccessibleName("Hide details for Brian L.");
    expect(card).toHaveClass("is-expanded");
    expect(details).toHaveAttribute("aria-hidden", "false");

    fireEvent.click(toggle);

    expect(toggle).toHaveAttribute("aria-expanded", "false");
    expect(card).not.toHaveClass("is-expanded");
    expect(details).toHaveAttribute("aria-hidden", "true");
  });

  it("renders mobile points with a small label and no extra disclosure icon", () => {
    const { container } = render(
      <StandingsTable
        rows={[
          {
            eventGuestId: "guest-1",
            publicDisplayName: "Brian L.",
            totalPoints: -12000,
            handsPlayed: 4,
            wins: 2,
            selfDrawWins: 1,
            discardWins: 1,
            discardLosses: 0,
            rank: 1,
          },
        ]}
      />,
    );

    const mobilePoints = container.querySelector(".mobile-card-points");

    expect(mobilePoints).toHaveClass("points-cell-negative");
    expect(mobilePoints?.querySelector(".mobile-card-points-value")).toHaveTextContent(
      "-12,000",
    );
    expect(mobilePoints?.querySelector(".mobile-card-points-label")).toHaveTextContent(
      "points",
    );
    expect(container.querySelector(".mobile-card-icon")).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Show details for Brian L." })).toBeVisible();
  });

  it("marks changed scores and shows a short points delta on desktop and mobile", () => {
    const { container } = render(
      <StandingsTable
        rows={[
          {
            eventGuestId: "guest-1",
            publicDisplayName: "Brian L.",
            totalPoints: 12000,
            handsPlayed: 4,
            wins: 2,
            selfDrawWins: 1,
            discardWins: 1,
            discardLosses: 0,
            rank: 1,
          },
        ]}
        scoreChanges={{ "guest-1": { pointsDelta: 384 } }}
      />,
    );

    expect(screen.getByText("+384")).toBeVisible();
    expect(screen.getByText("+384")).toHaveClass(
      "points-delta",
      "points-delta-positive",
    );
    expect(container.querySelector(".standings-table tbody tr")).not.toHaveClass(
      "is-live-updated",
    );
    expect(container.querySelector(".points-cell")).toHaveClass(
      "points-has-change",
    );
    expect(container.querySelector(".mobile-standings-card")).not.toHaveClass(
      "is-live-updated",
    );
    expect(container.querySelector(".mobile-card-points")).toHaveClass(
      "points-has-change",
    );
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
            discardLosses: 0,
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
