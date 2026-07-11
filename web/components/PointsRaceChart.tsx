"use client";

import { useId, useMemo, useState, useSyncExternalStore } from "react";
import { captureAnalyticsEvent } from "../lib/analytics";

export type PointsTimelinePlayer = {
  eventGuestId: string;
  publicDisplayName: string;
  totalPoints: number;
  rank?: number | null;
};

export type PointsTimelineHand = {
  handNumber?: number | null;
  handLabel?: string | null;
  completedAt?: string | null;
  players: PointsTimelinePlayer[];
};

type PointsRaceChartProps = {
  eventSlug?: string;
  eventTitle: string;
  pointsTimeline?: PointsTimelineHand[];
};

type PlayerSeries = {
  id: string;
  name: string;
  rank: number;
  latestPoints: number;
  values: Array<number | null>;
};

const DESKTOP_VISIBLE_PLAYERS = 12;
const MOBILE_VISIBLE_PLAYERS = 8;
const MOBILE_QUERY = "(max-width: 680px)";

type ChartGeometry = {
  width: number;
  height: number;
  padding: {
    top: number;
    right: number;
    bottom: number;
    left: number;
  };
};

const DESKTOP_CHART: ChartGeometry = {
  width: 960,
  height: 420,
  padding: { top: 30, right: 38, bottom: 44, left: 72 },
};

const MOBILE_CHART: ChartGeometry = {
  width: 480,
  height: 420,
  padding: { top: 30, right: 24, bottom: 44, left: 60 },
};
const LINE_COLORS = [
  "#006c67",
  "#d85f45",
  "#b98521",
  "#17211e",
  "#2d8f86",
  "#a44732",
  "#d1a33a",
  "#4f5d58",
  "#0f7f78",
  "#c9702f",
  "#8f6a14",
  "#36534d",
];

function useVisiblePlayerLimit() {
  return useSyncExternalStore(
    (onStoreChange) => {
      if (typeof window === "undefined") {
        return () => {};
      }

      const mediaQuery = window.matchMedia?.(MOBILE_QUERY);
      if (!mediaQuery) {
        return () => {};
      }

      mediaQuery.addEventListener?.("change", onStoreChange);
      return () => {
        mediaQuery.removeEventListener?.("change", onStoreChange);
      };
    },
    () => {
      if (typeof window === "undefined") {
        return null;
      }

      const mediaQuery = window.matchMedia?.(MOBILE_QUERY);
      if (!mediaQuery) {
        return DESKTOP_VISIBLE_PLAYERS;
      }

      return mediaQuery.matches ? MOBILE_VISIBLE_PLAYERS : DESKTOP_VISIBLE_PLAYERS;
    },
    () => null,
  );
}

function signedPoints(points: number) {
  if (points > 0) {
    return `+${points.toLocaleString()}`;
  }

  return points.toLocaleString();
}

function handLabel(hand: PointsTimelineHand, index: number) {
  if (hand.handLabel) {
    return hand.handLabel;
  }

  if (typeof hand.handNumber === "number") {
    return `Hand ${hand.handNumber}`;
  }

  return `Hand ${index + 1}`;
}

function buildSeries(pointsTimeline: PointsTimelineHand[]) {
  const seriesByPlayer = new Map<string, PlayerSeries>();

  pointsTimeline.forEach((hand, handIndex) => {
    hand.players.forEach((player) => {
      const existing = seriesByPlayer.get(player.eventGuestId);
      const series =
        existing ??
        {
          id: player.eventGuestId,
          name: player.publicDisplayName,
          rank: Number.MAX_SAFE_INTEGER,
          latestPoints: 0,
          values: Array(pointsTimeline.length).fill(null),
        };

      series.name = player.publicDisplayName || series.name;
      series.rank = Number(player.rank ?? series.rank);
      series.latestPoints = Number(player.totalPoints ?? 0);
      series.values[handIndex] = Number(player.totalPoints ?? 0);
      seriesByPlayer.set(player.eventGuestId, series);
    });
  });

  return Array.from(seriesByPlayer.values()).sort((left, right) => {
    const rankCompare = left.rank - right.rank;
    if (rankCompare !== 0) {
      return rankCompare;
    }

    const pointsCompare = right.latestPoints - left.latestPoints;
    if (pointsCompare !== 0) {
      return pointsCompare;
    }

    return left.name.localeCompare(right.name);
  });
}

