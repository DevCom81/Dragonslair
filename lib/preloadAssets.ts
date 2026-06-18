import { Asset } from 'expo-asset';
import { useEffect } from 'react';

const BOARD = require('../assets/Plateau.png');
const SPRITES = require('../assets/figurines.png');

export function usePreloadAssets() {
  useEffect(() => {
    Asset.loadAsync([BOARD, SPRITES]).catch(() => {});
  }, []);
}
