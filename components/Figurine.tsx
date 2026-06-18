import { Image } from 'expo-image';
import { useEffect } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';

import { COLORS } from '@/constants/theme';
import { getSpriteOffset } from '@/lib/spriteUtils';

const SPRITE_SOURCE = require('../Assets/figurines.png');

interface FigurineProps {
  figurineId: number;
  name: string;
  color: string;
  x: number;
  y: number;
  spriteWidth: number;
  spriteHeight: number;
  size?: number;
  pending?: boolean;
  showLabel?: boolean;
}

export function Figurine({
  figurineId,
  name,
  color,
  x,
  y,
  spriteWidth,
  spriteHeight,
  size = 48,
  pending = false,
  showLabel = true,
}: FigurineProps) {
  const posX = useSharedValue(x);
  const posY = useSharedValue(y);
  const scale = size / spriteWidth;
  const { offsetX, offsetY } = getSpriteOffset(figurineId, spriteWidth, spriteHeight);

  useEffect(() => {
    posX.value = withTiming(x, { duration: 450 });
    posY.value = withTiming(y, { duration: 450 });
  }, [x, y, posX, posY]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: posX.value }, { translateY: posY.value }],
    opacity: pending ? 0.5 : 1,
  }));

  return (
    <Animated.View style={[styles.wrapper, animatedStyle]} pointerEvents="none">
      <View style={[styles.colorDot, { backgroundColor: color }]} />
      <View
        style={[
          styles.clip,
          {
            width: size,
            height: size * (spriteHeight / spriteWidth),
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
      {pending && <Text style={styles.pendingIcon}>?</Text>}
      {showLabel && (
        <Text style={styles.name} numberOfLines={1}>
          {name}
        </Text>
      )}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    position: 'absolute',
    alignItems: 'center',
    width: 72,
    marginLeft: -36,
    marginTop: -56,
  },
  clip: {
    overflow: 'hidden',
  },
  colorDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginBottom: 2,
    borderWidth: 1,
    borderColor: COLORS.gold,
  },
  name: {
    color: COLORS.cream,
    fontSize: 10,
    marginTop: 2,
    textAlign: 'center',
    maxWidth: 72,
  },
  pendingIcon: {
    position: 'absolute',
    top: 8,
    right: 4,
    color: COLORS.gold,
    fontSize: 16,
    fontWeight: '700',
  },
});
