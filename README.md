# DragonsLair

Application mobile Flutter de jeu de role multijoueur medieval-fantasy avec maitre du jeu IA.

## Etat

Phase 1 en cours : bootstrap Flutter, theme, configuration, modeles Supabase et auth anonyme MVP.

## Stack

- Flutter / Dart
- Riverpod
- go_router
- Supabase Auth, PostgreSQL et Realtime
- MJ IA mock en premier, backend IA separe plus tard

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

## Validation

Commandes de base :

```powershell
flutter pub get
flutter analyze
flutter test
```
