import { useId, useMemo, useRef, useState, type MouseEvent } from 'react';
import { GlassSurface } from './GlassSurface';

type LineChartProps = {
  data: number[];
  color: string;
  height?: number;
  maxY?: number;
  formatValue?: (v: number, index: number) => string;
};

function clamp(n: number, a: number, b: number) {
  return Math.max(a, Math.min(b, n));
}

function premiumTooltipStyle(isDark: boolean): React.CSSProperties {
  return {
    position: 'absolute',
    pointerEvents: 'none',
    transform: 'translate(-50%, -120%)',
    borderRadius: 12,
    padding: '0.35rem 0.55rem',
    fontSize: 12,
    fontWeight: 800,
    whiteSpace: 'nowrap',
    backdropFilter: 'blur(10px)',
    WebkitBackdropFilter: 'blur(10px)',
    background: isDark ? 'rgba(8, 11, 20, 0.65)' : 'rgba(8, 11, 20, 0.72)',
    color: 'rgba(255,255,255,0.95)',
    border: '1px solid rgba(255,255,255,0.16)',
    boxShadow: '0 10px 30px rgba(0,0,0,0.22)',
  };
}

export function MiniLineChart({ data, color, height = 120, maxY, formatValue }: LineChartProps) {
  const gid = useId().replace(/:/g, '');
  const svgRef = useRef<SVGSVGElement | null>(null);
  const [hoverIndex, setHoverIndex] = useState<number | null>(null);
  const [hoverX, setHoverX] = useState(0);
  const [hoverY, setHoverY] = useState(0);

  const w = 320;
  const h = height;
  const pad = 8;
  const max = maxY ?? Math.max(1, ...data);
  const min = 0;
  const innerW = w - pad * 2;
  const innerH = h - pad * 2;
  const n = data.length;

  const points = useMemo(() => {
    return data.map((v, i) => {
      const x = pad + (n <= 1 ? innerW / 2 : (i / (n - 1)) * innerW);
      const y = pad + innerH - ((v - min) / (max - min)) * innerH;
      return { x, y, v };
    });
  }, [data, n, innerW, innerH, pad, min, max]);

  const d = useMemo(() => {
    const pts = points.map((p) => `${p.x},${p.y}`);
    return `M ${pts.join(' L ')}`;
  }, [points]);

  const hoverPoint = hoverIndex != null ? points[hoverIndex] : null;

  function onMove(e: MouseEvent) {
    if (!svgRef.current) return;
    const rect = svgRef.current.getBoundingClientRect();
    const xPct = clamp((e.clientX - rect.left) / rect.width, 0, 1);
    const idx = Math.round(xPct * Math.max(0, n - 1));
    const p = points[idx];
    if (!p) return;
    setHoverIndex(idx);
    setHoverX(p.x);
    setHoverY(p.y);
  }

  function onLeave() {
    setHoverIndex(null);
  }

  return (
    <div style={{ position: 'relative', width: '100%' }}>
      <svg
        ref={svgRef}
        width="100%"
        height={h}
        viewBox={`0 0 ${w} ${h}`}
        preserveAspectRatio="none"
        className="ms-chart-svg"
        onMouseMove={onMove}
        onMouseLeave={onLeave}
      >
        <defs>
          <linearGradient id={gid} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.28" />
            <stop offset="100%" stopColor={color} stopOpacity="0" />
          </linearGradient>
          <filter id={`${gid}-glow`} x="-30%" y="-30%" width="160%" height="160%">
            <feGaussianBlur stdDeviation="2.4" result="blur" />
            <feColorMatrix
              in="blur"
              type="matrix"
              values="1 0 0 0 0
                      0 1 0 0 0
                      0 0 1 0 0
                      0 0 0 0.8 0"
              result="glow"
            />
            <feMerge>
              <feMergeNode in="glow" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>

        <path d={`${d} L ${pad + innerW} ${pad + innerH} L ${pad} ${pad + innerH} Z`} fill={`url(#${gid})`} />
        <path
          d={d}
          fill="none"
          stroke={color}
          strokeWidth="2.6"
          strokeLinecap="round"
          strokeLinejoin="round"
          filter={`url(#${gid}-glow)`}
        />

        {/* Hover crosshair + point */}
        {hoverPoint && (
          <>
            <line
              x1={hoverX}
              x2={hoverX}
              y1={pad}
              y2={pad + innerH}
              stroke={color}
              strokeWidth="1.2"
              strokeDasharray="4 4"
              opacity={0.55}
            />
            <circle cx={hoverX} cy={hoverY} r="6" fill="#fff" opacity={0.95} />
            <circle cx={hoverX} cy={hoverY} r="3.5" fill={color} opacity={0.98} />
          </>
        )}
      </svg>

      {hoverPoint && (
        <div
          style={{
            ...premiumTooltipStyle(false),
            left: `${clamp((hoverX / w) * 100, 2, 98)}%`,
            top: `${clamp((hoverY / h) * 100, 2, 98)}%`,
          }}
        >
          {formatValue ? formatValue(hoverPoint.v, hoverIndex as number) : hoverPoint.v}
        </div>
      )}
    </div>
  );
}

