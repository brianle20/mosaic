import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

const refresh = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ refresh }),
}));

import { PublicLoadErrorBanner } from "./PublicLoadErrorBanner";

describe("PublicLoadErrorBanner", () => {
  it("offers retry and public-event recovery without backend details", () => {
    render(<PublicLoadErrorBanner />);

    expect(screen.getByRole("alert")).toHaveTextContent(
      "We couldn't load the latest public results.",
    );
    expect(screen.queryByText(/rpc|supabase|database|uuid/i)).not.toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Browse events" })).toHaveAttribute(
      "href",
      "/events",
    );

    fireEvent.click(screen.getByRole("button", { name: "Try again" }));
    expect(refresh).toHaveBeenCalledTimes(1);
  });
});
