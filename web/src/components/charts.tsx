import { useId } from 'react';

type LineChartProps = {
  data: number[];
  color: string;
  height?: number;
  maxY?: number;
};

export function MiniLineChart({ data, color, height = 120, maxY }: LineChartProps) {
  const gid = useId().replace(/:/g, '');
  const w = 320;
  const h = height;
  const pad = 8;
  const max = maxY ?? Math.max(1, ...data);
  const min = 0;
  const innerW = w - pad * 2;
  const innerH = h - pad * 2;
  const n = data.length;
  const pts = data.map((v, i) => {
    const x = pad + (n <= 1 ? innerW / 2 : (i / (n - 1)) * innerW);
    const y = pad + innerH - ((v - min) / (max - min)) * innerH;
    return `${x},${y}`;
  });
  const d = `M ${pts.join(' L ')}`;
  return (
    <svg width="100%" height={h} viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" className="ms-chart-svg">
      <defs>
        <linearGradient id={gid} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.25" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path
        d={`${d} L ${pad + innerW} ${pad + innerH} L ${pad} ${pad + innerH} Z`}
        fill={`url(#${gid})`}
      />
      <path d={d} fill="none" stroke={color} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
      {data.map((v, i) => {
        const x = pad + (n <= 1 ? innerW / 2 : (i / (n - 1)) * innerW);
        const y = pad + innerH - ((v - min) / (max - min)) * innerH;
        return <circle key={i} cx={x} cy={y} r="4" fill="#fff" stroke={color} strokeWidth="2" />;
      })}
    </svg>
  );
}

type BarChartProps = {
  labels: string[];
  values: number[];
  color?: string;
  maxY?: number;
};

export function MiniBarChart({ labels, values, color = '#3b82f6', maxY }: BarChartProps) {
  const h = 140;
  const w = 320;
  const pad = { t: 12, r: 8, b: 28, l: 28 };
  const innerW = w - pad.l - pad.r;
  const innerH = h - pad.t - pad.b;
  const max = maxY ?? Math.max(1, ...values);
  const bw = innerW / values.length - 4;
  return (
    <svg width="100%" height={h} viewBox={`0 0 ${w} ${h}`} className="ms-chart-svg">
      {[0, 0.25, 0.5, 0.75, 1].map((t) => (
        <line
          key={t}
          x1={pad.l}
          x2={w - pad.r}
          y1={pad.t + innerH * (1 - t)}
          y2={pad.t + innerH * (1 - t)}
          stroke="var(--ms-border)"
          strokeWidth="1"
        />
      ))}
      {values.map((v, i) => {
        const bh = (v / max) * innerH;
        const x = pad.l + i * (innerW / values.length) + 2;
        const y = pad.t + innerH - bh;
        return <rect key={i} x={x} y={y} width={bw} height={Math.max(bh, 2)} rx="4" fill={color} />;
      })}
      {labels.map((lab, i) => (
        <text
          key={lab}
          x={pad.l + i * (innerW / values.length) + bw / 2 + 2}
          y={h - 8}
          textAnchor="middle"
          fontSize="10"
          fill="var(--ms-text-muted)"
        >
          {lab}
        </text>
      ))}
    </svg>
  );
}

type DonutProps = { value: number; size?: number };

export function ScoreDonut({ value, size = 140 }: DonutProps) {
  const r = 52;
  const c = 2 * Math.PI * r;
  const pct = Math.min(100, Math.max(0, value)) / 100;
  return (
    <svg width={size} height={size} viewBox="0 0 120 120" className="ms-donut">
      <circle cx="60" cy="60" r={r} fill="none" stroke="rgba(255,255,255,0.35)" strokeWidth="12" />
      <circle
        cx="60"
        cy="60"
        r={r}
        fill="none"
        stroke="#fff"
        strokeWidth="12"
        strokeDasharray={`${c * pct} ${c}`}
        strokeLinecap="round"
        transform="rotate(-90 60 60)"
      />
    </svg>
  );
}

type ProgressRowProps = { label: string; value: number; color: string };

export function ProgressRow({ label, value, color }: ProgressRowProps) {
  const v = Math.min(100, Math.max(0, value));
  return (
    <div className="ms-progress-row">
      <div className="ms-progress-head">
        <span>{label}</span>
        <strong>{v} / 100</strong>
      </div>
      <div className="ms-progress-track">
        <div className="ms-progress-fill" style={{ width: `${v}%`, background: color }} />
      </div>
    </div>
  );
}
