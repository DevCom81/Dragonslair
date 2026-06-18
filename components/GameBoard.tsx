import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  LayoutChangeEvent,
  StyleSheet,
  View,
} from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  runOnJS,
  useAnimatedStyle,
  useSharedValue,
} from 'react-native-reanimated';

import { Figurine } from '@/components/Figurine';
import { PLAYER_COLORS } from '@/constants/theme';
import { measureSprite } from '@/lib/spriteUtils';
import { useGameStore } from '@/lib/gameStore';
import type { Player } from '@/types/game';

const BOARD_SOURCE = require('../assets/Plateau.png');
const SPRITE_SOURCE = require('../assets/figurines.png');

interface GameBoardProps {
  onMoveRequest?: (x: number, y: number) => void;
}

function playerColor(index: number) {
  return PLAYER_COLORS[index % PLAYER_COLORS.length];
}

export function GameBoard({ onMoveRequest }: GameBoardProps) {
  const players = useGameStore((s) => s.players);
  const currentPlayer = useGameStore((s) => s.currentPlayer);
  const pendingMove = useGameStore((s) => s.pendingMove);
  const requestMove = useGameStore((s) => s.requestMove);

  const [layout, setLayout] = useState({ width: 0, height: 0 });
  const [spriteDims, setSpriteDims] = useState({
    spriteWidth: 128,
    spriteHeight: 307.2,
  });
  const [imageSize, setImageSize] = useState({ width: 1024, height: 1536 });

  const scale = useSharedValue(1);
  const translateX = useSharedValue(0);
  const translateY = useSharedValue(0);
  const savedScale = useSharedValue(1);
  const savedTranslateX = useSharedValue(0);
  const savedTranslateY = useSharedValue(0);

  useEffect(() => {
    measureSprite(SPRITE_SOURCE)
      .then((dims) => {
        setSpriteDims({
          spriteWidth: dims.spriteWidth,
          spriteHeight: dims.spriteHeight,
        });
        setImageSize({
          width: dims.sheetWidth,
          height: dims.sheetHeight,
        });
      })
      .catch(() => {});
  }, []);

  const boardMetrics = useMemo(() => {
    if (layout.width === 0 || layout.height === 0) {
      return { displayWidth: 0, displayHeight: 0, offsetX: 0, offsetY: 0 };
    }

    const imageRatio = imageSize.width / imageSize.height;
    const layoutRatio = layout.width / layout.height;

    let displayWidth = layout.width;
    let displayHeight = layout.height;

    if (imageRatio > layoutRatio) {
      displayHeight = layout.width / imageRatio;
    } else {
      displayWidth = layout.height * imageRatio;
    }

    return {
      displayWidth,
      displayHeight,
      offsetX: (layout.width - displayWidth) / 2,
      offsetY: (layout.height - displayHeight) / 2,
    };
  }, [imageSize, layout]);

  const handleLayout = useCallback((event: LayoutChangeEvent) => {
    const { width, height } = event.nativeEvent.layout;
    setLayout({ width, height });
  }, []);

  const confirmMove = useCallback(
    (relativeX: number, relativeY: number) => {
      Alert.alert(
        'Déplacement',
        'Se déplacer ici ?',
        [
          { text: 'Annuler', style: 'cancel' },
          {
            text: 'Confirmer',
            onPress: () => {
              if (onMoveRequest) {
                onMoveRequest(relativeX, relativeY);
              } else {
                requestMove(relativeX, relativeY);
              }
            },
          },
        ],
      );
    },
    [onMoveRequest, requestMove],
  );

  const handleBoardTap = useCallback(
    (tapX: number, tapY: number) => {
      if (boardMetrics.displayWidth === 0) {
        return;
      }

      const localX = (tapX - boardMetrics.offsetX) / scale.value - translateX.value / scale.value;
      const localY = (tapY - boardMetrics.offsetY) / scale.value - translateY.value / scale.value;

      const relativeX = Math.min(
        1,
        Math.max(0, localX / boardMetrics.displayWidth),
      );
      const relativeY = Math.min(
        1,
        Math.max(0, localY / boardMetrics.displayHeight),
      );

      confirmMove(relativeX, relativeY);
    },
    [boardMetrics, confirmMove, scale, translateX, translateY],
  );

  const doubleTap = Gesture.Tap()
    .numberOfTaps(2)
    .onEnd((event) => {
      runOnJS(handleBoardTap)(event.x, event.y);
    });

  const pinch = Gesture.Pinch()
    .onUpdate((event) => {
      scale.value = Math.min(3, Math.max(0.8, savedScale.value * event.scale));
    })
    .onEnd(() => {
      savedScale.value = scale.value;
    });

  const pan = Gesture.Pan()
    .onUpdate((event) => {
      translateX.value = savedTranslateX.value + event.translationX;
      translateY.value = savedTranslateY.value + event.translationY;
    })
    .onEnd(() => {
      savedTranslateX.value = translateX.value;
      savedTranslateY.value = translateY.value;
    });

  const composed = Gesture.Simultaneous(pinch, pan, doubleTap);

  const animatedBoardStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { translateY: translateY.value },
      { scale: scale.value },
    ],
  }));

  const renderFigurine = (player: Player, index: number, pending = false) => {
    const x =
      boardMetrics.offsetX +
      player.position_x * boardMetrics.displayWidth -
      36;
    const y =
      boardMetrics.offsetY +
      player.position_y * boardMetrics.displayHeight -
      56;

    return (
      <Figurine
        key={player.id}
        figurineId={player.figurine_id}
        name={player.figurine_name}
        color={playerColor(index)}
        x={x}
        y={y}
        spriteWidth={spriteDims.spriteWidth}
        spriteHeight={spriteDims.spriteHeight}
        pending={pending}
      />
    );
  };

  return (
    <View style={styles.container} onLayout={handleLayout}>
      <GestureDetector gesture={composed}>
        <Animated.View style={[styles.boardContainer, animatedBoardStyle]}>
          <Animated.Image
            source={BOARD_SOURCE}
            style={{
              width: boardMetrics.displayWidth,
              height: boardMetrics.displayHeight,
              marginLeft: boardMetrics.offsetX,
              marginTop: boardMetrics.offsetY,
              resizeMode: 'contain',
            }}
          />
          {players.map((player, index) => renderFigurine(player, index))}
          {pendingMove && currentPlayer &&
            renderFigurine(
              {
                ...currentPlayer,
                position_x: pendingMove.x,
                position_y: pendingMove.y,
              },
              players.findIndex((p) => p.id === currentPlayer.id),
              true,
            )}
        </Animated.View>
      </GestureDetector>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    overflow: 'hidden',
    backgroundColor: '#050505',
  },
  boardContainer: {
    flex: 1,
  },
});
