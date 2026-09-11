export function sanitizeFilename(filename: string): string {
  const base = filename.replace(/[\\/\0\r\n]+/g, '_').trim();
  if (!base || base === '.' || base === '..') throw new Error('Invalid filename.');
  const sanitized = base.slice(0, 240);
  if (sanitized !== base) return sanitized;
  return sanitized;
}

export function formatBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes < 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return `${value >= 10 || unit === 0 ? value.toFixed(0) : value.toFixed(1)} ${units[unit]}`;
}

export function getChunkRange(index: number, chunkSize: number, size: number): { start: number; end: number } | null {
  if (!Number.isSafeInteger(index) || index < 0 || !Number.isSafeInteger(chunkSize) || chunkSize <= 0 || size < 0) {
    throw new Error('Invalid chunk range.');
  }
  const start = index * chunkSize;
  if (start >= size) return null;
  return { start, end: Math.min(start + chunkSize - 1, size - 1) };
}

export function totalChunksFor(size: number, chunkSize: number): number {
  if (!Number.isSafeInteger(size) || size < 0 || !Number.isSafeInteger(chunkSize) || chunkSize <= 0) {
    throw new Error('Invalid transfer dimensions.');
  }
  return Math.ceil(size / chunkSize);
}
