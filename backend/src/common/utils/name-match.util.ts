/**
 * Compare a name from a government record (RC owner, DL holder, Aadhaar) with the
 * name on the account.
 *
 * Exact string equality is useless here. The same person is routinely written as
 * "RAJPUT MANOJBHAI K", "Manoj K Rajput" and "Mj Rajput" across RTO, UIDAI and
 * whatever they typed at signup. A strict check would reject real drivers, which
 * is worse than letting a borderline one through for a human to eyeball.
 */

/** Strip titles/punctuation, collapse spaces, lowercase. */
function normalise(raw: string): string {
  return (raw || '')
    .toLowerCase()
    .replace(/\b(mr|mrs|ms|dr|shri|smt|kum|late)\b\.?/g, ' ')
    .replace(/[^a-z\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Indian records love the "-bhai"/"-ben"/"-kumar" suffixes and drop them freely:
 * "manojbhai" and "manoj" are the same token. Reduce both to the stem.
 */
function stem(token: string): string {
  return token
    .replace(/(bhai|ben|kumar|kumari|singh|lal)$/, '')
    .trim();
}

function tokens(raw: string): string[] {
  return normalise(raw)
    .split(' ')
    .map(stem)
    .filter((t) => t.length > 0);
}

/** Levenshtein distance, capped work for the short strings we deal with. */
function distance(a: string, b: string): number {
  if (a === b) return 0;
  if (!a.length) return b.length;
  if (!b.length) return a.length;
  let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const row = [i];
    for (let j = 1; j <= b.length; j++) {
      row[j] = Math.min(
        prev[j] + 1,
        row[j - 1] + 1,
        prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
    }
    prev = row;
  }
  return prev[b.length];
}

/** Do `short`'s letters appear in order inside `long`? Catches the clipped forms
 *  people sign up with - "mj" for "manoj", "sdp" for "sandeep". */
function isAbbreviation(short: string, long: string): boolean {
  if (short.length > 3 || short.length >= long.length) return false;
  if (short[0] !== long[0]) return false; // must at least start the same
  let i = 0;
  for (const ch of long) {
    if (ch === short[i]) i++;
    if (i === short.length) return true;
  }
  return false;
}

/** Two tokens count as the same word if they're equal, one abbreviates the other,
 *  one is an initial of the other, or they're within a typo's reach. */
function tokenMatches(a: string, b: string): boolean {
  if (a === b) return true;
  if (a.length === 1 || b.length === 1) return a[0] === b[0]; // "k" vs "kiran"
  const [shortT, longT] = a.length <= b.length ? [a, b] : [b, a];
  if (isAbbreviation(shortT, longT)) return true;
  // Transliteration wobble is the norm here ("rajput"/"rajpoot",
  // "shaikh"/"sheikh"), so longer words get more slack, not less.
  const longer = longT.length;
  const allowed = longer <= 4 ? 0 : longer <= 6 ? 1 : 2;
  return distance(a, b) <= allowed;
}

export interface NameMatchResult {
  /** 0..1 — share of the shorter name's words found in the longer one. */
  score: number;
  matched: boolean;
  /** Human-readable reason, safe to show in the app. */
  reason: string;
}

/**
 * Match `official` (from the government record) against `claimed` (the account).
 *
 * Scored on the SHORTER name's tokens: "Mj Rajput" vs "RAJPUT MANOJBHAI K" should
 * pass — the account name is simply a subset of the official one, which is the
 * normal case, not a mismatch.
 */
export function matchNames(official: string, claimed: string, threshold = 0.6): NameMatchResult {
  const a = tokens(official);
  const b = tokens(claimed);
  if (!a.length || !b.length) {
    return { score: 0, matched: false, reason: 'Name missing on one side' };
  }

  const [short, long] = a.length <= b.length ? [a, b] : [b, a];
  const pool = [...long];
  let hits = 0;
  for (const t of short) {
    const i = pool.findIndex((p) => tokenMatches(t, p));
    if (i >= 0) {
      hits++;
      pool.splice(i, 1); // each word can only be used once
    }
  }

  const score = hits / short.length;
  const matched = score >= threshold;
  return {
    score: Math.round(score * 100) / 100,
    matched,
    reason: matched
      ? 'Name matches the official record'
      : 'Name does not match the official record',
  };
}