function getBiggestSwing(series: PlayerSeries[]) {
  let biggestSwing = 0;
  let playerName = "No swings yet";

  series.forEach((player) => {
    let previousValue: number | null = null;
    player.values.forEach((value) => {
      if (value === null) {
        return;
      }

      if (previousValue !== null) {
        const swing = Math.abs(value - previousValue);
        if (swing > biggestSwing) {
          biggestSwing = swing;
          playerName = player.name;
        }
      }

      previousValue = value;
    });
  });

  return { playerName, points: biggestSwing };
}

function getPathForSeries(
  series: PlayerSeries,
  minPoints: number,
  maxPoints: number,
  geometry: ChartGeometry,
) {
  const plotWidth = geometry.width - geometry.padding.left - geometry.padding.right;
  const plotHeight = geometry.height - geometry.padding.top - geometry.padding.bottom;
  const pointRange = Math.max(1, maxPoints - minPoints);
  const xStep = series.values.length > 1 ? plotWidth / (series.values.length - 1) : 0;
  const points = series.values
    .map((value, index) => {
      if (value === null) {
        return null;
      }

      const x = geometry.padding.left + xStep * index;
      const y =
        geometry.padding.top +
        plotHeight -
        ((value - minPoints) / pointRange) * plotHeight;
      return { x, y };
    })
    .filter((point): point is { x: number; y: number } => point !== null);

  return {
    path: points
      .map((point, index) => `${index === 0 ? "M" : "L"} ${point.x.toFixed(1)} ${point.y.toFixed(1)}`)
      .join(" "),
    latestPoint: points.at(-1) ?? null,
  };
}

function lineClassName(
  index: number,
  isDefaultVisible: boolean,
  isSpotlighted: boolean,
  hasSpotlight: boolean,
) {
  return [
    "points-race-line",
    index < 4 ? "is-top-line" : null,
    !isDefaultVisible ? "is-muted-line" : null,
    hasSpotlight && !isSpotlighted ? "is-dimmed" : null,
    isSpotlighted ? "is-spotlighted" : null,
  ]
    .filter(Boolean)
    .join(" ");
}

