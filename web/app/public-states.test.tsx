import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import EventError from "./events/[eventSlug]/error";
import EventLoading from "./events/[eventSlug]/loading";
import EventNotFound from "./events/[eventSlug]/not-found";
import SiteNotFound from "./not-found";

describe("public recovery states", () => {
  it("provides event-not-found recovery", () => {
    render(<EventNotFound />);
    expect(
      screen.getByRole("heading", { name: "This event isn't available." }),
    ).toBeVisible();
    expect(screen.getByRole("link", { name: "Browse events" })).toHaveAttribute(
      "href",
      "/events",
    );
    expect(
      within(screen.getByRole("main")).getByRole("link", { name: "Mosaic home" }),
    ).toHaveAttribute(
      "href",
      "/",
    );
  });

  it("keeps loading and general 404 states branded", () => {
    const { rerender } = render(<EventLoading />);
    expect(screen.getByRole("heading", { name: "Loading event" })).toBeVisible();
    rerender(<SiteNotFound />);
    expect(screen.getByRole("heading", { name: "Page not found." })).toBeVisible();
  });

  it("retries an unexpected render failure", () => {
    const reset = vi.fn();
    render(<EventError error={new Error("private backend detail")} reset={reset} />);
    expect(screen.queryByText("private backend detail")).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Try again" }));
    expect(reset).toHaveBeenCalledTimes(1);
  });
});
