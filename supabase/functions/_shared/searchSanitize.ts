/** Pure. Normalizes a search term into a safe PostgREST `ilike` pattern:
 * `%` and `*` are pattern wildcards, and `,` `(` `)` `.` quotes and
 * backslashes are filter-significant in PostgREST `.or(...)` expressions.
 * Collapsing them to plain text prevents the raw term from widening the match
 * or being parsed as extra filter syntax (filter injection). */
export function sanitizeSearchPattern(q: string): string {
  const cleaned = q
    .replace(/[%,*()'"\\]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return `%${cleaned}%`;
}