type BarChartProps = {
  labels: string[];
  values: number[];
  color?: string;
  maxY?: number;
  formatValue?: (v: number, index: number) => string;
};

export function MiniBarChart({ labels, values, color = '#3b82f6', maxY, formatValue }: BarChartProps) {
  const svgRef = useRef<SVGSVGElement | null>(null);
  const [hoverIndex, setHoverIndex] = useState<number | null>(null);
  const [hoverX, setHoverX] = useState(0);
  const [hoverY, setHoverY] = useState(0);

  const h = 140;
  const w = 320;
  const pad = { t: 12, r: 8, b: 28, l: 28 };
  const innerW = w - pad.l - pad.r;
  const innerH = h - pad.t - pad.b;
  const max = maxY ?? Math.max(1, ...values);
  const bw = innerW / values.length - 4;

  function onMove(e: MouseEvent) {
    if (!svgRef.current) return;
    const rect = svgRef.current.getBoundingClientRect();
    const x = clamp((e.clientX - rect.left) / rect.width, 0, 1) * w;
    const xInner = clamp(x - pad.l, 0, innerW);
    const i = clamp(Math.floor((xInner / innerW) * values.length), 0, values.length - 1);
    const v = values[i] ?? 0;
    const bh = (v / max) * innerH;
    const barX = pad.l + i * (innerW / values.length) + 2;
    const barY = pad.t + innerH - bh;
    setHoverIndex(i);
    setHoverX(barX + bw / 2);
    setHoverY(barY);
  }

  function onLeave() {
    setHoverIndex(null);
  }

  const hoverValue = hoverIndex != null ? values[hoverIndex] : null;
  const hoverLabel = hoverIndex != null ? labels[hoverIndex] : null;

  return (
    <div style={{ position: 'relative', width: '100%' }}>
      <svg
        ref={svgRef}
        width="100%"
        height={h}
        viewBox={`0 0 ${w} ${h}`}
        className="ms-chart-svg"
        onMouseMove={onMove}
        onMouseLeave={onLeave}
      >
        <defs>
          <linearGradient id="barGloss" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#fff" stopOpacity="0.22" />
            <stop offset="70%" stopColor="#fff" stopOpacity="0" />
          </linearGradient>
          <filter id="barShadow" x="-30%" y="-30%" width="160%" height="160%">
            <feDropShadow dx="0" dy="6" stdDeviation="6" floodColor="rgba(0,0,0,0.12)" />
          </filter>
        </defs>

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
          const active = hoverIndex === i;
          return (
            <g key={i} opacity={active ? 1 : 0.92} filter={active ? 'url(#barShadow)' : undefined}>
              <rect x={x} y={y} width={bw} height={Math.max(bh, 2)} rx="6" fill={color} />
              <rect x={x} y={y} width={bw} height={Math.max(bh, 2)} rx="6" fill="url(#barGloss)" />
              {active && <rect x={x - 1} y={y - 1} width={bw + 2} height={Math.max(bh, 2) + 2} rx="7" fill="none" stroke="#fff" opacity={0.65} />}
            </g>
          );
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

      {hoverIndex != null && hoverValue != null && (
        <div
          style={{
            ...premiumTooltipStyle(false),
            left: `${clamp((hoverX / w) * 100, 2, 98)}%`,
            top: `${clamp(((hoverY - 6) / h) * 100, 2, 98)}%`,
          }}
        >
          {hoverLabel != null ? `${hoverLabel}: ` : ''}
          {formatValue ? formatValue(hoverValue, hoverIndex) : hoverValue}
        </div>
      )}
    </div>
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
    <GlassSurface variant="light" borderRadius={16} className="ms-progress-row" backgroundOpacity={0.12} saturation={1.35} displace={0.2}>
      <div className="ms-progress-head">
        <span>{label}</span>
        <strong>{v} / 100</strong>
      </div>
      <div className="ms-progress-track">
        <div className="ms-progress-fill" style={{ width: `${v}%`, background: color }} />
      </div>
    </GlassSurface>
  );
}
