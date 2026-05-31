import type { Metadata } from "next";
import { LivePointsRace } from "../../../../../components/LivePointsRace";
import {
  fetchPublicStandings,
  type PublicStandingsClient,
  type PublicStandingsSnapshot,
} from "../../../../../lib/public-standings";
import { eventTitleFromSlug, publicEventMetadata } from "../../../../../lib/public-metadata";
import { createPublicSupabaseClient } from "../../../../../lib/supabase";

type PointsRacePageProps = {
  params: Promise<{ eventSlug: string }>;
};

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: PointsRacePageProps): Promise<Metadata> {
  const { eventSlug } = await params;
  const canonicalPath = `/events/${eventSlug}/standings/graph`;
  const eventTitle = eventTitleFromSlug(eventSlug);
  const title = `${eventTitle} Points Race`;
  const description = `Live cumulative points graph for ${eventTitle}.`;

  return publicEventMetadata({
    title,
    description,
    canonicalPath,
  });
}

export default async function PointsRacePage({ params }: PointsRacePageProps) {
  const { eventSlug } = await params;
  let initialSnapshot: PublicStandingsSnapshot;
  let loadError: string | null = null;

  try {
    const publicClient = createPublicSupabaseClient() as unknown as PublicStandingsClient;
    initialSnapshot = await fetchPublicStandings(publicClient, eventSlug);
  } catch (error) {
    initialSnapshot = {
      eventId: eventSlug,
      eventSlug,
      eventTitle: "Mosaic tournament",
      leaderboard: [],
      bonusResults: [],
      pointsTimeline: [],
      updatedAt: null,
    };
    loadError = error instanceof Error ? error.message : "Unable to load public standings.";
  }

  return (
    <>
      {loadError ? (
        <div className="load-error" role="alert">
          {loadError}
        </div>
      ) : null}
      <LivePointsRace
        eventId={initialSnapshot.eventId ?? eventSlug}
        eventSlug={eventSlug}
        initialSnapshot={initialSnapshot}
      />
    </>
  );
}
