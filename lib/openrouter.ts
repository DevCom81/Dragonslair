const OPENROUTER_API_URL = 'https://openrouter.ai/api/v1/chat/completions';

export interface Message {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export async function callMJ(params: {
  model: string;
  apiKey: string;
  systemPrompt: string;
  history: Message[];
  newUserMessage: string;
}): Promise<string> {
  const response = await fetch(OPENROUTER_API_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${params.apiKey}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': 'rpg-mobile-app',
    },
    body: JSON.stringify({
      model: params.model,
      messages: [
        { role: 'system', content: params.systemPrompt },
        ...params.history,
        { role: 'user', content: params.newUserMessage },
      ],
      max_tokens: 600,
      temperature: 0.85,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenRouter API error (${response.status}): ${errorText}`);
  }

  const data = await response.json();
  const content = data?.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error('Réponse OpenRouter invalide');
  }
  return content as string;
}
