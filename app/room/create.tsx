import { useRouter } from 'expo-router';
import { useState } from 'react';
import {
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';

import { FigurineSelector } from '@/components/FigurineSelector';
import { getFigurineById } from '@/constants/figurines';
import { COLORS } from '@/constants/theme';
import { ensureAuthSession, isSupabaseConfigured, supabase } from '@/lib/supabase';

export default function CreateRoomScreen() {
  const router = useRouter();
  const [name, setName] = useState('');
  const [scenario, setScenario] = useState('');
  const [selectedFigurineId, setSelectedFigurineId] = useState<number | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const handleCreate = async () => {
    if (!name.trim()) {
      Alert.alert('Nom requis', 'Donnez un nom à la partie.');
      return;
    }
    if (selectedFigurineId === null) {
      Alert.alert('Figurine', 'Choisissez votre figurine.');
      return;
    }
    if (!isSupabaseConfigured) {
      Alert.alert('Supabase', 'Configurez vos variables .env d\'abord.');
      return;
    }

    setSubmitting(true);
    try {
      const session = await ensureAuthSession();
      const figurine = getFigurineById(selectedFigurineId);
      if (!session?.user || !figurine) {
        return;
      }

      const { data: room, error: roomError } = await supabase
        .from('rooms')
        .insert({
          name: name.trim(),
          scenario: scenario.trim() || null,
          status: 'playing',
          host_id: session.user.id,
        })
        .select('*')
        .single();

      if (roomError || !room) {
        throw roomError ?? new Error('Création de room impossible');
      }

      const { error: playerError } = await supabase.from('players').insert({
        room_id: room.id,
        user_id: session.user.id,
        figurine_id: figurine.id,
        figurine_name: figurine.name,
      });

      if (playerError) {
        throw playerError;
      }

      await supabase.from('game_events').insert({
        room_id: room.id,
        player_id: null,
        type: 'system',
        content: `La partie « ${room.name} » commence. Que l'aventure commence !`,
      });

      router.replace(`/room/${room.id}`);
    } catch (err) {
      Alert.alert('Erreur', err instanceof Error ? err.message : 'Échec de création');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.label}>Nom de la partie</Text>
      <TextInput
        style={styles.input}
        value={name}
        onChangeText={setName}
        placeholder="Ex: Les Mines de Khaz"
        placeholderTextColor={COLORS.muted}
      />

      <Text style={styles.label}>Scénario / univers</Text>
      <TextInput
        style={[styles.input, styles.textArea]}
        value={scenario}
        onChangeText={setScenario}
        placeholder="Donjon médiéval fantasy, vaisseau spatial en détresse..."
        placeholderTextColor={COLORS.muted}
        multiline
      />

      <Text style={styles.label}>Votre figurine (hôte)</Text>
      <FigurineSelector
        selectedId={selectedFigurineId}
        onSelect={setSelectedFigurineId}
      />

      <Pressable
        style={[styles.button, submitting && styles.disabled]}
        onPress={handleCreate}
        disabled={submitting}
      >
        <Text style={styles.buttonText}>
          {submitting ? 'Création...' : 'Lancer la partie'}
        </Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  content: { padding: 16, gap: 8 },
  label: { color: COLORS.cream, fontWeight: '600', marginTop: 8 },
  input: {
    backgroundColor: COLORS.panel,
    borderWidth: 1,
    borderColor: COLORS.muted,
    borderRadius: 8,
    color: COLORS.cream,
    padding: 12,
  },
  textArea: { minHeight: 100, textAlignVertical: 'top' },
  button: {
    marginTop: 16,
    backgroundColor: COLORS.gold,
    borderRadius: 8,
    paddingVertical: 14,
    alignItems: 'center',
  },
  buttonText: { color: COLORS.background, fontWeight: '700' },
  disabled: { opacity: 0.6 },
});
