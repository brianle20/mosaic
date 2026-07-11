import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { LivePointsRace } from "../../../../components/LivePointsRace";
import {
  fetchPublicStandings,
  isPublicEventUnavailableError,
  type PublicStandingsClient,
  type PublicStandingsSnapshot,
} from "../../../../lib/public-standings";
import { eventTitleFromSlug, publicEventMetadata } from "../../../../lib/public-metadata";
import { publicEventPointsRacePath } from "../../../../lib/public-routes";
import { createPublicSupabaseClient } from "../../../../lib/supabase";

type PointsRacePageProps = {
  params: Promise<{ eventSlug: string }>;
};

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: PointsRacePageProps): Promise<Metadata> {
  const { eventSlug } = await params;
  const eventTitle = eventTitleFromSlug(eventSlug);

  return publicEventMetadata({
    title: `${eventTitle} Points Race`,
    description: `Live cumulative points graph for ${eventTitle}.`,
    canonicalPath: publicEventPointsRacePath(eventSlug),
  });
}

export default async function PointsRacePage({ params }: PointsRacePageProps) {
  const { eventSlug } = await params;
  let initialSnapshot: PublicStandingsSnapshot;
  let initialLoadFailed = false;

  try {
    const publicClient = createPublicSupabaseClient() as unknown as PublicStandingsClient;
    initialSnapshot = await fetchPublicStandings(publicClient, eventSlug);
  } catch (error) {
    if (isPublicEventUnavailableError(error)) {
      notFound();
    }

    initialSnapshot = {
      eventId: eventSlug,
      eventSlug,
      eventTitle: eventTitleFromSlug(eventSlug) || "Mosaic tournament",
      leaderboard: [],
      bonusResults: [],
      pointsTimeline: [],
      updatedAt: null,
    };
    initialLoadFailed = true;
  }

  return (
    <LivePointsRace
      eventId={initialSnapshot.eventId ?? eventSlug}
      eventSlug={eventSlug}
      initialSnapshot={initialSnapshot}
      initialLoadFailed={initialLoadFailed}
    />
  );
}
