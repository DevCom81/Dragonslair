import { callMJ } from '@/lib/openrouter';

describe('callMJ', () => {
  beforeEach(() => {
    global.fetch = jest.fn();
  });

  it('retourne le contenu assistant', async () => {
    (global.fetch as jest.Mock).mockResolvedValue({
      ok: true,
      json: async () => ({
        choices: [{ message: { content: 'Le dragon rugit.' } }],
      }),
    });

    const result = await callMJ({
      model: 'anthropic/claude-3.5-sonnet',
      apiKey: 'test-key',
      systemPrompt: 'Tu es MJ',
      history: [],
      newUserMessage: 'J avance',
    });

    expect(result).toBe('Le dragon rugit.');
    expect(global.fetch).toHaveBeenCalledWith(
      'https://openrouter.ai/api/v1/chat/completions',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          Authorization: 'Bearer test-key',
        }),
      }),
    );
  });

  it('lève une erreur si la réponse API est invalide', async () => {
    (global.fetch as jest.Mock).mockResolvedValue({
      ok: false,
      status: 401,
      text: async () => 'Unauthorized',
    });

    await expect(
      callMJ({
        model: 'test',
        apiKey: 'bad',
        systemPrompt: 'x',
        history: [],
        newUserMessage: 'y',
      }),
    ).rejects.toThrow('OpenRouter API error (401)');
  });
});
