import { render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { PublicEventShell } from "./PublicEventShell";

describe("PublicEventShell", () => {
  it("orients a direct-link standings visitor", () => {
    render(
      <PublicEventShell
        eventSlug="south-wind-6-copy"
        eventTitle="South Wind 6 Copy"
        updatedAt={null}
        activeView="standings"
      >
        <p>Standings content</p>
      </PublicEventShell>,
    );

    expect(screen.getByRole("heading", { level: 1, name: "South Wind 6 Copy" })).toBeVisible();
    expect(screen.getByRole("link", { name: "All events" })).toHaveAttribute("href", "/events");
    const eventNav = screen.getByRole("navigation", { name: "Event views" });
    expect(within(eventNav).getByRole("link", { name: "Standings" })).toHaveAttribute(
      "aria-current",
      "page",
    );
    expect(within(eventNav).getByRole("link", { name: "Points race" })).toHaveAttribute(
      "href",
      "/events/south-wind-6-copy/points-race",
    );
    expect(screen.getByRole("main")).toHaveAttribute("id", "main-content");
    expect(screen.getByText("Standings content")).toBeVisible();
  });

  it("keeps a long event title as complete visible page context", () => {
    const eventTitle =
      "South Wind Invitational Championship for the Greater Bay Mahjong Community";

    render(
      <PublicEventShell
        eventSlug="south-wind-invitational"
        eventTitle={eventTitle}
        updatedAt="not-a-date"
        activeView="points-race"
      >
        <p>Points race content</p>
      </PublicEventShell>,
    );

    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(eventTitle);
    expect(screen.getByText("Waiting for scores")).toBeVisible();
    expect(screen.getByRole("link", { name: "Points race" })).toHaveAttribute(
      "aria-current",
      "page",
    );
  });
});
