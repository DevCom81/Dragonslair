import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/character_sheet_screen.dart';
import '../features/auth/presentation/display_name_screen.dart';
import '../features/board/presentation/board_screen.dart';
import '../features/figurines/presentation/figurine_selection_screen.dart';
import '../features/game_master/presentation/game_master_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/play_hub_screen.dart';
import '../features/lobby/presentation/lobby_screen.dart';
import '../features/rooms/presentation/create_room_screen.dart';
import '../features/rooms/presentation/join_room_by_code_screen.dart';
import '../features/rooms/presentation/room_list_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => AuthScreen(
          isSignUp: state.uri.queryParameters['mode'] != 'login',
        ),
      ),
      GoRoute(
        path: '/display-name',
        name: 'display-name',
        builder: (context, state) => const DisplayNameScreen(),
      ),
      GoRoute(
        path: '/play',
        name: 'play-hub',
        builder: (context, state) => const PlayHubScreen(),
      ),
      GoRoute(
        path: '/character-sheet',
        name: 'character-sheet',
        builder: (context, state) => const CharacterSheetScreen(),
      ),
      GoRoute(
        path: '/game-master',
        name: 'game-master',
        builder: (context, state) => const GameMasterScreen(),
      ),
      GoRoute(
        path: '/rooms',
        name: 'rooms',
        builder: (context, state) => const RoomListScreen(),
      ),
      GoRoute(
        path: '/rooms/create',
        name: 'create-room',
        builder: (context, state) => const CreateRoomScreen(),
      ),
      GoRoute(
        path: '/rooms/join',
        name: 'join-room',
        builder: (context, state) => const JoinRoomByCodeScreen(),
      ),
      GoRoute(
        path: '/rooms/:roomId/figurines',
        name: 'figurines',
        builder: (context, state) => FigurineSelectionScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/rooms/:roomId/lobby',
        name: 'lobby',
        builder: (context, state) => LobbyScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/rooms/:roomId/board',
        name: 'board',
        builder: (context, state) => BoardScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
    ],
  );
});
