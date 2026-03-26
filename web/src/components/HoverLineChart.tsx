import { useMemo, useRef, useState, type MouseEvent } from 'react';

type HoverLineChartProps = {
  data: number[];
  color: string;
  height?: number;
  maxY?: number;
  minY?: number;
  formatValue?: (v: number) => string;
};

function clamp(n: number, a: number, b: number) {
  return Math.max(a, Math.min(b, n));
}

export function HoverLineChart({
  data,
  color,
  height = 180,
  maxY,
  minY,
  formatValue,
}: HoverLineChartProps) {
  const svgRef = useRef<SVGSVGElement | null>(null);
  const [hoverIndex, setHoverIndex] = useState<number | null>(null);
  const [hoverX, setHoverX] = useState(0);
  const [hoverY, setHoverY] = useState(0);

  const dims = useMemo(() => {
    const w = 520;
    const h = height;
    const pad = 16;
    const innerW = w - pad * 2;
    const innerH = h - pad * 2;
    return { w, h, pad, innerW, innerH };
  }, [height]);

  const yMin = minY ?? 0;
  const yMax = maxY ?? Math.max(1, ...data, yMin + 1);

  const points = useMemo(() => {
    const { pad, innerW, innerH } = dims;
    const n = data.length;
    return data.map((v, i) => {
      const x = pad + (n <= 1 ? innerW / 2 : (i / (n - 1)) * innerW);
      const t = (v - yMin) / (yMax - yMin);
      const y = pad + innerH - clamp(t, 0, 1) * innerH;
      return { x, y, v };
    });
  }, [data, dims, yMin, yMax]);

  const d = useMemo(() => {
    if (points.length === 0) return '';
    const head = `M ${points[0].x} ${points[0].y}`;
    const tail = points.slice(1).map((p) => `L ${p.x} ${p.y}`).join(' ');
    // Keep line slightly smooth.
    return `${head} ${tail}`;
  }, [points]);

  const hoverPoint = hoverIndex != null ? points[hoverIndex] : null;

  function handleMove(e: MouseEvent) {
    if (!svgRef.current) return;
    const rect = svgRef.current.getBoundingClientRect();
    const xPct = clamp((e.clientX - rect.left) / rect.width, 0, 1);
    const idx = Math.round(xPct * (data.length - 1));
    const p = points[idx];
    setHoverIndex(idx);
    setHoverX(p?.x ?? 0);
    setHoverY(p?.y ?? 0);
  }

  function handleLeave() {
    setHoverIndex(null);
  }

  return (
    <div style={{ position: 'relative', width: '100%' }}>
      <svg
        ref={svgRef}
        width="100%"
        height={height}
        viewBox={`0 0 ${dims.w} ${dims.h}`}
        preserveAspectRatio="none"
        onMouseMove={handleMove}
        onMouseLeave={handleLeave}
        style={{ display: 'block', borderRadius: 14 }}
      >
        <defs>
          <linearGradient id="hoverLineGlow" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity={0.35} />
            <stop offset="100%" stopColor={color} stopOpacity={0} />
          </linearGradient>
        </defs>

        <path
          d={d}
          fill="none"
          stroke={color}
          strokeWidth="3"
          strokeLinecap="round"
          strokeLinejoin="round"
        />

        {points.length > 1 && (
          <path
            d={`${d} L ${points[points.length - 1].x} ${dims.h - dims.pad} L ${points[0].x} ${dims.h - dims.pad} Z`}
            fill="url(#hoverLineGlow)"
            opacity={0.9}
          />
        )}

        {/* hover vertical line */}
        {hoverPoint && (
          <>
            <line
              x1={hoverX}
              x2={hoverX}
              y1={dims.pad}
              y2={dims.h - dims.pad}
              stroke={color}
              strokeWidth="1.5"
              strokeDasharray="4 4"
              opacity={0.6}
            />
            <circle cx={hoverX} cy={hoverY} r="6" fill="#fff" opacity={0.95} />
            <circle cx={hoverX} cy={hoverY} r="3.5" fill={color} opacity={0.98} />
          </>
        )}
      </svg>

      {hoverPoint && (
        <div
          style={{
            position: 'absolute',
            pointerEvents: 'none',
            left: `${clamp((hoverX / dims.w) * 100, 2, 98)}%`,
            top: `${clamp((hoverY / dims.h) * 100, 2, 98)}%`,
            transform: 'translate(-50%, -120%)',
            background: 'rgba(8, 11, 20, 0.65)',
            color: 'white',
            border: `1px solid rgba(255,255,255,0.18)`,
            boxShadow: '0 10px 30px rgba(0,0,0,0.25)',
            borderRadius: 12,
            padding: '0.35rem 0.55rem',
            fontSize: 12,
            fontWeight: 700,
            whiteSpace: 'nowrap',
          }}
        >
          {formatValue ? formatValue(hoverPoint.v) : hoverPoint.v}
        </div>
      )}
    </div>
  );
}

