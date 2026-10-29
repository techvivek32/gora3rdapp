'use client';

import {
  InvoiceTemplate, InvoiceBlock, SAMPLE, previewFare, money2, amountInWords,
  companyFieldValue, customerFieldValue, tripFieldValue,
} from './types';

/**
 * An on-screen copy of the PDF, drawn from the same design and the same sample
 * booking the server uses for its preview.
 *
 * It exists so an edit shows its effect immediately; it is a likeness, not the
 * artefact — "Open PDF preview" runs the real renderer when the exact output
 * matters.
 */
export function InvoicePreview({ t }: { t: InvoiceTemplate }) {
  const paper = t.paper || {};
  const company = t.company || {};
  const tax = t.tax || {};
  const invoice = t.invoice || {};
  const fare = previewFare(tax);

  const text = paper.text || '#1F2430';
  const muted = paper.muted || '#6B7280';
  const border = paper.border || '#D1D5DB';
  const headBg = paper.headerBg || '#F3F4F6';
  const accent = paper.accent || '#F26522';
  const fs = Number(paper.fontSize) || 9;

  const kv = (label: string, value: string, i: number) => (
    <div key={i} className="flex gap-2 py-[1px]">
      <span style={{ color: muted, minWidth: '38%' }}>{label}:</span>
      <span style={{ color: text, fontWeight: 600 }}>{value || '-'}</span>
    </div>
  );

  const block = (b: InvoiceBlock) => {
    if (b.enabled === false) return null;
    switch (b.type) {
      case 'logo':
        return (
          <div key={b.id} style={{ textAlign: b.props?.align || 'center', marginBottom: 8 }}>
            {company.logoUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={company.logoUrl} alt="" style={{ width: Number(b.props?.width) || 150, display: 'inline-block' }} />
            ) : (
              <span style={{ color: accent, fontWeight: 800, fontSize: fs + 7 }}>
                {company.tradeName || company.legalName || 'Company'}
              </span>
            )}
          </div>
        );
      case 'title':
        return (
          <div
            key={b.id}
            style={{
              textAlign: b.props?.align || 'center',
              background: b.props?.boxed ? headBg : 'transparent',
              border: b.props?.boxed ? `1px solid ${border}` : 'none',
              color: text, fontWeight: 800, fontSize: fs + 2,
              padding: '6px 8px', marginBottom: 8, letterSpacing: 0.3,
            }}
          >
            {String(b.props?.text || invoice.title || 'TAX INVOICE').toUpperCase()}
          </div>
        );
      case 'parties': {
        const left = (b.props?.leftFields || []).map((k: string) => companyFieldValue(k, company, invoice)).filter(Boolean) as Array<[string, string]>;
        const right = (b.props?.rightFields || []).map((k: string) => customerFieldValue(k)).filter(Boolean) as Array<[string, string]>;
        return (
          <div key={b.id} style={{ border: `1px solid ${border}`, padding: 8, marginBottom: 8, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
            <div>
              <div style={{ fontWeight: 700, color: text, marginBottom: 4 }}>{b.props?.leftTitle || 'Company Details:'}</div>
              {left.map(([l, v], i) => kv(l, v, i))}
            </div>
            <div>
              <div style={{ fontWeight: 700, color: text, marginBottom: 4 }}>{b.props?.rightTitle || 'Customer Details:'}</div>
              {right.map(([l, v], i) => kv(l, v, i))}
            </div>
          </div>
        );
      }
      case 'trip': {
        const rows = (b.props?.fields || []).map((k: string) => tripFieldValue(k)).filter(Boolean) as Array<[string, string]>;
        if (!rows.length) return null;
        const half = Math.ceil(rows.length / 2);
        return (
          <div key={b.id} style={{ border: `1px solid ${border}`, padding: 8, marginBottom: 8 }}>
            <div style={{ fontWeight: 700, color: text, marginBottom: 4 }}>{b.props?.title || 'Trip Details'}</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
              <div>{rows.slice(0, half).map(([l, v], i) => kv(l, v, i))}</div>
              <div>{rows.slice(half).map(([l, v], i) => kv(l, v, i))}</div>
            </div>
          </div>
        );
      }
      case 'fare': {
        const cell: React.CSSProperties = { border: `1px solid ${border}`, padding: '3px 6px' };
        const right: React.CSSProperties = { ...cell, textAlign: 'right', whiteSpace: 'nowrap' };
        return (
          <div key={b.id} style={{ marginBottom: 8 }}>
            <div style={{ fontWeight: 700, color: text, marginBottom: 4 }}>{b.props?.title || 'Fare Details:'}</div>
            <table style={{ width: '100%', borderCollapse: 'collapse', color: text }}>
              <thead>
                <tr style={{ background: headBg, fontWeight: 700 }}>
                  <td style={cell}>{b.props?.descriptionLabel || 'Particulars'}</td>
                  <td style={right}>{b.props?.rateLabel || 'Rate'}</td>
                  <td style={right}>{b.props?.amountLabel || 'Amount'}</td>
                </tr>
              </thead>
              <tbody>
                {fare.lines.map((l, i) => (
                  <tr key={i}>
                    <td style={cell}>{l.label}</td>
                    <td style={right}>{l.rate}</td>
                    <td style={right}>{money2(l.amount)}</td>
                  </tr>
                ))}
                {tax.mode === 'cgst_sgst' && fare.taxTotal > 0 && (
                  <>
                    <tr><td style={cell}>CGST</td><td style={right}>{tax.cgstPercent}%</td><td style={right}>{money2(fare.cgst)}</td></tr>
                    <tr><td style={cell}>SGST</td><td style={right}>{tax.sgstPercent}%</td><td style={right}>{money2(fare.sgst)}</td></tr>
                  </>
                )}
                {tax.mode === 'igst' && fare.taxTotal > 0 && (
                  <tr><td style={cell}>IGST</td><td style={right}>{tax.igstPercent}%</td><td style={right}>{money2(fare.igst)}</td></tr>
                )}
                <tr style={{ fontWeight: 700 }}><td style={cell}>Total</td><td style={right} /><td style={right}>{money2(fare.total)}</td></tr>
                {tax.showRoundOff !== false && Math.abs(fare.roundOff) >= 0.005 && (
                  <tr><td style={cell}>Rounded Off</td><td style={right} /><td style={right}>{(fare.roundOff < 0 ? '-' : '') + money2(Math.abs(fare.roundOff))}</td></tr>
                )}
                <tr style={{ fontWeight: 700, background: headBg }}>
                  <td style={cell}>Final Amount</td><td style={right} /><td style={right}>{money2(fare.finalAmount)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        );
      }
      case 'amountInWords':
        return (
          <div key={b.id} style={{ marginBottom: 8 }}>
            <div style={{ color: muted }}>{b.props?.label || 'Amount in words:'}</div>
            <div style={{ color: text, fontWeight: 700 }}>{amountInWords(fare.finalAmount)}</div>
          </div>
        );
      case 'terms': {
        const items: string[] = (b.props?.items || []).filter((x: string) => String(x || '').trim());
        if (!items.length) return null;
        return (
          <div key={b.id} style={{ marginBottom: 8 }}>
            <div style={{ fontWeight: 700, color: text, marginBottom: 3 }}>{b.props?.title || 'Terms & Conditions:'}</div>
            <ol style={{ color: muted, fontSize: fs - 0.5, paddingLeft: 16, margin: 0 }}>
              {items.map((it, i) => <li key={i} style={{ marginBottom: 1 }}>{it}</li>)}
            </ol>
          </div>
        );
      }
      case 'note':
        if (!String(b.props?.text || '').trim()) return null;
        return (
          <div key={b.id} style={{ border: `1px solid ${border}`, padding: 8, marginBottom: 8, textAlign: b.props?.align || 'center', color: text, fontWeight: 700 }}>
            {b.props?.text}
          </div>
        );
      case 'text':
        if (!String(b.props?.text || '').trim()) return null;
        return (
          <div key={b.id} style={{ marginBottom: 6, textAlign: b.props?.align || 'left', color: b.props?.color || text, fontWeight: b.props?.bold ? 700 : 400, fontSize: Number(b.props?.size) || fs }}>
            {b.props?.text}
          </div>
        );
      case 'divider':
        return <hr key={b.id} style={{ border: 0, borderTop: `1px solid ${border}`, margin: '8px 0' }} />;
      case 'spacer':
        return <div key={b.id} style={{ height: Number(b.props?.height) || 10 }} />;
      default:
        return null;
    }
  };

  return (
    <div
      className="shadow-sm"
      style={{
        background: '#FFFFFF',
        // A4 proportions so the preview wraps roughly where the PDF will.
        width: '100%', aspectRatio: '210 / 297',
        padding: `${Number(paper.margin) || 36}px`,
        fontSize: fs + 1, lineHeight: 1.35, color: text,
        fontFamily: 'Helvetica, Arial, sans-serif',
        overflow: 'auto',
      }}
    >
      {(t.blocks || []).map(block)}
    </div>
  );
}
