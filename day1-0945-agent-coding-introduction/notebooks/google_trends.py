"""Small, classroom-friendly helpers for fetching Google Trends data."""

from pathlib import Path
import random
import time

import pandas as pd
from pytrends.request import TrendReq


CACHE_FILENAME = "google_trends_dengue_mx_cached.csv"


def _underscored_name(name):
    """Return a stable, notebook-friendly column name."""
    return name.strip().replace(" ", "_")


def _is_rate_limited(error):
    """Recognize the error forms pytrends uses for HTTP 429 responses."""
    return "429" in str(error) or "toomany" in type(error).__name__.lower()


def gt_fetch(kw_list, timeframe, geo="MX", tries=4):
    """Fetch Google Trends interest over time, returning ``None`` after failure.

    Results have a ``date`` column and one underscored column per requested term.
    A short random pause avoids a synchronized classroom request burst; 429 responses
    are retried after roughly ten seconds.
    """
    time.sleep(random.uniform(0, 3))

    for attempt in range(tries):
        try:
            trends = TrendReq(hl="en-US", tz=360, retries=3, backoff_factor=0.5)
            trends.build_payload(kw_list, timeframe=timeframe, geo=geo)
            frame = trends.interest_over_time()
            if frame.empty:
                return None

            frame = frame.drop(columns=["isPartial"], errors="ignore").reset_index()
            return frame.rename(columns={column: _underscored_name(column) for column in frame.columns})
        except Exception as error:
            if _is_rate_limited(error) and attempt < tries - 1:
                print(f"Rate-limited (attempt {attempt + 1}/{tries}); waiting 10s and retrying...")
                time.sleep(10)
                continue
            print(f"Live Google Trends pull failed ({type(error).__name__}): {error}")
            return None

    return None


def _default_cache_path():
    """Find the bundled cache relative to the notebook's working directory."""
    candidates = []
    for directory in (Path.cwd(), *Path.cwd().parents):
        candidates.extend(
            [
                directory / "data" / CACHE_FILENAME,
                directory
                / "day1-0945-agent-coding-introduction"
                / "data"
                / CACHE_FILENAME,
            ]
        )

    return next((path for path in candidates if path.exists()), candidates[0])


def load_hist_cache(cache_path=None):
    """Load the bundled Mexico dengue Trends snapshot with parsed dates."""
    cache_path = _default_cache_path() if cache_path is None else Path(cache_path)
    return pd.read_csv(cache_path, parse_dates=["date"])
