/**
 * Escape user input before putting it into a `new RegExp(...)` used in a Mongo
 * query. Prevents ReDoS (catastrophic backtracking) and unintended pattern
 * matching from attacker-controlled search strings.
 */
export function escapeRegex(input: unknown): string {
  return String(input ?? '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** Build a case-insensitive RegExp from a safely-escaped user string. */
export function safeRegex(input: unknown, flags = 'i'): RegExp {
  return new RegExp(escapeRegex(input), flags);
}
