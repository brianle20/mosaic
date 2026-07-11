import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { PublicSiteHeader } from "./PublicSiteHeader";

describe("PublicSiteHeader", () => {
  it("provides Home, Events, and skip navigation", () => {
    render(<PublicSiteHeader eventsCurrent />);

    expect(screen.getByRole("link", { name: "Mosaic home" })).toHaveAttribute("href", "/");
    expect(screen.getByRole("link", { name: "Events" })).toHaveAttribute(
      "aria-current",
      "page",
    );
    expect(screen.getByRole("link", { name: "Skip to content" })).toHaveAttribute(
      "href",
      "#main-content",
    );
  });
});
