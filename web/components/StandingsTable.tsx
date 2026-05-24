import type { PublicLeaderboardRow } from "../lib/public-standings";

type StandingsTableProps = {
  rows: PublicLeaderboardRow[];
};

export function StandingsTable({ rows }: StandingsTableProps) {
  if (rows.length === 0) {
    return (
      <section className="empty-state" aria-live="polite">
        <h2>No public tournament standings yet</h2>
        <p>Standings will appear once tournament hands are scored.</p>
      </section>
    );
  }

  return (
    <div className="standings-table-wrap">
      <table className="standings-table">
        <thead>
          <tr>
            <th scope="col">Rank</th>
            <th scope="col">Player</th>
            <th scope="col" className="numeric">
              Points
            </th>
            <th scope="col" className="numeric">
              Hands
            </th>
            <th scope="col" className="numeric">
              Wins
            </th>
            <th scope="col" className="numeric wide-only">
              Self-draw
            </th>
            <th scope="col" className="numeric wide-only">
              Discard
            </th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.eventGuestId}>
              <td className="rank-cell">#{row.rank}</td>
              <td className="player-cell">{row.publicDisplayName}</td>
              <td className="numeric">{row.totalPoints.toLocaleString()}</td>
              <td className="numeric">{row.handsPlayed}</td>
              <td className="numeric">{row.wins}</td>
              <td className="numeric wide-only">{row.selfDrawWins}</td>
              <td className="numeric wide-only">{row.discardWins}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
