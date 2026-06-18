import { useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import {
  IconRun,
  IconSearch,
  IconMessage,
  IconSword,
} from '@tabler/icons-react-native';

import { COLORS } from '@/constants/theme';
import { useGameStore } from '@/lib/gameStore';

const QUICK_ACTIONS = [
  { label: 'Attaquer', template: "J'attaque l'ennemi le plus proche", icon: IconSword },
  { label: 'Inspecter', template: "J'inspecte les alentours", icon: IconSearch },
  { label: 'Parler', template: "Je m'adresse aux personnages présents", icon: IconMessage },
  { label: 'Fuir', template: 'Je tente de fuir la zone', icon: IconRun },
] as const;

export function ActionPanel() {
  const [text, setText] = useState('');
  const submitAction = useGameStore((s) => s.submitAction);
  const isWaitingForMJ = useGameStore((s) => s.isWaitingForMJ);

  const handleSubmit = async (action: string) => {
    if (!action.trim() || isWaitingForMJ) {
      return;
    }
    setText('');
    await submitAction(action);
  };

  return (
    <View style={styles.container}>
      <View style={styles.quickRow}>
        {QUICK_ACTIONS.map(({ label, template, icon: Icon }) => (
          <Pressable
            key={label}
            style={styles.quickButton}
            onPress={() => handleSubmit(template)}
            disabled={isWaitingForMJ}
          >
            <Icon size={16} color={COLORS.gold} />
            <Text style={styles.quickLabel}>{label}</Text>
          </Pressable>
        ))}
      </View>
      <View style={styles.inputRow}>
        <TextInput
          style={styles.input}
          placeholder="Décrivez votre action..."
          placeholderTextColor={COLORS.muted}
          value={text}
          onChangeText={setText}
          editable={!isWaitingForMJ}
          onSubmitEditing={() => handleSubmit(text)}
        />
        <Pressable
          style={[styles.sendButton, isWaitingForMJ && styles.disabled]}
          onPress={() => handleSubmit(text)}
          disabled={isWaitingForMJ}
        >
          {isWaitingForMJ ? (
            <ActivityIndicator color={COLORS.gold} size="small" />
          ) : (
            <Text style={styles.sendText}>Envoyer</Text>
          )}
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    gap: 8,
  },
  quickRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  quickButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: COLORS.panel,
    borderWidth: 1,
    borderColor: COLORS.gold,
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  quickLabel: {
    color: COLORS.cream,
    fontSize: 12,
  },
  inputRow: {
    flexDirection: 'row',
    gap: 8,
  },
  input: {
    flex: 1,
    backgroundColor: COLORS.panel,
    borderWidth: 1,
    borderColor: COLORS.muted,
    borderRadius: 8,
    color: COLORS.cream,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  sendButton: {
    justifyContent: 'center',
    paddingHorizontal: 14,
    backgroundColor: COLORS.gold,
    borderRadius: 8,
  },
  sendText: {
    color: COLORS.background,
    fontWeight: '700',
  },
  disabled: {
    opacity: 0.6,
  },
});
