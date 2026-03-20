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
  className = '',
  variant = 'light',
}: GlassSurfaceProps) {
  const style = {
    borderRadius: `${borderRadius}px`,
    width: typeof width === 'number' ? `${width}px` : width,
    height: height != null ? (typeof height === 'number' ? `${height}px` : height) : undefined,
    minHeight: minHeight != null ? (typeof minHeight === 'number' ? `${minHeight}px` : minHeight) : undefined,
  } as CSSProperties;

  return (
    <div className={['gs-elite', `gs-elite--${variant}`, className].filter(Boolean).join(' ')} style={style}>
      {children}
    </div>
  );
}
