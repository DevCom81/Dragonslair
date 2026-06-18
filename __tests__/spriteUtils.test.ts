import { getSpriteOffset, SPRITE_SHEET } from '@/lib/spriteUtils';

describe('spriteUtils', () => {
  it('expose une grille 8x5 de 40 figurines', () => {
    expect(SPRITE_SHEET.columns).toBe(8);
    expect(SPRITE_SHEET.rows).toBe(5);
    expect(SPRITE_SHEET.totalFigurines).toBe(40);
  });

  it('calcule le décalage de la première figurine à (0,0)', () => {
    const offset = getSpriteOffset(0, 128, 307.2);
    expect(offset.offsetX).toBe(0);
    expect(offset.offsetY).toBe(0);
  });

  it('calcule le décalage de la figurine en colonne 1', () => {
    const offset = getSpriteOffset(1, 128, 307.2);
    expect(offset.offsetX).toBe(-128);
    expect(offset.offsetY).toBe(0);
  });

  it('calcule le décalage de la figurine en ligne 2 colonne 0', () => {
    const offset = getSpriteOffset(16, 128, 307.2);
    expect(offset.offsetX).toBe(0);
    expect(offset.offsetY).toBe(-614.4);
  });

  it('borne les index hors limites', () => {
    const low = getSpriteOffset(-5, 100, 100);
    const high = getSpriteOffset(999, 100, 100);
    expect(low).toEqual(getSpriteOffset(0, 100, 100));
    expect(high).toEqual(getSpriteOffset(39, 100, 100));
  });
});