export function PointsRaceChart({
  eventSlug,
  eventTitle,
  pointsTimeline = [],
}: PointsRaceChartProps) {
  const chartTitleId = useId();
  const chartDescriptionId = useId();
  const visibleLimit = useVisiblePlayerLimit();
  const [showEveryone, setShowEveryone] = useState(false);
  const [spotlightedPlayerId, setSpotlightedPlayerId] = useState<string | null>(null);
  const series = useMemo(() => buildSeries(pointsTimeline), [pointsTimeline]);
  const isViewportReady = visibleLimit !== null;
  const visibleSeries =
    isViewportReady && showEveryone
      ? series
      : isViewportReady
        ? series.slice(0, visibleLimit)
        : [];
  const leader = series[0];
  const biggestSwing = getBiggestSwing(series);
  const domainSeries = visibleSeries.length > 0 ? visibleSeries : series;
  const allValues = domainSeries.flatMap((player) =>
    player.values.filter((value): value is number => value !== null),
  );
  const rawMin = Math.min(...allValues, 0);
  const rawMax = Math.max(...allValues, 0);
  const yPadding = Math.max(100, Math.round((rawMax - rawMin) * 0.12));
  const minPoints = rawMin - yPadding;
  const maxPoints = rawMax + yPadding;
  const geometry =
    visibleLimit === MOBILE_VISIBLE_PLAYERS ? MOBILE_CHART : DESKTOP_CHART;
  const gridLines = Array.from({ length: 5 }, (_, index) => {
    const ratio = index / 4;
    const y =
      geometry.padding.top +
      (geometry.height - geometry.padding.top - geometry.padding.bottom) * ratio;
    const value = maxPoints - (maxPoints - minPoints) * ratio;
    return { y, value };
  });

  if (pointsTimeline.length === 0 || series.length === 0) {
    return (
      <>
        <section className="points-race-stats" aria-label="Points race stats">
          <div className="points-race-stat">
            <span>Leader</span>
            <strong>Waiting</strong>
          </div>
          <div className="points-race-stat">
            <span>Biggest swing</span>
            <strong>0</strong>
          </div>
          <div className="points-race-stat">
            <span>Hands recorded</span>
            <strong>0</strong>
          </div>
        </section>
        <section className="empty-state points-race-empty" aria-live="polite">
          <h2>No points race data yet</h2>
          <p>Points race will appear once scored hands arrive.</p>
        </section>
      </>
    );
  }

  if (!isViewportReady) {
    return (
      <>
        <section className="points-race-stats" aria-label="Points race stats">
          <div className="points-race-stat">
            <span>Leader</span>
            <strong>{leader.name}</strong>
            <small>{signedPoints(leader.latestPoints)}</small>
          </div>
          <div className="points-race-stat">
            <span>Biggest swing</span>
            <strong>{signedPoints(biggestSwing.points)}</strong>
            <small>{biggestSwing.playerName}</small>
          </div>
          <div className="points-race-stat">
            <span>Hands recorded</span>
            <strong>{pointsTimeline.length.toLocaleString()}</strong>
          </div>
        </section>

        <section className="empty-state points-race-empty" aria-live="polite">
          <h2>Preparing points race</h2>
          <p>The graph will appear once the viewport is ready.</p>
        </section>
      </>
    );
  }

  return (
    <>
      <section className="points-race-stats" aria-label="Points race stats">
        <div className="points-race-stat">
          <span>Leader</span>
          <strong>{leader.name}</strong>
          <small>{signedPoints(leader.latestPoints)}</small>
        </div>
        <div className="points-race-stat">
          <span>Biggest swing</span>
          <strong>{signedPoints(biggestSwing.points)}</strong>
          <small>{biggestSwing.playerName}</small>
        </div>
        <div className="points-race-stat">
          <span>Hands recorded</span>
          <strong>{pointsTimeline.length.toLocaleString()}</strong>
        </div>
      </section>

      <section className="points-race-stage" aria-label="Points race chart">
        <svg
          className="points-race-svg"
          viewBox={`0 0 ${geometry.width} ${geometry.height}`}
          role="img"
          aria-labelledby={`${chartTitleId} ${chartDescriptionId}`}
        >
          <title id={chartTitleId}>
            Points race for {eventTitle} across {pointsTimeline.length.toLocaleString()} recorded hands
          </title>
          <desc id={chartDescriptionId}>
            Cumulative point totals by recorded hand. Latest leader is {leader.name} at {signedPoints(leader.latestPoints)} points.
          </desc>
          <defs>
            <filter id="latest-point-glow" x="-80%" y="-80%" width="260%" height="260%">
              <feGaussianBlur stdDeviation="4" result="blur" />
              <feMerge>
                <feMergeNode in="blur" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
          </defs>
          <rect
            className="points-race-plot"
            x={geometry.padding.left}
            y={geometry.padding.top}
            width={geometry.width - geometry.padding.left - geometry.padding.right}
            height={geometry.height - geometry.padding.top - geometry.padding.bottom}
            rx="8"
          />
          {gridLines.map((gridLine) => (
            <g key={gridLine.y}>
              <line
                className="points-race-grid-line"
                x1={geometry.padding.left}
                x2={geometry.width - geometry.padding.right}
                y1={gridLine.y}
                y2={gridLine.y}
              />
              <text className="points-race-axis-label" x="18" y={gridLine.y + 4}>
                {Math.round(gridLine.value).toLocaleString()}
              </text>
            </g>
          ))}
          {visibleSeries.map((player, index) => {
            const color = LINE_COLORS[index % LINE_COLORS.length];
            const { path, latestPoint } = getPathForSeries(
              player,
              minPoints,
              maxPoints,
              geometry,
            );
            const isSpotlighted = spotlightedPlayerId === player.id;
            const hasSpotlight = spotlightedPlayerId !== null;
            const isDefaultVisible = index < visibleLimit;

            return (
              <g key={player.id}>
                <path
                  data-player-id={player.id}
                  className={lineClassName(
                    index,
                    isDefaultVisible,
                    isSpotlighted,
                    hasSpotlight,
                  )}
                  d={path}
                  fill="none"
                  stroke={color}
                />
                {latestPoint ? (
                  <circle
                    className={[
                      "points-race-latest-point",
                      hasSpotlight && !isSpotlighted ? "is-dimmed" : null,
                      isSpotlighted ? "is-spotlighted" : null,
                    ]
                      .filter(Boolean)
                      .join(" ")}
                    cx={latestPoint.x}
                    cy={latestPoint.y}
                    r={isSpotlighted ? 6 : 4}
                    fill={color}
                  />
                ) : null}
              </g>
            );
          })}
        </svg>
      </section>

      <div className="visually-hidden">
        <table aria-label="Points race data summary">
          <caption>Points race data summary</caption>
          <thead>
            <tr>
              <th scope="col">Player</th>
              <th scope="col">Latest points</th>
              {pointsTimeline.map((hand, index) => (
                <th scope="col" key={index}>
                  {handLabel(hand, index)}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {series.map((player) => (
              <tr key={player.id}>
                <th scope="row">{player.name}</th>
                <td>{player.latestPoints.toLocaleString()}</td>
                {player.values.map((value, index) => (
                  <td key={index}>{value === null ? "No score" : value.toLocaleString()}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <section className="points-race-legend-wrap" aria-label="Player controls">
        <div className="points-race-actions">
          <button
            className="points-race-toggle"
            type="button"
            onClick={() => {
              setShowEveryone((current) => {
                const nextShowEveryone = !current;
                if (nextShowEveryone && eventSlug) {
                  captureAnalyticsEvent("points_race_show_everyone_clicked", {
                    event_slug: eventSlug,
                    visible_players: series.length,
                  });
                }
                return nextShowEveryone;
              });
            }}
          >
            {showEveryone ? "Show top players" : "Show everyone"}
          </button>
        </div>
        <ul className="points-race-legend" aria-label="Players">
          {visibleSeries.map((player, index) => {
            const isSpotlighted = spotlightedPlayerId === player.id;
            const color = LINE_COLORS[index % LINE_COLORS.length];

            return (
              <li key={player.id}>
                <button
                  className={[
                    "points-race-chip",
                    index < 4 ? "is-top-chip" : null,
                    showEveryone && index >= visibleLimit && !isSpotlighted
                      ? "is-muted-chip"
                      : null,
                    spotlightedPlayerId && !isSpotlighted ? "is-dimmed" : null,
                    isSpotlighted ? "is-spotlighted" : null,
                  ]
                    .filter(Boolean)
                    .join(" ")}
                  type="button"
                  aria-label={
                    isSpotlighted
                      ? `Clear ${player.name} spotlight`
                      : `Spotlight ${player.name}`
                  }
                  aria-pressed={isSpotlighted}
                  onClick={() =>
                    setSpotlightedPlayerId((currentId) =>
                      currentId === player.id ? null : player.id,
                    )
                  }
                >
                  <span
                    className="points-race-swatch"
                    style={{ backgroundColor: color }}
                    aria-hidden="true"
                  />
                  <span className="points-race-chip-name">{player.name}</span>
                  <span className="points-race-chip-points">
                    {signedPoints(player.latestPoints)}
                  </span>
                </button>
              </li>
            );
          })}
        </ul>
      </section>
    </>
  );
}
