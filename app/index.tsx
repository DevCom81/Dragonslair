import { Link, useRouter } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import { FigurineSelector } from '@/components/FigurineSelector';
import { COLORS } from '@/constants/theme';
import { getFigurineById } from '@/constants/figurines';
import { ensureAuthSession, isSupabaseConfigured, supabase } from '@/lib/supabase';
import type { Room } from '@/types/game';

export default function LobbyScreen() {
  const router = useRouter();
  const [rooms, setRooms] = useState<Room[]>([]);
  const [loading, setLoading] = useState(true);
  const [joinRoomId, setJoinRoomId] = useState<string | null>(null);
  const [selectedFigurineId, setSelectedFigurineId] = useState<number | null>(null);
  const [authReady, setAuthReady] = useState(false);

  const loadRooms = useCallback(async () => {
    if (!isSupabaseConfigured) {
      setLoading(false);
      return;
    }

    const { data, error } = await supabase
      .from('rooms')
      .select('*')
      .eq('status', 'waiting')
      .order('created_at', { ascending: false });

    if (!error && data) {
      setRooms(data as Room[]);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    if (!isSupabaseConfigured) {
      setLoading(false);
      return;
    }

    ensureAuthSession()
      .then(() => setAuthReady(true))
      .catch((err) => Alert.alert('Auth', String(err.message)));

    loadRooms();

    const channel = supabase
      .channel('lobby-rooms')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'rooms' },
        () => loadRooms(),
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [loadRooms]);

  const joinRoom = async (roomId: string) => {
    if (selectedFigurineId === null) {
      Alert.alert('Figurine', 'Choisissez une figurine avant de rejoindre.');
      return;
    }

    try {
      const session = await ensureAuthSession();
      const figurine = getFigurineById(selectedFigurineId);
      if (!figurine || !session?.user) {
        return;
      }

      const { error } = await supabase.from('players').insert({
        room_id: roomId,
        user_id: session.user.id,
        figurine_id: figurine.id,
        figurine_name: figurine.name,
      });

      if (error) {
        throw error;
      }

      setJoinRoomId(null);
      router.push(`/room/${roomId}`);
    } catch (err) {
      Alert.alert('Erreur', err instanceof Error ? err.message : 'Impossible de rejoindre');
    }
  };

  if (!isSupabaseConfigured) {
    return (
      <View style={styles.centered}>
        <Text style={styles.title}>Configuration requise</Text>
        <Text style={styles.subtitle}>
          Copiez `.env.example` vers `.env` et renseignez vos clés Supabase.
        </Text>
        <Link href="/settings" style={styles.link}>
          Paramètres IA
        </Link>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.headerActions}>
        <Link href="/room/create" asChild>
          <Pressable style={styles.primaryButton}>
            <Text style={styles.primaryButtonText}>Créer une partie</Text>
          </Pressable>
        </Link>
        <Link href="/settings" asChild>
          <Pressable style={styles.secondaryButton}>
            <Text style={styles.secondaryButtonText}>Paramètres IA</Text>
          </Pressable>
        </Link>
      </View>

      {!authReady || loading ? (
        <ActivityIndicator color={COLORS.gold} style={{ marginTop: 24 }} />
      ) : (
        <FlatList
          data={rooms}
          keyExtractor={(item) => item.id}
          ListEmptyComponent={
            <Text style={styles.empty}>Aucune partie en attente.</Text>
          }
          renderItem={({ item }) => (
            <View style={styles.roomCard}>
              <View style={{ flex: 1 }}>
                <Text style={styles.roomName}>{item.name}</Text>
                <Text style={styles.roomScenario} numberOfLines={2}>
                  {item.scenario ?? 'Sans scénario'}
                </Text>
              </View>
              <Pressable
                style={styles.joinButton}
                onPress={() => setJoinRoomId(item.id)}
              >
                <Text style={styles.joinButtonText}>Rejoindre</Text>
              </Pressable>
            </View>
          )}
        />
      )}

      {joinRoomId && (
        <View style={styles.joinOverlay}>
          <Text style={styles.overlayTitle}>Choisir votre figurine</Text>
          <FigurineSelector
            selectedId={selectedFigurineId}
            onSelect={setSelectedFigurineId}
          />
          <View style={styles.overlayActions}>
            <Pressable
              style={styles.secondaryButton}
              onPress={() => setJoinRoomId(null)}
            >
              <Text style={styles.secondaryButtonText}>Annuler</Text>
            </Pressable>
            <Pressable
              style={styles.primaryButton}
              onPress={() => joinRoom(joinRoomId)}
            >
              <Text style={styles.primaryButtonText}>Confirmer</Text>
            </Pressable>
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16 },
  centered: { flex: 1, justifyContent: 'center', padding: 24, gap: 12 },
  headerActions: { flexDirection: 'row', gap: 8, marginBottom: 16 },
  primaryButton: {
    flex: 1,
    backgroundColor: COLORS.gold,
    borderRadius: 8,
    paddingVertical: 12,
    alignItems: 'center',
  },
  primaryButtonText: { color: COLORS.background, fontWeight: '700' },
  secondaryButton: {
    flex: 1,
    borderWidth: 1,
    borderColor: COLORS.gold,
    borderRadius: 8,
    paddingVertical: 12,
    alignItems: 'center',
  },
  secondaryButtonText: { color: COLORS.gold },
  empty: { color: COLORS.muted, textAlign: 'center', marginTop: 32 },
  roomCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    backgroundColor: COLORS.panel,
    borderRadius: 10,
    padding: 12,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: COLORS.muted,
  },
  roomName: { color: COLORS.cream, fontSize: 16, fontWeight: '700' },
  roomScenario: { color: COLORS.muted, fontSize: 12, marginTop: 4 },
  joinButton: {
    backgroundColor: COLORS.gold,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  joinButtonText: { color: COLORS.background, fontWeight: '700' },
  joinOverlay: {
    ...StyleSheet.absoluteFill,
    backgroundColor: 'rgba(0,0,0,0.92)',
    padding: 16,
  },
  overlayTitle: {
    color: COLORS.cream,
    fontSize: 18,
    fontWeight: '700',
    marginBottom: 8,
  },
  overlayActions: { flexDirection: 'row', gap: 8, marginTop: 12 },
  title: { color: COLORS.cream, fontSize: 20, fontWeight: '700' },
  subtitle: { color: COLORS.muted, lineHeight: 20 },
  link: { color: COLORS.gold, marginTop: 8 },
});
