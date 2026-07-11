import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { LiveStandings } from "../../../../components/LiveStandings";
import {
  fetchPublicStandings,
  isPublicEventUnavailableError,
  type PublicStandingsClient,
  type PublicStandingsSnapshot,
} from "../../../../lib/public-standings";
import { eventTitleFromSlug, publicEventMetadata } from "../../../../lib/public-metadata";
import { publicEventStandingsPath } from "../../../../lib/public-routes";
import { createPublicSupabaseClient } from "../../../../lib/supabase";

type StandingsPageProps = {
  params: Promise<{ eventSlug: string }>;
};

export const dynamic = "force-dynamic";

export async function generateMetadata({ params }: StandingsPageProps): Promise<Metadata> {
  const { eventSlug } = await params;
  const canonicalPath = publicEventStandingsPath(eventSlug);
  const eventTitle = eventTitleFromSlug(eventSlug);
  const title = `${eventTitle} Live Standings`;
  const description = `Live mahjong standings for ${eventTitle}.`;

  return publicEventMetadata({
    title,
    description,
    canonicalPath,
  });
}

export default async function StandingsPage({ params }: StandingsPageProps) {
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
    <LiveStandings
      eventId={initialSnapshot.eventId ?? eventSlug}
      eventSlug={eventSlug}
      initialSnapshot={initialSnapshot}
      initialLoadFailed={initialLoadFailed}
    />
  );
}
