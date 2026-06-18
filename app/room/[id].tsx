import { useLocalSearchParams } from 'expo-router';
import { useEffect } from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';

import { ActionPanel } from '@/components/ActionPanel';
import { GameBoard } from '@/components/GameBoard';
import { NarrationFeed } from '@/components/NarrationFeed';
import { PlayerList } from '@/components/PlayerList';
import { COLORS } from '@/constants/theme';
import { ensureAuthSession, supabase } from '@/lib/supabase';
import { useGameStore } from '@/lib/gameStore';

export default function RoomScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const roomId = Array.isArray(id) ? id[0] : id;

  const refreshRoomData = useGameStore((s) => s.refreshRoomData);
  const subscribeToRoom = useGameStore((s) => s.subscribeToRoom);
  const setCurrentPlayer = useGameStore((s) => s.setCurrentPlayer);
  const isConnected = useGameStore((s) => s.isConnected);
  const room = useGameStore((s) => s.room);

  useEffect(() => {
    if (!roomId) {
      return;
    }

    let unsubscribe = () => {};

    const init = async () => {
      await refreshRoomData(roomId);
      unsubscribe = subscribeToRoom(roomId);

      const session = await ensureAuthSession();
      if (session?.user) {
        const { data } = await supabase
          .from('players')
          .select('*')
          .eq('room_id', roomId)
          .eq('user_id', session.user.id)
          .maybeSingle();

        if (data) {
          setCurrentPlayer({
            ...data,
            inventory: Array.isArray(data.inventory) ? data.inventory : [],
          });
        }
      }
    };

    init();

    return () => {
      unsubscribe();
    };
  }, [roomId, refreshRoomData, subscribeToRoom, setCurrentPlayer]);

  if (!roomId) {
    return (
      <View style={styles.centered}>
        <Text style={styles.error}>Partie introuvable.</Text>
      </View>
    );
  }

  if (!room) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={COLORS.gold} size="large" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {!isConnected && (
        <View style={styles.banner}>
          <Text style={styles.bannerText}>Reconnexion...</Text>
        </View>
      )}

      <View style={styles.boardZone}>
        <GameBoard />
      </View>

      <View style={styles.bottomZone}>
        <NarrationFeed />
        <ActionPanel />
        <PlayerList />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: COLORS.background,
  },
  error: { color: COLORS.cream },
  banner: {
    backgroundColor: COLORS.danger,
    paddingVertical: 6,
    alignItems: 'center',
  },
  bannerText: { color: COLORS.cream, fontWeight: '600' },
  boardZone: { flex: 0.6 },
  bottomZone: { flex: 0.4, borderTopWidth: 1, borderTopColor: COLORS.gold },
});
