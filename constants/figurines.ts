import { SPRITE_SHEET } from '@/lib/spriteUtils';

export interface FigurineDefinition {
  id: number;
  name: string;
  col: number;
  row: number;
}

const FIGURINE_NAMES: string[] = [
  'Dragon Rouge',
  'Chevalier',
  'Mage',
  'Orc',
  'Voleur',
  'Nain',
  'Gelée',
  'Squelette',
  'Loup',
  'Assassin',
  'Beholder',
  'Owlbear',
  'Coffre',
  'Potion',
  'Gobelin',
  'Licorne',
  'Golem',
  'Élémentaire Eau',
  'Élémentaire Feu',
  'Diablotin',
  'D20',
  'Gobelin Vert',
  'Licorne Blanche',
  'Ombre',
  'Fantôme',
  'Araignée',
  'Troll',
  'Chapeau Mage',
  'Hache',
  'Grimoire',
  'Boule Cristal',
  'Épées Croisées',
  'Caisse',
  'Cape',
  'Œuf Dragon',
  'Bottes',
  'Portail',
  'Mimic',
  'Orbe Vert',
  'Valkyrie',
];

export const FIGURINES: FigurineDefinition[] = Array.from(
  { length: SPRITE_SHEET.totalFigurines },
  (_, id) => ({
    id,
    col: id % SPRITE_SHEET.columns,
    row: Math.floor(id / SPRITE_SHEET.columns),
    name: FIGURINE_NAMES[id] ?? `Figurine ${id + 1}`,
  }),
);

export function getFigurineById(id: number): FigurineDefinition | undefined {
  return FIGURINES.find((f) => f.id === id);
}
