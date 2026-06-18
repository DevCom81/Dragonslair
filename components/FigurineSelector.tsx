import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Image } from 'expo-image';

import { FIGURINES } from '@/constants/figurines';
import { COLORS } from '@/constants/theme';
import { getSpriteOffset } from '@/lib/spriteUtils';

const SPRITE_SOURCE = require('../Assets/figurines.png');

interface FigurineSelectorProps {
  selectedId: number | null;
  onSelect: (id: number) => void;
  spriteWidth?: number;
  spriteHeight?: number;
}

export function FigurineSelector({
  selectedId,
  onSelect,
  spriteWidth = 128,
  spriteHeight = 307.2,
}: FigurineSelectorProps) {
  const thumbSize = 56;
  const scale = thumbSize / spriteWidth;

  return (
    <ScrollView contentContainerStyle={styles.grid}>
      {FIGURINES.map((figurine) => {
        const { offsetX, offsetY } = getSpriteOffset(
          figurine.id,
          spriteWidth,
          spriteHeight,
        );
        const selected = selectedId === figurine.id;

        return (
          <Pressable
            key={figurine.id}
            style={[styles.cell, selected && styles.selectedCell]}
            onPress={() => onSelect(figurine.id)}
          >
            <View
              style={[
                styles.clip,
                {
                  width: thumbSize,
                  height: thumbSize * (spriteHeight / spriteWidth),
                },
              ]}
            >
              <Image
                source={SPRITE_SOURCE}
                style={{
                  width: spriteWidth * scale * 8,
                  height: spriteHeight * scale * 5,
                  transform: [
                    { translateX: offsetX * scale },
                    { translateY: offsetY * scale },
                  ],
                }}
                contentFit="fill"
              />
            </View>
            <Text style={styles.label} numberOfLines={1}>
              {figurine.name}
            </Text>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    padding: 8,
  },
  cell: {
    width: '23%',
    alignItems: 'center',
    padding: 6,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: 'transparent',
    backgroundColor: COLORS.panel,
  },
  selectedCell: {
    borderColor: COLORS.gold,
  },
  clip: {
    overflow: 'hidden',
  },
  label: {
    color: COLORS.cream,
    fontSize: 9,
    marginTop: 4,
    textAlign: 'center',
  },
});
