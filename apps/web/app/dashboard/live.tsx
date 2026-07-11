"use client";

import { useEffect, useState } from "react";
import { getStats, getVerdicts, type Stats, type StoredVerdict } from "../../lib/engine";

/**
 * Live data hook for the dashboard. Polls the engine every 5s. Returns null
 * while loading or if the engine is unreachable, so the page can fall back
 * to its static sample content and never look broken during a demo.
 */
export function useLiveData() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [verdicts, setVerdicts] = useState<StoredVerdict[] | null>(null);
  const [live, setLive] = useState(false);

  useEffect(() => {
    let active = true;
    async function pull() {
      const [s, v] = await Promise.all([getStats(), getVerdicts(6)]);
      if (!active) return;
      if (s && s.total > 0) {
        setStats(s);
        setVerdicts(v);
        setLive(true);
      } else {
        setLive(false);
      }
    }
    pull();
    const id = setInterval(pull, 5000);
    return () => {
      active = false;
      clearInterval(id);
    };
  }, []);

  return { stats, verdicts, live };
}
