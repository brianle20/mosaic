import type { Metadata } from "next";
import { LiveStandings } from "../../../../components/LiveStandings";
import {
  fetchPublicStandings,
  type PublicStandingsClient,
} from "../../../../lib/public-standings";
import { createPublicSupabaseClient } from "../../../../lib/supabase";

type StandingsPageProps = {
  params: Promise<{ eventSlug: string }>;
};

export const dynamic = "force-dynamic";

export async function generateMetadata({ params }: StandingsPageProps): Promise<Metadata> {
  const { eventSlug } = await params;
  const canonicalPath = `/events/${eventSlug}/standings`;
  const title = "Mosaic Live Standings";
  const description = "Live mahjong standings for this Mosaic event.";

  return {
    title,
    description,
    alternates: {
      canonical: canonicalPath,
    },
    openGraph: {
      title,
      description,
      url: canonicalPath,
      siteName: "Mosaic",
      type: "website",
      images: [
        {
          url: "/mosaic-app-icon.png",
          width: 1024,
          height: 1024,
          alt: "Mosaic app icon",
        },
      ],
    },
    twitter: {
      card: "summary",
      title,
      description,
      images: ["/mosaic-app-icon.png"],
    },
  };
}

export default async function StandingsPage({ params }: StandingsPageProps) {
  const { eventSlug } = await params;
  let initialSnapshot;
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
      <LiveStandings
        eventId={initialSnapshot.eventId ?? eventSlug}
        initialSnapshot={initialSnapshot}
      />
    </>
  );
}
