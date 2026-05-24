import { LiveStandings } from "../../../../components/LiveStandings";
import {
  fetchPublicStandings,
  type PublicStandingsClient,
} from "../../../../lib/public-standings";
import { createPublicSupabaseClient } from "../../../../lib/supabase";

type StandingsPageProps = {
  params: Promise<{ eventId: string }>;
};

export const dynamic = "force-dynamic";

export default async function StandingsPage({ params }: StandingsPageProps) {
  const { eventId } = await params;
  let initialSnapshot;
  let loadError: string | null = null;

  try {
    const publicClient = createPublicSupabaseClient() as unknown as PublicStandingsClient;
    initialSnapshot = await fetchPublicStandings(publicClient, eventId);
  } catch (error) {
    initialSnapshot = {
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
      <LiveStandings eventId={eventId} initialSnapshot={initialSnapshot} />
    </>
  );
}
