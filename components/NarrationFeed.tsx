import { useRef } from 'react';
import {
  ActivityIndicator,
  FlatList,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { IconBook2 } from '@tabler/icons-react-native';

import { COLORS, PLAYER_COLORS } from '@/constants/theme';
import { useGameStore } from '@/lib/gameStore';
import type { GameEvent } from '@/types/game';

interface NarrationFeedProps {
  narrationFontLoaded?: boolean;
}

export function NarrationFeed({ narrationFontLoaded = true }: NarrationFeedProps) {
  const events = useGameStore((s) => s.events);
  const players = useGameStore((s) => s.players);
  const isWaitingForMJ = useGameStore((s) => s.isWaitingForMJ);
  const listRef = useRef<FlatList<GameEvent>>(null);

  const renderItem = ({ item }: { item: GameEvent }) => {
    const isNarration = item.type === 'narration';
    const playerIndex = players.findIndex((p) => p.id === item.player_id);
    const borderColor =
      playerIndex >= 0
        ? PLAYER_COLORS[playerIndex % PLAYER_COLORS.length]
        : COLORS.gold;

    return (
      <View
        style={[
          styles.bubble,
          isNarration ? styles.narrationBubble : styles.actionBubble,
          !isNarration && { borderColor },
        ]}
      >
        {isNarration && (
          <View style={styles.bookIcon}>
            <IconBook2 size={16} color={COLORS.gold} />
          </View>
        )}
        <Text
          style={[
            styles.text,
            isNarration && narrationFontLoaded && styles.narrationText,
          ]}
        >
          {item.content}
        </Text>
      </View>
    );
  };

  return (
    <View style={styles.container}>
      <FlatList
        ref={listRef}
        data={events}
        keyExtractor={(item) => item.id}
        renderItem={renderItem}
        contentContainerStyle={styles.listContent}
        onContentSizeChange={() =>
          listRef.current?.scrollToEnd({ animated: true })
        }
      />
      {isWaitingForMJ && (
        <View style={styles.waitingRow}>
          <ActivityIndicator color={COLORS.gold} size="small" />
          <Text style={styles.waitingText}>Le MJ réfléchit...</Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  listContent: {
    padding: 12,
    gap: 8,
  },
  bubble: {
    borderRadius: 10,
    padding: 10,
    borderWidth: 1,
  },
  narrationBubble: {
    backgroundColor: COLORS.parchment,
    borderColor: COLORS.gold,
    flexDirection: 'row',
    gap: 8,
  },
  actionBubble: {
    backgroundColor: COLORS.panel,
    alignSelf: 'flex-end',
    maxWidth: '85%',
  },
  bookIcon: {
    marginTop: 2,
  },
  text: {
    color: COLORS.cream,
    flex: 1,
    lineHeight: 20,
  },
  narrationText: {
    fontFamily: 'IMFellEnglish_400Regular',
  },
  waitingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 12,
    paddingBottom: 8,
  },
  waitingText: {
    color: COLORS.muted,
    fontSize: 12,
  },
});
