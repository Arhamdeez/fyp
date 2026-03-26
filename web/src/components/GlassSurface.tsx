import { type CSSProperties, type ReactNode } from 'react';
import './GlassSurface.css';

export type GlassSurfaceProps = {
  children: ReactNode;
  borderRadius?: number;
  width?: string | number;
  height?: string | number;
  minHeight?: string | number;
  backgroundOpacity?: number;
  saturation?: number;
  displace?: number;
  className?: string;
  variant?: 'light' | 'dark' | 'tinted';
};

/**
 * Premium frosted / tinted panel — blur-only (no SVG displacement).
 * Reads clean on all browsers; displacement on backdrop often looked muddy.
 */
export function GlassSurface({
  children,
  borderRadius = 20,
  width = '100%',
  height,
  minHeight,
  backgroundOpacity,
  saturation,
  displace,
  className = '',
  variant = 'light',
}: GlassSurfaceProps) {
  const bgAlpha =
    backgroundOpacity ??
    (variant === 'dark' ? 0.82 : variant === 'tinted' ? 0.16 : 0.78);
  const sat = saturation ?? (variant === 'dark' ? 1.2 : 1.65);
  // Maps `displace` into a blur amount so pages using `displace` still get stronger glass.
  const blurPx = Math.round(24 + (displace ?? 0) * 70);
  const borderAlpha =
    variant === 'dark'
      ? Math.min(0.25, bgAlpha * 0.26)
      : Math.min(0.95, bgAlpha * 1.2);

  const style = {
    borderRadius: `${borderRadius}px`,
    width: typeof width === 'number' ? `${width}px` : width,
    height: height != null ? (typeof height === 'number' ? `${height}px` : height) : undefined,
    minHeight: minHeight != null ? (typeof minHeight === 'number' ? `${minHeight}px` : minHeight) : undefined,
    // CSS vars consumed by `GlassSurface.css`
    ['--gs-bg-alpha' as string]: bgAlpha.toString(),
    ['--gs-sat' as string]: sat.toString(),
    ['--gs-blur' as string]: `${blurPx}px`,
    ['--gs-border-alpha' as string]: borderAlpha.toString(),
  } as CSSProperties;

  return (
    <div className={['gs-elite', `gs-elite--${variant}`, className].filter(Boolean).join(' ')} style={style}>
      {children}
    </div>
  );
}
