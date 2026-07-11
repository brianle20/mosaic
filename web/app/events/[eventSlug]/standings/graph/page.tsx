import { permanentRedirect } from "next/navigation";
import { publicEventPointsRacePath } from "../../../../../lib/public-routes";

type LegacyPointsRacePageProps = {
  params: Promise<{ eventSlug: string }>;
};

export default async function LegacyPointsRacePage({
  params,
}: LegacyPointsRacePageProps) {
  const { eventSlug } = await params;
  permanentRedirect(publicEventPointsRacePath(eventSlug));
}
