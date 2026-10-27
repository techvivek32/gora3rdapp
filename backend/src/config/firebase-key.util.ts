/**
 * Normalise a service-account private key read from an env var into a PEM that
 * Node's crypto (and therefore firebase-admin) will actually parse.
 *
 * The same key gets mangled three different ways depending on how it was put
 * into `.env`, and all three produce the identical unhelpful error —
 * "Invalid PEM formatted message" — with push silently disabled:
 *
 *  1. escaped:   "-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n"
 *     The literal two-character \n sequences need turning into real newlines.
 *     This is the only case the old `.replace(/\\n/g, '\n')` handled.
 *  2. flattened: "-----BEGIN PRIVATE KEY-----MIIE...-----END PRIVATE KEY-----"
 *     Every newline stripped (an editor or a copy-paste through a web form).
 *     Nothing to replace, so the old code passed it straight through and it
 *     failed. This is what KVM4 is running with.
 *  3. spaced:    newlines replaced by spaces, same cause.
 *
 * Rather than asking whoever edits `.env` to get the quoting exactly right, the
 * app accepts all of them: strip the wrapper, pull out the base64 body, and
 * re-emit a canonical PEM with the body wrapped at 64 characters.
 *
 * Returns undefined when there is nothing usable, so the caller keeps its
 * existing "not configured" path.
 */
export function normalizeFirebasePrivateKey(raw?: string): string | undefined {
  let key = (raw ?? '').trim();
  if (!key) return undefined;

  // `.env` values are often quoted; the quotes are not part of the key.
  if ((key.startsWith('"') && key.endsWith('"')) || (key.startsWith("'") && key.endsWith("'"))) {
    key = key.slice(1, -1);
  }

  // Case 1: literal backslash-n sequences.
  key = key.replace(/\\n/g, '\n');

  const match = key.match(/-----BEGIN ([A-Z ]+?)-----([\s\S]*?)-----END \1-----/);
  if (!match) return undefined;

  const label = match[1];
  // Cases 2 and 3: whatever separated the base64 — newlines, spaces or nothing —
  // the body is just the base64 characters.
  const body = match[2].replace(/[^A-Za-z0-9+/=]/g, '');
  if (!body) return undefined;

  const lines = body.match(/.{1,64}/g) ?? [];
  return `-----BEGIN ${label}-----\n${lines.join('\n')}\n-----END ${label}-----\n`;
}
