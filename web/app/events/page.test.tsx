import { render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import EventsPage, { metadata } from "./page";

vi.mock("../../lib/supabase", () => ({
  createPublicSupabaseClient: vi.fn(),
}));

vi.mock("../../lib/public-standings", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../../lib/public-standings")>();
  return {
    ...actual,
    fetchPublicEvents: vi.fn(),
  };
});

import { fetchPublicEvents } from "../../lib/public-standings";
import { createPublicSupabaseClient } from "../../lib/supabase";

const mockedFetchPublicEvents = vi.mocked(fetchPublicEvents);
const mockedCreatePublicSupabaseClient = vi.mocked(createPublicSupabaseClient);

describe("EventsPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockedCreatePublicSupabaseClient.mockReturnValue({ rpc: vi.fn() } as never);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("defines public events metadata", () => {
    expect(metadata).toMatchObject({
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

  it("renders public event links from public slugs", async () => {
    const publicClient = { rpc: vi.fn() };
    mockedCreatePublicSupabaseClient.mockReturnValueOnce(publicClient as never);
    mockedFetchPublicEvents.mockResolvedValueOnce([
      {
        eventId: "event-1",
        publicSlug: "summer-open",
        title: "Summer Open",
        startsAt: "2026-07-23T02:00:00.000Z",
        timezone: "America/Los_Angeles",
        standingsUpdatedAt: "2026-06-27T12:30:00.000Z",
      },
      {
        eventId: "event-2",
        publicSlug: "autumn-open",
        title: "Autumn Open",
        startsAt: "2026-10-16T00:30:00.000Z",
        timezone: "America/New_York",
        standingsUpdatedAt: null,
      },
    ]);

    render(await EventsPage());

    expect(mockedFetchPublicEvents).toHaveBeenCalledWith(publicClient);
    expect(screen.getByRole("heading", { level: 1, name: "Events" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Summer Open" })).toHaveAttribute(
      "href",
      "/events/summer-open/standings",
    );
    expect(screen.getByRole("link", { name: "Summer Open standings" })).toHaveClass(
      "is-primary",
    );
    expect(screen.getByRole("link", { name: "Summer Open points race" })).toHaveAttribute(
      "href",
      "/events/summer-open/points-race",
    );
    expect(screen.getByText("Jul 22, 2026 · 7:00 PM PDT")).toHaveAttribute(
      "datetime",
      "2026-07-23T02:00:00.000Z",
    );
    expect(
      screen.getByText("Last hand recorded Jun 27, 2026 · 5:30 AM PDT"),
    ).toHaveAttribute("datetime", "2026-06-27T12:30:00.000Z");
    expect(screen.getByText("Autumn Open")).toBeInTheDocument();
    expect(screen.getByText("Standings update pending")).toBeInTheDocument();
  });

  it("skips events without usable public slugs", async () => {
    mockedFetchPublicEvents.mockResolvedValueOnce([
      {
        eventId: "event-1",
        publicSlug: "",
        title: "Broken Event",
        startsAt: null,
        timezone: null,
        standingsUpdatedAt: null,
      },
      {
        eventId: "event-2",
        publicSlug: "valid-event",
        title: "Valid Event",
        startsAt: null,
        timezone: null,
        standingsUpdatedAt: null,
      },
    ]);

    render(await EventsPage());

    expect(screen.queryByText("Broken Event")).not.toBeInTheDocument();
    expect(screen.getByText("Valid Event")).toBeInTheDocument();
  });

  it("renders an empty state when no public events are available", async () => {
    mockedFetchPublicEvents.mockResolvedValueOnce([]);

    render(await EventsPage());

    expect(screen.getByText("No public events are available.")).toBeInTheDocument();
  });

  it("renders an alert when public events fail to load", async () => {
    mockedFetchPublicEvents.mockRejectedValueOnce(new Error("directory unavailable"));

    render(await EventsPage());

    expect(screen.getByRole("alert")).toHaveTextContent("Unable to load public events.");
    expect(screen.queryByText("directory unavailable")).not.toBeInTheDocument();
    expect(screen.getByText("No public events are available.")).toBeInTheDocument();
  });
});
