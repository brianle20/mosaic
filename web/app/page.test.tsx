import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { metadata as layoutMetadata } from "./layout";
import LandingPage, { metadata as pageMetadata } from "./page";

describe("LandingPage", () => {
  it("keeps landing metadata on the root page instead of the shared layout", () => {
    expect(pageMetadata).toMatchObject({
      title: "Mosaic | Mahjong event software",
      description: "Host polished mahjong events with Mosaic.",
    });
    expect(layoutMetadata).toMatchObject({
      title: "Mosaic Live Standings",
      description: "Public tournament standings for Mosaic events.",
    });
  });

  it("renders the public landing page content and email calls to action", () => {
    render(<LandingPage />);

    expect(screen.getByRole("banner")).toHaveTextContent("Mosaic");
    expect(screen.getByRole("main")).toBeInTheDocument();
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
