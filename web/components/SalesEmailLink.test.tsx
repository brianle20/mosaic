import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { captureAnalyticsEvent } from "../lib/analytics";
import { SalesEmailLink } from "./SalesEmailLink";

vi.mock("../lib/analytics", () => ({
  captureAnalyticsEvent: vi.fn(),
}));

describe("SalesEmailLink", () => {
  it("keeps the mailto link and captures sales intent", () => {
    render(
      <SalesEmailLink
        className="landing-primary-link"
        location="hero"
        onClick={(event) => event.preventDefault()}
      >
        Email sales
      </SalesEmailLink>,
    );

    const link = screen.getByRole("link", { name: /email sales/i });
    expect(link).toHaveAttribute("href", "mailto:sales@mosaicmahjong.com");

    fireEvent.click(link);

    expect(captureAnalyticsEvent).toHaveBeenCalledWith("sales_email_clicked", {
      location: "hero",
    });
  });
});
