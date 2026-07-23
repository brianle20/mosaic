"use client";

import { useEffect, useState } from "react";
import {
  getNotPrizeEligibleRows,
  getPrizePlacementRows,
  type PublicLeaderboardRow,
  type PublicPrizePlacementRow,
} from "../lib/public-standings";

export type ScoreChange = {
  pointsDelta: number;
};

export type ScoreChangeMap = Record<string, ScoreChange>;

type StandingsTableProps = {
  rows: PublicLeaderboardRow[];
  scoreChanges?: ScoreChangeMap;
};

export function StandingsTable({ rows, scoreChanges = {} }: StandingsTableProps) {
  if (rows.length === 0) {
    return (
      <section className="empty-state" aria-live="polite">
        <h2>No public tournament standings yet</h2>
        <p>Standings will appear once tournament hands are scored.</p>
      </section>
    );
  }

  const prizePlacementRows = getPrizePlacementRows(rows);
  const notPrizeEligibleRows = getNotPrizeEligibleRows(rows);

  return (
    <>
      <section aria-labelledby="prize-eligible-heading">
        <h2 id="prize-eligible-heading" className="section-heading">
          Prize eligible standings
        </h2>
        <LeaderboardTable rows={prizePlacementRows} scoreChanges={scoreChanges} />
      </section>
      {notPrizeEligibleRows.length > 0 ? (
        <section aria-labelledby="not-prize-eligible-heading">
          <h2 id="not-prize-eligible-heading" className="section-heading">
            Not prize eligible
          </h2>
          <LeaderboardTable
            rows={notPrizeEligibleRows.map((row) => ({ row, placement: null }))}
            scoreChanges={scoreChanges}
          />
        </section>
      ) : null}
    </>
  );
}

type LeaderboardTableProps = {
  rows: Array<PublicPrizePlacementRow | { row: PublicLeaderboardRow; placement: null }>;
  scoreChanges: ScoreChangeMap;
};

