/**
 * Structured data, the machine-readable half of a page.
 *
 * The visible page tells a person what the trip costs; this tells a search
 * engine the same thing in a form it can quote directly — which is how a
 * result gets the extra lines, the FAQ drop-downs and the breadcrumb trail
 * instead of a bare blue link.
 *
 * Rendered as a plain script tag rather than through a library: the payload is
 * built on the server, it is our own data, and `JSON.stringify` with the
 * closing-tag escape below is the whole job.
 */
export function JsonLd({ data }: { data: object | object[] }) {
  // A literal "</script>" inside the JSON would end the tag early and the rest
  // of the payload would render as markup. Escaping the slash keeps it inside
  // the string and still parses as the same JSON.
  const json = JSON.stringify(data).replace(/</g, '\\u003c');
  return (
    <script
      type="application/ld+json"
      // The content is generated above from our own typed objects, never from
      // anything a visitor supplied.
      dangerouslySetInnerHTML={{ __html: json }}
    />
  );
}
