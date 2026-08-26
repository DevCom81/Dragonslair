# DragonsLair

Application mobile Flutter de jeu de role multijoueur medieval-fantasy avec maitre du jeu IA.

## Etat

Phase 1 en cours : bootstrap Flutter, theme, configuration, modeles Supabase et auth anonyme MVP.

## Stack

- Flutter / Dart
- Riverpod
- go_router
- Supabase Auth, PostgreSQL et Realtime
- Backend MJ IA FastAPI sur Railway
- OpenRouter avec `google/gemini-3.1-flash-lite`

## Assets

Les assets reels sont conserves dans `Assets/`.

Ne pas renommer ce dossier et ne pas remplacer les images existantes par des placeholders.

## Configuration

Les valeurs de configuration attendues sont documentees dans `.env.example`.

Pour lancer avec Supabase :

```powershell
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=GAME_MASTER_MODE=mock
```

Sans ces valeurs, l'application compile et affiche un etat local non connecte.

## Backend MJ IA Railway

Le backend est dans `backend/`. Il expose :

- `GET /health`
- `POST /v1/game-master/respond`

Variables a configurer sur Railway :

```text
OPENROUTER_API_KEY=...
OPENROUTER_MODEL=google/gemini-3.1-flash-lite
```

La cle OpenRouter ne doit jamais etre ajoutee dans Flutter.

Pour connecter Flutter au backend Railway :

```powershell
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=GAME_MASTER_MODE=remote --dart-define=GAME_MASTER_BACKEND_URL=https://ton-backend.up.railway.app
```

Pour rester en developpement local sans appel IA distant :

```powershell
flutter run --dart-define=GAME_MASTER_MODE=mock
```

## Validation

Commandes de base :

```powershell
flutter pub get
flutter analyze
flutter test
```

Les commandes `flutter build` Android sont lancees manuellement par le proprietaire du projet, pas par l'agent Cursor.
