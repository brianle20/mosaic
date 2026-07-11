const PUBLIC_CLOCK_INTERVAL_MS = 30_000;

type ClockListener = () => void;

const listeners = new Set<ClockListener>();
let currentTime: number | null = null;
let clockInterval: ReturnType<typeof setInterval> | null = null;

export function getPublicClockSnapshot(): number {
  if (currentTime === null) {
    currentTime = Date.now();
  }
  return currentTime;
}

export function getPublicClockServerSnapshot(): null {
  return null;
}

export function subscribeToPublicClock(listener: ClockListener): () => void {
  listeners.add(listener);

  if (listeners.size === 1) {
    currentTime = Date.now();
    clockInterval = setInterval(() => {
      currentTime = Date.now();
      listeners.forEach((currentListener) => currentListener());
    }, PUBLIC_CLOCK_INTERVAL_MS);
  }

  return () => {
    listeners.delete(listener);
    if (listeners.size === 0 && clockInterval) {
      clearInterval(clockInterval);
      clockInterval = null;
      currentTime = null;
    }
  };
}