function LeaderboardTable({ rows, scoreChanges }: LeaderboardTableProps) {
  const [expandedRows, setExpandedRows] = useState<Set<string>>(new Set());
  const isMobileLayout = useIsMobileStandingsLayout();

  const toggleExpanded = (eventGuestId: string) => {
    setExpandedRows((currentRows) => {
      const nextRows = new Set(currentRows);

      if (nextRows.has(eventGuestId)) {
        nextRows.delete(eventGuestId);
      } else {
        nextRows.add(eventGuestId);
      }

      return nextRows;
    });
  };

  return (
    <>
      <div className="standings-table-wrap">
        <table className="standings-table">
          <thead>
            <tr>
              <th scope="col">Place</th>
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
                Discard wins
              </th>
              <th scope="col" className="numeric wide-only">
                Discard losses
              </th>
            </tr>
          </thead>
          <tbody>
            {rows.map(({ row, placement }) => {
              const isTopFour = placement !== null && placement <= 4;
              const pointsTone = getPointsTone(row.totalPoints);
              const scoreChange = scoreChanges[row.eventGuestId];
              const rowClassName = [
                isTopFour ? "top-four-row" : null,
              ]
                .filter(Boolean)
                .join(" ");
              const pointsClassName = [
                "numeric",
                "points-cell",
                pointsTone,
                scoreChange ? "points-has-change" : null,
              ]
                .filter(Boolean)
                .join(" ");

              return (
                <tr
                  key={row.eventGuestId}
                  className={rowClassName || undefined}
                >
                  <td className="rank-cell" data-label="Place">
                    {formatPlacement(placement)}
                  </td>
                  <td className="player-cell" data-label="Player">
                    {row.publicDisplayName}
                  </td>
                  <td
                    className={pointsClassName}
                    data-label="Points"
                  >
                    <span className="points-value">
                      {row.totalPoints.toLocaleString()}
                      <PointsDelta change={isMobileLayout ? undefined : scoreChange} />
                    </span>
                  </td>
                  <td
                    className="numeric stat-cell summary-stat-cell"
                    data-label="Hands"
                    data-short-label="Hands"
                    data-mobile-label="hands"
                  >
                    {row.handsPlayed}
                  </td>
                  <td
                    className="numeric stat-cell summary-stat-cell"
                    data-label="Wins"
                    data-short-label="Wins"
                    data-mobile-label="wins"
                  >
                    {row.wins}
                  </td>
                  <td
                    className="numeric wide-only stat-cell detail-stat-cell"
                    data-label="Self-draw"
                    data-short-label="Self"
                  >
                    {row.selfDrawWins}
                  </td>
                  <td
                    className="numeric wide-only stat-cell detail-stat-cell"
                    data-label="Discard wins"
                    data-short-label="Discard W"
                  >
                    {row.discardWins}
                  </td>
                  <td
                    className="numeric wide-only stat-cell detail-stat-cell"
                    data-label="Discard losses"
                    data-short-label="Discard L"
                  >
                    {row.discardLosses}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <MobileStandingsCards
        rows={rows}
        expandedRows={expandedRows}
        onToggleExpanded={toggleExpanded}
        scoreChanges={scoreChanges}
        showPointsDelta={isMobileLayout}
      />
    </>
  );
}

type MobileStandingsCardsProps = {
  rows: LeaderboardTableProps["rows"];
  expandedRows: Set<string>;
  onToggleExpanded: (eventGuestId: string) => void;
  scoreChanges: ScoreChangeMap;
  showPointsDelta: boolean;
};

function MobileStandingsCards({
  rows,
  expandedRows,
  onToggleExpanded,
  scoreChanges,
  showPointsDelta,
}: MobileStandingsCardsProps) {
  return (
    <div className="mobile-standings-cards" aria-label="Mobile standings">
      {rows.map(({ row, placement }) => {
        const isExpanded = expandedRows.has(row.eventGuestId);
        const isTopFour = placement !== null && placement <= 4;
        const scoreChange = scoreChanges[row.eventGuestId];
        const detailsId = `mobile-standings-details-${row.eventGuestId}`;
        const cardClassName = [
          "mobile-standings-card",
          isTopFour ? "top-four-mobile-card" : null,
          isExpanded ? "is-expanded" : null,
        ]
          .filter(Boolean)
          .join(" ");
        const mobilePointsClassName = [
          "mobile-card-points",
          getPointsTone(row.totalPoints),
          scoreChange ? "points-has-change" : null,
        ]
          .filter(Boolean)
          .join(" ");

        return (
          <article className={cardClassName} key={row.eventGuestId}>
            <button
              type="button"
              className="mobile-card-toggle"
              aria-expanded={isExpanded}
              aria-controls={detailsId}
              aria-label={`${isExpanded ? "Hide" : "Show"} details for ${
                row.publicDisplayName
              }`}
              onClick={() => onToggleExpanded(row.eventGuestId)}
            >
              <span className="mobile-card-rank">{formatPlacement(placement)}</span>
              <span className="mobile-card-name">{row.publicDisplayName}</span>
              <span className={mobilePointsClassName}>
                <span className="mobile-card-points-value">
                  {row.totalPoints.toLocaleString()}
                </span>
                <span className="mobile-card-points-label">points</span>
                <PointsDelta change={showPointsDelta ? scoreChange : undefined} />
              </span>
              <span className="mobile-card-summary">
                <strong>{row.handsPlayed}</strong> hands
                <span aria-hidden="true"> · </span>
                <strong>{row.wins}</strong> wins
              </span>
            </button>
            <div
              id={detailsId}
              className="mobile-card-details"
              aria-hidden={!isExpanded}
            >
              <div className="mobile-card-details-inner">
                <dl>
                  <div>
                    <dt>Self-draw</dt>
                    <dd>{row.selfDrawWins}</dd>
                  </div>
                  <div>
                    <dt>Discard wins</dt>
                    <dd>{row.discardWins}</dd>
                  </div>
                  <div>
                    <dt>Discard losses</dt>
                    <dd>{row.discardLosses}</dd>
                  </div>
                </dl>
              </div>
            </div>
          </article>
        );
      })}
    </div>
  );
}

function useIsMobileStandingsLayout() {
  const [isMobileLayout, setIsMobileLayout] = useState(false);

  useEffect(() => {
    if (typeof window === "undefined" || !window.matchMedia) {
      return;
    }

    const query = window.matchMedia("(max-width: 680px)");
    const updateIsMobileLayout = () => setIsMobileLayout(query.matches);

    updateIsMobileLayout();
    query.addEventListener("change", updateIsMobileLayout);

    return () => {
      query.removeEventListener("change", updateIsMobileLayout);
    };
  }, []);

  return isMobileLayout;
}

function PointsDelta({ change }: { change?: ScoreChange }) {
  if (!change || change.pointsDelta === 0) {
    return null;
  }

  const className = [
    "points-delta",
    change.pointsDelta > 0 ? "points-delta-positive" : "points-delta-negative",
  ].join(" ");

  return (
    <span className={className}>
      {change.pointsDelta > 0 ? "+" : ""}
      {change.pointsDelta.toLocaleString()}
    </span>
  );
}

function formatPlacement(placement: number | null) {
  return placement === null ? "N/A" : `#${placement}`;
}

function getPointsTone(totalPoints: number) {
  if (totalPoints > 0) {
    return "points-cell-positive";
  }

  if (totalPoints < 0) {
    return "points-cell-negative";
  }

  return "points-cell-neutral";
}
