import { Asset } from 'expo-asset';
import { useEffect } from 'react';

const BOARD = require('../Assets/plateau.png');
const SPRITES = require('../Assets/figurines.png');

export function usePreloadAssets() {
  useEffect(() => {
    Asset.loadAsync([BOARD, SPRITES]).catch(() => {});
  }, []);
}
