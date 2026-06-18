import { useEffect, useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';

import { COLORS } from '@/constants/theme';
import { DEFAULT_MODEL, useGameStore } from '@/lib/gameStore';

const PRESET_MODELS = [
  'anthropic/claude-3.5-sonnet',
  'anthropic/claude-3-haiku',
  'google/gemini-pro-1.5',
  'meta-llama/llama-3.1-70b-instruct',
  'mistralai/mistral-large',
] as const;

export default function SettingsScreen() {
  const openrouterApiKey = useGameStore((s) => s.openrouterApiKey);
  const selectedModel = useGameStore((s) => s.selectedModel);
  const setApiKey = useGameStore((s) => s.setApiKey);
  const setModel = useGameStore((s) => s.setModel);
  const loadSettings = useGameStore((s) => s.loadSettings);

  const [apiKeyInput, setApiKeyInput] = useState('');
  const [customModel, setCustomModel] = useState('');
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    loadSettings();
  }, [loadSettings]);

  useEffect(() => {
    setApiKeyInput(openrouterApiKey);
    if (!PRESET_MODELS.includes(selectedModel as (typeof PRESET_MODELS)[number])) {
      setCustomModel(selectedModel);
    }
  }, [openrouterApiKey, selectedModel]);

  const saveSettings = async () => {
    await setApiKey(apiKeyInput.trim());
    const modelToSave = customModel.trim() || selectedModel || DEFAULT_MODEL;
    await setModel(modelToSave);
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.label}>Clé API OpenRouter</Text>
      <Text style={styles.hint}>
        Stockée localement via SecureStore. Jamais envoyée à Supabase.
      </Text>
      <TextInput
        style={styles.input}
        value={apiKeyInput}
        onChangeText={setApiKeyInput}
        placeholder="sk-or-..."
        placeholderTextColor={COLORS.muted}
        secureTextEntry
        autoCapitalize="none"
      />

      <Text style={styles.label}>Modèle IA</Text>
      <View style={styles.modelList}>
        {PRESET_MODELS.map((model) => {
          const active = selectedModel === model && !customModel.trim();
          return (
            <Pressable
              key={model}
              style={[styles.modelChip, active && styles.modelChipActive]}
              onPress={() => {
                setCustomModel('');
                setModel(model);
              }}
            >
              <Text style={[styles.modelText, active && styles.modelTextActive]}>
                {model}
              </Text>
            </Pressable>
          );
        })}
      </View>

      <Text style={styles.label}>Modèle personnalisé OpenRouter</Text>
      <TextInput
        style={styles.input}
        value={customModel}
        onChangeText={setCustomModel}
        placeholder="provider/model-name"
        placeholderTextColor={COLORS.muted}
        autoCapitalize="none"
      />

      <Pressable style={styles.button} onPress={saveSettings}>
        <Text style={styles.buttonText}>
          {saved ? 'Enregistré ✓' : 'Enregistrer'}
        </Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  content: { padding: 16, gap: 8 },
  label: { color: COLORS.cream, fontWeight: '700', marginTop: 8 },
  hint: { color: COLORS.muted, fontSize: 12 },
  input: {
    backgroundColor: COLORS.panel,
    borderWidth: 1,
    borderColor: COLORS.muted,
    borderRadius: 8,
    color: COLORS.cream,
    padding: 12,
  },
  modelList: { gap: 8, marginTop: 4 },
  modelChip: {
    borderWidth: 1,
    borderColor: COLORS.muted,
    borderRadius: 8,
    padding: 10,
    backgroundColor: COLORS.panel,
  },
  modelChipActive: {
    borderColor: COLORS.gold,
    backgroundColor: COLORS.parchment,
  },
  modelText: { color: COLORS.cream, fontSize: 12 },
  modelTextActive: { color: COLORS.gold, fontWeight: '700' },
  button: {
    marginTop: 16,
    backgroundColor: COLORS.gold,
    borderRadius: 8,
    paddingVertical: 14,
    alignItems: 'center',
  },
  buttonText: { color: COLORS.background, fontWeight: '700' },
});
