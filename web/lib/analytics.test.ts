import posthog from "posthog-js";
import { afterEach, describe, expect, it, vi } from "vitest";
import { captureAnalyticsEvent, initPostHog, resetAnalyticsForTest } from "./analytics";

vi.mock("posthog-js", () => ({
  default: {
    capture: vi.fn(),
    init: vi.fn(),
  },
}));

const originalEnv = process.env;

describe("analytics", () => {
  afterEach(() => {
    process.env = originalEnv;
    resetAnalyticsForTest();
    vi.clearAllMocks();
  });

  it("does not initialize PostHog without a public project token", () => {
    process.env = {
      ...originalEnv,
      NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN: "",
      NEXT_PUBLIC_POSTHOG_HOST: "",
    };

    expect(initPostHog()).toBe(false);
    expect(posthog.init).not.toHaveBeenCalled();
  });

  it("initializes product analytics, pageviews, and session replay when configured", () => {
    process.env = {
      ...originalEnv,
      NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN: "ph_project_token",
      NEXT_PUBLIC_POSTHOG_HOST: "https://us.i.posthog.com",
    };

    expect(initPostHog()).toBe(true);
    expect(posthog.init).toHaveBeenCalledWith("ph_project_token", {
      api_host: "https://us.i.posthog.com",
      capture_pageview: "history_change",
      defaults: "2026-01-30",
      disable_session_recording: false,
      mask_personal_data_properties: true,
      session_recording: {
        maskAllInputs: true,
      },
    });
  });

  it("captures named events only when analytics is configured", () => {
    process.env = {
      ...originalEnv,
      NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN: "ph_project_token",
    };

    captureAnalyticsEvent("sales_email_clicked", { location: "hero" });
    expect(posthog.capture).toHaveBeenCalledWith("sales_email_clicked", {
      location: "hero",
    });

    process.env = {
      ...originalEnv,
      NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN: "",
    };

    captureAnalyticsEvent("points_race_show_everyone_clicked", {
      event_slug: "fv-mahjong-1",
    });
    expect(posthog.capture).toHaveBeenCalledTimes(1);
  });
});
