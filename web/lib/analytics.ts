import posthog from "posthog-js";

export type AnalyticsEventName =
  | "sales_email_clicked"
  | "public_standings_viewed"
  | "points_race_viewed"
  | "points_race_show_everyone_clicked";

type AnalyticsProperties = Record<string, string | number | boolean | null>;

let initialized = false;

function postHogToken() {
  return process.env.NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN?.trim() ?? "";
}

function postHogHost() {
  return process.env.NEXT_PUBLIC_POSTHOG_HOST?.trim() || "https://us.i.posthog.com";
}

export function initPostHog() {
  const token = postHogToken();
  if (!token || initialized) {
    return false;
  }

  posthog.init(token, {
    api_host: postHogHost(),
    capture_pageview: "history_change",
    defaults: "2026-01-30",
    disable_session_recording: false,
    mask_personal_data_properties: true,
    session_recording: {
      maskAllInputs: true,
    },
  });
  initialized = true;
  return true;
}

export function captureAnalyticsEvent(
  eventName: AnalyticsEventName,
  properties: AnalyticsProperties = {},
) {
  if (!postHogToken()) {
    return;
  }

  posthog.capture(eventName, properties);
}

export function resetAnalyticsForTest() {
  initialized = false;
}
