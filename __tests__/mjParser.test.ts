import { parseMJResponse } from '@/lib/mjParser';

describe('parseMJResponse', () => {
  it('extrait la narration sans les tokens', () => {
    const parsed = parseMJResponse(
      'La porte grince. [DEPLACEMENT: ACCEPTE] [PV: Chevalier -10]',
    );

    expect(parsed.narration).toBe('La porte grince.');
    expect(parsed.movementAccepted).toBe(true);
    expect(parsed.hpChanges).toEqual([{ figurineName: 'Chevalier', delta: -10 }]);
  });

  it('détecte un déplacement refusé avec raison', () => {
    const parsed = parseMJResponse(
      'Un mur invisible vous bloque. [DEPLACEMENT: REFUSE - passage interdit]',
    );

    expect(parsed.movementAccepted).toBe(false);
    expect(parsed.movementReason).toBe('passage interdit');
  });

  it('extrait les ajouts d inventaire', () => {
    const parsed = parseMJResponse(
      'Vous trouvez un artefact. [INVENTAIRE: Mage +Amulette de feu]',
    );

    expect(parsed.inventoryChanges).toEqual([
      { figurineName: 'Mage', item: 'Amulette de feu' },
    ]);
  });
});
