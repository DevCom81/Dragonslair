import { buildSystemPrompt } from '@/constants/gameRules';
import { FIGURINES } from '@/constants/figurines';

describe('gameRules', () => {
  it('inclut le scénario et les joueurs dans le prompt', () => {
    const prompt = buildSystemPrompt('Donjon oublié', [
      {
        id: '1',
        room_id: 'room',
        user_id: 'u1',
        figurine_id: 0,
        figurine_name: FIGURINES[0].name,
        user_name: 'Alice',
        position_x: 0.5,
        position_y: 0.5,
        hp: 80,
        inventory: [],
        joined_at: new Date().toISOString(),
      },
    ]);

    expect(prompt).toContain('Donjon oublié');
    expect(prompt).toContain(FIGURINES[0].name);
    expect(prompt).toContain('Alice');
    expect(prompt).toContain('[DEPLACEMENT: ACCEPTE]');
  });
});

describe('figurines', () => {
  it('définit exactement 40 figurines', () => {
    expect(FIGURINES).toHaveLength(40);
    expect(FIGURINES[0].id).toBe(0);
    expect(FIGURINES[39].id).toBe(39);
  });
});
