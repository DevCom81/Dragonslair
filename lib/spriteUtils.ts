import { Image } from 'react-native';

export const SPRITE_SHEET = {
  columns: 8,
  rows: 5,
  totalFigurines: 40,
} as const;

export interface SpriteDimensions {
  spriteWidth: number;
  spriteHeight: number;
  sheetWidth: number;
  sheetHeight: number;
}

/**
 * Mesure la feuille de sprites et calcule la taille d'une cellule (8×5).
 */
export function measureSprite(
  source: number,
): Promise<SpriteDimensions> {
  return new Promise((resolve, reject) => {
    Image.getSize(
      Image.resolveAssetSource(source).uri,
      (sheetWidth, sheetHeight) => {
        resolve({
          sheetWidth,
          sheetHeight,
          spriteWidth: sheetWidth / SPRITE_SHEET.columns,
          spriteHeight: sheetHeight / SPRITE_SHEET.rows,
        });
      },
      reject,
    );
  });
}

/**
 * Coordonnées de découpe pour l'index donné (0-39).
 */
export function getSpriteOffset(
  index: number,
  spriteWidth: number,
  spriteHeight: number,
) {
  const safeIndex = Math.max(0, Math.min(index, SPRITE_SHEET.totalFigurines - 1));
  const col = safeIndex % SPRITE_SHEET.columns;
  const row = Math.floor(safeIndex / SPRITE_SHEET.columns);
  return {
    offsetX: col === 0 ? 0 : -(col * spriteWidth),
    offsetY: row === 0 ? 0 : -(row * spriteHeight),
  };
}
