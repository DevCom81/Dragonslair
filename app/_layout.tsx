import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { useFonts, IMFellEnglish_400Regular } from '@expo-google-fonts/im-fell-english';

import { COLORS } from '@/constants/theme';
import { usePreloadAssets } from '@/lib/preloadAssets';
import { useGameStore } from '@/lib/gameStore';

export default function RootLayout() {
  const loadSettings = useGameStore((s) => s.loadSettings);
  const [fontsLoaded] = useFonts({ IMFellEnglish_400Regular });

  usePreloadAssets();

  useEffect(() => {
    loadSettings();
  }, [loadSettings]);

  if (!fontsLoaded) {
    return null;
  }

  return (
    <GestureHandlerRootView style={{ flex: 1, backgroundColor: COLORS.background }}>
      <StatusBar style="light" />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: COLORS.background },
          headerTintColor: COLORS.gold,
          headerTitleStyle: { color: COLORS.cream },
          contentStyle: { backgroundColor: COLORS.background },
        }}
      >
        <Stack.Screen name="index" options={{ title: 'Lobby' }} />
        <Stack.Screen name="settings" options={{ title: 'Paramètres IA' }} />
        <Stack.Screen name="room/create" options={{ title: 'Nouvelle partie' }} />
        <Stack.Screen name="room/[id]" options={{ title: 'Partie', headerBackVisible: false }} />
      </Stack>
    </GestureHandlerRootView>
  );
}
