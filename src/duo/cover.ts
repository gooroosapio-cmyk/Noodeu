export const COVER_MAX_BYTES = 5 * 1024 * 1024;
export function validateCover(file: { type: string; size: number }): string | null {
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) return 'Choisis une image JPEG, PNG ou WebP.';
  if (file.size <= 0 || file.size > COVER_MAX_BYTES) return 'Choisis une photo de 5 Mo maximum.';
  return null;
}
/** Décodage réel + réencodage : retire métadonnées EXIF, limite dimensions et format. */
export async function prepareCover(file: File): Promise<Blob> {
  const error = validateCover(file); if (error) throw new Error(error);
  const bitmap = await createImageBitmap(file).catch(() => { throw new Error('Cette image est illisible. Choisis une autre photo.'); });
  try {
    if (bitmap.width * bitmap.height > 40_000_000) throw new Error('Cette image est trop grande. Choisis une photo plus petite.');
    const canvas = document.createElement('canvas');
    const ratio = Math.min(1, 1600 / bitmap.width, 1200 / bitmap.height);
    canvas.width = Math.round(bitmap.width * ratio); canvas.height = Math.round(bitmap.height * ratio);
    const ctx = canvas.getContext('2d'); if (!ctx) throw new Error('Impossible de préparer la photo.');
    ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    return await new Promise<Blob>((resolve, reject) => canvas.toBlob(b => b && b.size <= 2 * 1024 * 1024 ? resolve(b) : reject(new Error('Cette image est trop lourde.')), 'image/webp', .84));
  } finally { bitmap.close(); }
}
