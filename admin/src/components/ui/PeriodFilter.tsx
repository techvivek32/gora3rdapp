'use client';

import { useMemo, useState } from 'react';
import { Select } from '@/components/ui/Select';

/** Emitted date window. Both undefined = "All time" (no filtering). */
export interface PeriodRange {
  dateFrom?: string;
  dateTo?: string;
}

type Mode = 'all' | 'year' | 'month' | 'week';

const startOfDay = (d: Date) => {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
};
const endOfDay = (d: Date) => {
  const x = new Date(d);
  x.setHours(23, 59, 59, 999);
  return x;
};

/**
 * Reusable period filter: pick All time / Year (last 5) / Month (last 12) /
 * Week (last 8), then the specific value. Emits an inclusive ISO date range via
 * `onChange`. Defaults to "All time" so a page looks unchanged until used.
 */
export function PeriodFilter({
  onChange,
  className,
}: {
  onChange: (range: PeriodRange) => void;
  className?: string;
}) {
  const now = useMemo(() => new Date(), []);
  const currentYear = now.getFullYear();

  const years = useMemo(
    () => Array.from({ length: 5 }, (_, i) => currentYear - i),
    [currentYear],
  );

  const months = useMemo(() => {
    const arr: { value: string; label: string; from: Date; to: Date }[] = [];
    for (let i = 0; i < 12; i++) {
      const d = new Date(currentYear, now.getMonth() - i, 1);
      arr.push({
        value: `${d.getFullYear()}-${d.getMonth()}`,
        label: d.toLocaleString('en-US', { month: 'short', year: 'numeric' }),
        from: new Date(d.getFullYear(), d.getMonth(), 1),
        to: new Date(d.getFullYear(), d.getMonth() + 1, 0),
      });
    }
    return arr;
  }, [currentYear, now]);

  const weeks = useMemo(() => {
    const arr: { value: string; label: string; from: Date; to: Date }[] = [];
    // Week starts Monday.
    const diffToMon = (now.getDay() + 6) % 7;
    const thisMon = startOfDay(new Date(now));
    thisMon.setDate(now.getDate() - diffToMon);
    for (let i = 0; i < 8; i++) {
      const from = new Date(thisMon);
      from.setDate(thisMon.getDate() - 7 * i);
      const to = new Date(from);
      to.setDate(from.getDate() + 6);
      const label =
        i === 0
          ? 'This week'
          : i === 1
            ? 'Last week'
            : `${from.toLocaleDateString('en-US', { day: 'numeric', month: 'short' })} – ${to.toLocaleDateString('en-US', { day: 'numeric', month: 'short' })}`;
      arr.push({ value: `w${i}`, label, from, to });
    }
    return arr;
  }, [now]);

  const [mode, setMode] = useState<Mode>('all');
  const [yearSel, setYearSel] = useState(currentYear);
  const [monthSel, setMonthSel] = useState(months[0].value);
  const [weekSel, setWeekSel] = useState('w1'); // default = last week

  const emit = (m: Mode, y: number, mo: string, w: string) => {
    if (m === 'all') return onChange({});
    if (m === 'year') {
      return onChange({
        dateFrom: startOfDay(new Date(y, 0, 1)).toISOString(),
        dateTo: endOfDay(new Date(y, 11, 31)).toISOString(),
      });
    }
    if (m === 'month') {
      const it = months.find((x) => x.value === mo) ?? months[0];
      return onChange({ dateFrom: startOfDay(it.from).toISOString(), dateTo: endOfDay(it.to).toISOString() });
    }
    const it = weeks.find((x) => x.value === w) ?? weeks[1];
    return onChange({ dateFrom: startOfDay(it.from).toISOString(), dateTo: endOfDay(it.to).toISOString() });
  };

  return (
    <div className={`flex items-center gap-2 ${className ?? ''}`}>
      <Select
        value={mode}
        onChange={(e) => {
          const m = e.target.value as Mode;
          setMode(m);
          emit(m, yearSel, monthSel, weekSel);
        }}
        aria-label="Period"
      >
        <option value="all">All time</option>
        <option value="year">Yearly</option>
        <option value="month">Monthly</option>
        <option value="week">Weekly</option>
      </Select>

      {mode === 'year' && (
        <Select
          value={yearSel}
          onChange={(e) => {
            const y = Number(e.target.value);
            setYearSel(y);
            emit('year', y, monthSel, weekSel);
          }}
          aria-label="Year"
        >
          {years.map((y) => (
            <option key={y} value={y}>
              {y}
            </option>
          ))}
        </Select>
      )}

      {mode === 'month' && (
        <Select
          value={monthSel}
          onChange={(e) => {
            setMonthSel(e.target.value);
            emit('month', yearSel, e.target.value, weekSel);
          }}
          aria-label="Month"
        >
          {months.map((m) => (
            <option key={m.value} value={m.value}>
              {m.label}
            </option>
          ))}
        </Select>
      )}

      {mode === 'week' && (
        <Select
          value={weekSel}
          onChange={(e) => {
            setWeekSel(e.target.value);
            emit('week', yearSel, monthSel, e.target.value);
          }}
          aria-label="Week"
        >
          {weeks.map((w) => (
            <option key={w.value} value={w.value}>
              {w.label}
            </option>
          ))}
        </Select>
      )}
    </div>
  );
}
