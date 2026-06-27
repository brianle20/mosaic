import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
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
        standingsUpdatedAt: "2026-06-27T12:30:00.000Z",
      },
      {
        eventId: "event-2",
        publicSlug: "autumn-open",
        title: "Autumn Open",
        standingsUpdatedAt: null,
      },
    ]);

    render(await EventsPage());

    expect(mockedFetchPublicEvents).toHaveBeenCalledWith(publicClient);
    expect(screen.getByRole("heading", { level: 1, name: "Events" })).toBeInTheDocument();
    expect(screen.getByText("Summer Open")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Summer Open standings" })).toHaveAttribute(
      "href",
      "/events/summer-open/standings",
    );
    expect(screen.getByRole("link", { name: "Summer Open points race" })).toHaveAttribute(
      "href",
      "/events/summer-open/standings/graph",
    );
    expect(screen.getByText("Updated Jun 27, 2026, 12:30 PM UTC")).toBeInTheDocument();
    expect(screen.getByText("Autumn Open")).toBeInTheDocument();
    expect(screen.getByText("Standings update pending")).toBeInTheDocument();
  });

  it("skips events without usable public slugs", async () => {
    mockedFetchPublicEvents.mockResolvedValueOnce([
      {
        eventId: "event-1",
        publicSlug: "",
        title: "Broken Event",
        standingsUpdatedAt: null,
      },
      {
        eventId: "event-2",
        publicSlug: "valid-event",
        title: "Valid Event",
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
