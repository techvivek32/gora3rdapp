'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { adminApi } from '@/lib/api';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Select } from '@/components/ui/Select';
import toast from 'react-hot-toast';
import {
  ReceiptText, GripVertical, Eye, EyeOff, Trash2, Plus, ChevronDown, ChevronRight,
  RotateCcw, Save, FileDown, Upload,
} from 'lucide-react';
import { InvoicePreview } from './InvoicePreview';
import {
  InvoiceTemplate, InvoiceBlock, InvoiceBlockType, BLOCK_LABELS, SINGLE_USE,
  COMPANY_FIELDS, CUSTOMER_FIELDS, TRIP_FIELDS, newBlock,
} from './types';

type Tab = 'blocks' | 'company' | 'tax' | 'style';

export default function InvoiceDesignPage() {
  const [tpl, setTpl] = useState<InvoiceTemplate | null>(null);
  const [tab, setTab] = useState<Tab>('blocks');
  const [open, setOpen] = useState<string | null>(null);
  const [dragId, setDragId] = useState<string | null>(null);
  const [overId, setOverId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [dirty, setDirty] = useState(false);
  const logoInput = useRef<HTMLInputElement>(null);

  useEffect(() => { void load(); }, []);

  async function load() {
    setLoading(true);
    try {
      const res: any = await adminApi.getInvoiceTemplate();
      setTpl(res.data ?? res);
      setDirty(false);
    } catch (e: any) {
      toast.error(e?.message || 'Could not load the invoice design');
    } finally {
      setLoading(false);
    }
  }

  const patch = (fn: (draft: InvoiceTemplate) => void) => {
    setTpl((cur) => {
      if (!cur) return cur;
      const next: InvoiceTemplate = JSON.parse(JSON.stringify(cur));
      fn(next);
      return next;
    });
    setDirty(true);
  };

  const setBlock = (id: string, fn: (b: InvoiceBlock) => void) =>
    patch((d) => { const b = d.blocks.find((x) => x.id === id); if (b) fn(b); });

  // ── drag to reorder ────────────────────────────────────────────────────────
  // Native HTML5 drag: the block list is a short vertical list, so this needs no
  // library and keeps the admin bundle as it was.
  const onDrop = (targetId: string) => {
    if (!dragId || dragId === targetId) { setDragId(null); setOverId(null); return; }
    patch((d) => {
      const from = d.blocks.findIndex((b) => b.id === dragId);
      const to = d.blocks.findIndex((b) => b.id === targetId);
      if (from < 0 || to < 0) return;
      const [moved] = d.blocks.splice(from, 1);
      d.blocks.splice(to, 0, moved);
    });
    setDragId(null);
    setOverId(null);
  };

  const addable = useMemo(() => {
    const used = new Set((tpl?.blocks || []).map((b) => b.type));
    return (Object.keys(BLOCK_LABELS) as InvoiceBlockType[])
      .filter((t) => !(SINGLE_USE.includes(t) && used.has(t)));
  }, [tpl]);

  async function save() {
    if (!tpl) return;
    setSaving(true);
    try {
      const res: any = await adminApi.saveInvoiceTemplate(tpl);
      setTpl(res.data ?? tpl);
      setDirty(false);
      toast.success('Invoice design saved — every new invoice uses it');
    } catch (e: any) {
      toast.error(e?.message || 'Could not save');
    } finally {
      setSaving(false);
    }
  }

  async function reset() {
    if (!confirm('Restore the built-in default invoice design? Your current design will be replaced.')) return;
    try {
      const res: any = await adminApi.resetInvoiceTemplate();
      setTpl(res.data ?? null);
      setDirty(false);
      toast.success('Restored the default design');
    } catch (e: any) {
      toast.error(e?.message || 'Could not reset');
    }
  }

  async function openPdf() {
    if (!tpl) return;
    try {
      const blob = await adminApi.previewInvoiceTemplate(tpl);
      const url = URL.createObjectURL(blob as Blob);
      window.open(url, '_blank', 'noopener');
      // Give the new tab a moment to take the blob before releasing it.
      setTimeout(() => URL.revokeObjectURL(url), 60000);
    } catch (e: any) {
      toast.error(e?.message || 'Could not render the PDF');
    }
  }

  async function uploadLogo(file: File) {
    try {
      const res: any = await adminApi.uploadInvoiceLogo(file);
      const url = res?.data ?? res;
      patch((d) => { d.company.logoUrl = String(url); });
      toast.success('Logo uploaded');
    } catch (e: any) {
      toast.error(e?.message || 'Could not upload the logo');
    }
  }

  if (loading || !tpl) {
    return (
      <div className="p-6">
        <div className="h-8 w-56 rounded bg-gray-200 dark:bg-gray-700 animate-pulse" />
        <div className="mt-4 h-96 rounded-xl bg-gray-100 dark:bg-gray-800 animate-pulse" />
      </div>
    );
  }

  const field = (label: string, value: any, onChange: (v: string) => void, placeholder?: string) => (
    <div>
      <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">{label}</label>
      <Input value={value ?? ''} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} />
    </div>
  );

  const checkList = (
    all: Array<[string, string]>,
    chosen: string[],
    onToggle: (key: string, on: boolean) => void,
  ) => (
    <div className="grid grid-cols-2 gap-1">
      {all.map(([key, label]) => (
        <label key={key} className="flex items-center gap-2 text-xs text-gray-700 dark:text-gray-300">
          <input
            type="checkbox"
            className="accent-orange-500"
            checked={chosen.includes(key)}
            onChange={(e) => onToggle(key, e.target.checked)}
          />
          {label}
        </label>
      ))}
    </div>
  );

  const blockEditor = (b: InvoiceBlock) => {
    const P = b.props || {};
    const set = (k: string, v: any) => setBlock(b.id, (x) => { x.props = { ...x.props, [k]: v }; });
    switch (b.type) {
      case 'logo':
        return (
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Align</label>
              <Select className="w-full" value={P.align || 'center'} onChange={(e) => set('align', e.target.value)}>
                <option value="left">Left</option><option value="center">Centre</option><option value="right">Right</option>
              </Select>
            </div>
            {field('Width (pt)', P.width, (v) => set('width', Number(v) || 0))}
            <p className="col-span-2 text-xs text-gray-500">
              Upload the logo under the <button type="button" className="underline" onClick={() => setTab('company')}>Company</button> tab.
              Without one, the company name is printed instead.
            </p>
          </div>
        );
      case 'title':
        return (
          <div className="space-y-3">
            {field('Title text', P.text, (v) => set('text', v), 'ORIGINAL TAX INVOICE')}
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Align</label>
                <Select className="w-full" value={P.align || 'center'} onChange={(e) => set('align', e.target.value)}>
                  <option value="left">Left</option><option value="center">Centre</option><option value="right">Right</option>
                </Select>
              </div>
              <label className="flex items-end gap-2 text-sm text-gray-700 dark:text-gray-300 pb-2">
                <input type="checkbox" className="accent-orange-500" checked={P.boxed !== false} onChange={(e) => set('boxed', e.target.checked)} />
                Boxed band
              </label>
            </div>
          </div>
        );
      case 'parties':
        return (
          <div className="space-y-3">
            <div className="grid grid-cols-2 gap-3">
              {field('Left heading', P.leftTitle, (v) => set('leftTitle', v))}
              {field('Right heading', P.rightTitle, (v) => set('rightTitle', v))}
            </div>
            <div>
              <p className="text-xs font-semibold text-gray-700 dark:text-gray-300 mb-1">Left column (your company)</p>
              {checkList(COMPANY_FIELDS, P.leftFields || [], (k, on) =>
                set('leftFields', on ? [...(P.leftFields || []), k] : (P.leftFields || []).filter((x: string) => x !== k)))}
            </div>
            <div>
              <p className="text-xs font-semibold text-gray-700 dark:text-gray-300 mb-1">Right column (the rider)</p>
              {checkList(CUSTOMER_FIELDS, P.rightFields || [], (k, on) =>
                set('rightFields', on ? [...(P.rightFields || []), k] : (P.rightFields || []).filter((x: string) => x !== k)))}
            </div>
          </div>
        );
      case 'trip':
        return (
          <div className="space-y-3">
            {field('Heading', P.title, (v) => set('title', v))}
            {checkList(TRIP_FIELDS, P.fields || [], (k, on) =>
              set('fields', on ? [...(P.fields || []), k] : (P.fields || []).filter((x: string) => x !== k)))}
          </div>
        );
      case 'fare':
        return (
          <div className="space-y-3">
            {field('Heading', P.title, (v) => set('title', v))}
            <div className="grid grid-cols-3 gap-3">
              {field('Column 1', P.descriptionLabel, (v) => set('descriptionLabel', v))}
              {field('Column 2', P.rateLabel, (v) => set('rateLabel', v))}
              {field('Column 3', P.amountLabel, (v) => set('amountLabel', v))}
            </div>
            <p className="text-xs text-gray-500">
              The tax rows come from the <button type="button" className="underline" onClick={() => setTab('tax')}>Tax</button> tab.
            </p>
          </div>
        );
      case 'amountInWords':
        return field('Label', P.label, (v) => set('label', v), 'Amount in words:');
      case 'terms': {
        const items: string[] = P.items || [];
        return (
          <div className="space-y-2">
            {field('Heading', P.title, (v) => set('title', v))}
            {items.map((it, i) => (
              <div key={i} className="flex gap-2 items-start">
                <span className="pt-2 text-xs text-gray-400 w-4">{i + 1}.</span>
                <textarea
                  value={it}
                  onChange={(e) => set('items', items.map((x, j) => (j === i ? e.target.value : x)))}
                  rows={2}
                  className="flex-1 px-3 py-2 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-orange-500"
                />
                <button
                  type="button"
                  onClick={() => set('items', items.filter((_, j) => j !== i))}
                  className="mt-2 text-gray-400 hover:text-red-500"
                  aria-label={`Remove term ${i + 1}`}
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))}
            <Button size="sm" variant="outline" onClick={() => set('items', [...items, ''])}>
              <Plus className="w-4 h-4 mr-1" /> Add a term
            </Button>
          </div>
        );
      }
      case 'note':
      case 'text':
        return (
          <div className="space-y-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Text</label>
              <textarea
                value={P.text ?? ''}
                onChange={(e) => set('text', e.target.value)}
                rows={3}
                className="w-full px-3 py-2 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-orange-500"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Align</label>
                <Select className="w-full" value={P.align || 'center'} onChange={(e) => set('align', e.target.value)}>
                  <option value="left">Left</option><option value="center">Centre</option><option value="right">Right</option>
                </Select>
              </div>
              {b.type === 'text' && (
                <label className="flex items-end gap-2 text-sm text-gray-700 dark:text-gray-300 pb-2">
                  <input type="checkbox" className="accent-orange-500" checked={!!P.bold} onChange={(e) => set('bold', e.target.checked)} />
                  Bold
                </label>
              )}
            </div>
          </div>
        );
      case 'spacer':
        return field('Height (pt)', P.height, (v) => set('height', Number(v) || 0));
      default:
        return <p className="text-xs text-gray-500">This block has nothing to configure.</p>;
    }
  };

  const colour = (label: string, key: string) => (
    <div>
      <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">{label}</label>
      <div className="flex gap-2">
        <input
          type="color"
          value={tpl.paper?.[key] || '#000000'}
          onChange={(e) => patch((d) => { d.paper = { ...d.paper, [key]: e.target.value }; })}
          className="h-9 w-12 rounded border border-gray-300 dark:border-gray-600 bg-transparent"
        />
        <Input value={tpl.paper?.[key] ?? ''} onChange={(e) => patch((d) => { d.paper = { ...d.paper, [key]: e.target.value }; })} />
      </div>
    </div>
  );

  return (
    <div className="p-6 space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <ReceiptText className="w-6 h-6 text-orange-500" />
          <div>
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Invoice Design</h1>
            <p className="text-sm text-gray-500">
              Arrange the invoice here — the PDF riders and drivers download is built from this design.
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {dirty && <span className="text-xs text-amber-600 dark:text-amber-400">Unsaved changes</span>}
          <Button variant="outline" onClick={openPdf}><FileDown className="w-4 h-4 mr-1" /> Open PDF preview</Button>
          <Button variant="outline" onClick={reset}><RotateCcw className="w-4 h-4 mr-1" /> Reset</Button>
          <Button onClick={save} disabled={saving || !dirty}>
            <Save className="w-4 h-4 mr-1" /> {saving ? 'Saving…' : 'Save design'}
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] gap-5">
        {/* ── editor ─────────────────────────────────────────────────────── */}
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700">
          <div className="flex border-b border-gray-200 dark:border-gray-700">
            {([['blocks', 'Layout'], ['company', 'Company'], ['tax', 'Tax'], ['style', 'Style']] as Array<[Tab, string]>).map(([k, label]) => (
              <button
                key={k}
                onClick={() => setTab(k)}
                className={`px-4 py-3 text-sm font-medium transition-colors ${
                  tab === k
                    ? 'text-orange-600 border-b-2 border-orange-500'
                    : 'text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
                }`}
              >
                {label}
              </button>
            ))}
          </div>

          <div className="p-4 space-y-3">
            {tab === 'blocks' && (
              <>
                <p className="text-xs text-gray-500">
                  Drag a row by its handle to move that section up or down the invoice. The eye hides a section without deleting it.
                </p>
                {tpl.blocks.map((b) => (
                  <div
                    key={b.id}
                    onDragOver={(e) => { e.preventDefault(); setOverId(b.id); }}
                    onDragLeave={() => setOverId((cur) => (cur === b.id ? null : cur))}
                    onDrop={(e) => { e.preventDefault(); onDrop(b.id); }}
                    className={`rounded-lg border transition-colors ${
                      overId === b.id && dragId !== b.id
                        ? 'border-orange-400 bg-orange-50 dark:bg-orange-500/10'
                        : 'border-gray-200 dark:border-gray-700'
                    } ${dragId === b.id ? 'opacity-50' : ''}`}
                  >
                    <div className="flex items-center gap-2 px-3 py-2">
                      <span
                        draggable
                        onDragStart={() => setDragId(b.id)}
                        onDragEnd={() => { setDragId(null); setOverId(null); }}
                        className="cursor-grab active:cursor-grabbing text-gray-400 hover:text-gray-600"
                        title="Drag to reorder"
                      >
                        <GripVertical className="w-4 h-4" />
                      </span>
                      <button
                        onClick={() => setOpen(open === b.id ? null : b.id)}
                        className="flex items-center gap-1 flex-1 text-left text-sm font-medium text-gray-900 dark:text-white"
                      >
                        {open === b.id ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
                        <span className={b.enabled === false ? 'line-through text-gray-400' : ''}>{BLOCK_LABELS[b.type]}</span>
                      </button>
                      <button
                        onClick={() => setBlock(b.id, (x) => { x.enabled = x.enabled === false; })}
                        className="text-gray-400 hover:text-gray-700 dark:hover:text-gray-200"
                        title={b.enabled === false ? 'Show on the invoice' : 'Hide from the invoice'}
                      >
                        {b.enabled === false ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                      </button>
                      <button
                        onClick={() => patch((d) => { d.blocks = d.blocks.filter((x) => x.id !== b.id); })}
                        className="text-gray-400 hover:text-red-500"
                        title="Remove this section"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                    {open === b.id && (
                      <div className="px-3 pb-3 pt-1 border-t border-gray-100 dark:border-gray-800">
                        {blockEditor(b)}
                      </div>
                    )}
                  </div>
                ))}

                <div className="pt-1">
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Add a section</label>
                  <Select
                    className="w-full"
                    value=""
                    onChange={(e) => {
                      const t = e.target.value as InvoiceBlockType;
                      if (!t) return;
                      const b = newBlock(t);
                      patch((d) => { d.blocks.push(b); });
                      setOpen(b.id);
                    }}
                  >
                    <option value="">Choose a section…</option>
                    {addable.map((t) => <option key={t} value={t}>{BLOCK_LABELS[t]}</option>)}
                  </Select>
                </div>
              </>
            )}

            {tab === 'company' && (
              <div className="space-y-3">
                {field('Legal name', tpl.company?.legalName, (v) => patch((d) => { d.company.legalName = v; }))}
                {field('Trade name (printed)', tpl.company?.tradeName, (v) => patch((d) => { d.company.tradeName = v; }))}
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Address</label>
                  <textarea
                    value={tpl.company?.address ?? ''}
                    onChange={(e) => patch((d) => { d.company.address = e.target.value; })}
                    rows={3}
                    className="w-full px-3 py-2 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-orange-500"
                  />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  {field('Phone', tpl.company?.phone, (v) => patch((d) => { d.company.phone = v; }))}
                  {field('Email', tpl.company?.email, (v) => patch((d) => { d.company.email = v; }))}
                  {field('GSTIN', tpl.company?.gstin, (v) => patch((d) => { d.company.gstin = v.toUpperCase(); }))}
                  {field('Place of supply', tpl.company?.placeOfSupply, (v) => patch((d) => { d.company.placeOfSupply = v; }))}
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Logo</label>
                  <div className="flex items-center gap-3">
                    {tpl.company?.logoUrl ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={tpl.company.logoUrl} alt="" className="h-10 object-contain rounded border border-gray-200 dark:border-gray-700 bg-white p-1" />
                    ) : (
                      <span className="text-xs text-gray-500">No logo — the company name is printed instead.</span>
                    )}
                    <input
                      ref={logoInput}
                      type="file"
                      accept="image/png,image/jpeg,image/webp"
                      className="hidden"
                      onChange={(e) => { const f = e.target.files?.[0]; if (f) void uploadLogo(f); e.target.value = ''; }}
                    />
                    <Button size="sm" variant="outline" onClick={() => logoInput.current?.click()}>
                      <Upload className="w-4 h-4 mr-1" /> Upload
                    </Button>
                    {tpl.company?.logoUrl && (
                      <Button size="sm" variant="outline" onClick={() => patch((d) => { d.company.logoUrl = ''; })}>Remove</Button>
                    )}
                  </div>
                </div>
                {field('Invoice number prefix', tpl.invoice?.numberPrefix, (v) => patch((d) => { d.invoice.numberPrefix = v; }), 'INV')}
              </div>
            )}

            {tab === 'tax' && (
              <div className="space-y-3">
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Tax split</label>
                  <Select className="w-full" value={tpl.tax?.mode || 'cgst_sgst'} onChange={(e) => patch((d) => { d.tax.mode = e.target.value; })}>
                    <option value="cgst_sgst">CGST + SGST (same state)</option>
                    <option value="igst">IGST (other state)</option>
                    <option value="none">No tax lines</option>
                  </Select>
                </div>
                {tpl.tax?.mode !== 'none' && (
                  <div className="rounded-lg border border-gray-200 dark:border-gray-700 p-3 bg-gray-50 dark:bg-gray-800/50">
                    <div className="flex items-baseline justify-between mb-2">
                      <span className="text-xs font-semibold text-gray-700 dark:text-gray-300">Rate</span>
                      <span className="text-xs text-gray-500">
                        GST {tpl.tax?.gstPercent ?? 0}% from{' '}
                        <a href="/cab-categories" className="underline hover:text-orange-600">Cab Categories</a>
                      </span>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      {tpl.tax?.mode === 'igst' ? (
                        <div className="col-span-2">
                          <label className="block text-xs text-gray-500 mb-1">IGST</label>
                          <div className="px-3 py-2 text-sm rounded-lg bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 font-semibold">
                            {tpl.tax?.igstPercent ?? 0}%
                          </div>
                        </div>
                      ) : (
                        <>
                          <div>
                            <label className="block text-xs text-gray-500 mb-1">CGST</label>
                            <div className="px-3 py-2 text-sm rounded-lg bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 font-semibold">
                              {tpl.tax?.cgstPercent ?? 0}%
                            </div>
                          </div>
                          <div>
                            <label className="block text-xs text-gray-500 mb-1">SGST</label>
                            <div className="px-3 py-2 text-sm rounded-lg bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 font-semibold">
                              {tpl.tax?.sgstPercent ?? 0}%
                            </div>
                          </div>
                        </>
                      )}
                    </div>
                    <p className="text-xs text-gray-500 mt-2">
                      Set GST once in Cab Categories → Pricing. The invoice splits it:{' '}
                      {tpl.tax?.gstPercent ?? 0}% becomes {tpl.tax?.mode === 'igst'
                        ? `IGST ${tpl.tax?.igstPercent ?? 0}%`
                        : `CGST ${tpl.tax?.cgstPercent ?? 0}% + SGST ${tpl.tax?.sgstPercent ?? 0}%`}.
                    </p>
                  </div>
                )}
                <label className="flex items-start gap-2 text-sm text-gray-700 dark:text-gray-300">
                  <input type="checkbox" className="mt-1 accent-orange-500" checked={tpl.tax?.fareIncludesTax !== false} onChange={(e) => patch((d) => { d.tax.fareIncludesTax = e.target.checked; })} />
                  <span>
                    The fare already includes tax
                    <span className="block text-xs text-gray-500">
                      On, the invoice splits the tax out of the amount charged. Off, the tax is added on top of it.
                    </span>
                  </span>
                </label>
                <label className="flex items-start gap-2 text-sm text-gray-700 dark:text-gray-300">
                  <input type="checkbox" className="mt-1 accent-orange-500" checked={tpl.tax?.showRoundOff !== false} onChange={(e) => patch((d) => { d.tax.showRoundOff = e.target.checked; })} />
                  <span>
                    Show a “Rounded Off” line
                    <span className="block text-xs text-gray-500">Rounds the final amount to the nearest rupee.</span>
                  </span>
                </label>
                <p className="text-xs text-gray-500 border-t border-gray-100 dark:border-gray-800 pt-3">
                  A booking that already recorded its own GST keeps that figure on the invoice — this rate applies to
                  bookings that did not store one. Toll, parking and other charges the driver adds at trip end are
                  reimbursements, so no tax is charged on them.
                </p>
              </div>
            )}

            {tab === 'style' && (
              <div className="space-y-3">
                <div className="grid grid-cols-2 gap-3">
                  {colour('Accent', 'accent')}
                  {colour('Text', 'text')}
                  {colour('Muted text', 'muted')}
                  {colour('Borders', 'border')}
                  {colour('Table header', 'headerBg')}
                </div>
                <div className="grid grid-cols-2 gap-3">
                  {field('Page margin (pt)', tpl.paper?.margin, (v) => patch((d) => { d.paper.margin = Number(v) || 0; }))}
                  {field('Base font size (pt)', tpl.paper?.fontSize, (v) => patch((d) => { d.paper.fontSize = Number(v) || 0; }))}
                </div>
                <p className="text-xs text-gray-500">Margin 16–80, font size 7–14. Anything outside that is pulled back into range when saved.</p>
              </div>
            )}
          </div>
        </div>

        {/* ── preview ────────────────────────────────────────────────────── */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-semibold text-gray-700 dark:text-gray-300">Live preview</h2>
            <span className="text-xs text-gray-500">Sample booking · {tpl.blocks.filter((b) => b.enabled !== false).length} sections</span>
          </div>
          <div className="rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-100 dark:bg-gray-800 p-4 overflow-auto max-h-[80vh]">
            <InvoicePreview t={tpl} />
          </div>
          <p className="text-xs text-gray-500">
            This is a likeness so you can see changes as you make them. Use <strong>Open PDF preview</strong> for the exact file.
          </p>
        </div>
      </div>
    </div>
  );
}
