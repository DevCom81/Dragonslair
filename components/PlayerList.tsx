import { StyleSheet, Text, View } from 'react-native';

import { COLORS, PLAYER_COLORS } from '@/constants/theme';
import { useGameStore } from '@/lib/gameStore';

export function PlayerList() {
  const players = useGameStore((s) => s.players);

  return (
    <View style={styles.container}>
      {players.map((player, index) => (
        <View key={player.id} style={styles.playerRow}>
          <View
            style={[
              styles.avatar,
              { backgroundColor: PLAYER_COLORS[index % PLAYER_COLORS.length] },
            ]}
          />
          <View style={styles.info}>
            <Text style={styles.name}>{player.figurine_name}</Text>
            <Text style={styles.hp}>PV : {player.hp}</Text>
          </View>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  playerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: COLORS.panel,
    borderRadius: 8,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderWidth: 1,
    borderColor: COLORS.muted,
  },
  avatar: {
    width: 12,
    height: 12,
    borderRadius: 6,
  },
  info: {
    gap: 1,
  },
  name: {
    color: COLORS.cream,
    fontSize: 11,
    fontWeight: '600',
  },
  hp: {
    color: COLORS.muted,
    fontSize: 10,
  },
});
