# DragonsLair

Application mobile Flutter de jeu de role multijoueur medieval-fantasy avec maitre du jeu IA.

## Etat

Gameplay MVP : auth anonyme, pseudo joueur, rooms avec code, selection de figurine, lobby realtime, plateau, pions, des, journal et MJ IA Railway.

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
- `POST /v1/game-master/respond` (JWT joueur obligatoire)

Variables a configurer sur Railway :

```text
OPENROUTER_API_KEY=...
OPENROUTER_MODEL=google/gemini-3.1-flash-lite
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...
```

La cle OpenRouter et la service role ne doivent jamais etre ajoutees dans Flutter.

Apres OpenRouter, Railway verifie le JWT du joueur puis ecrit les evenements `narration` / `system` dans Supabase.

## Migration identite joueur

Executer manuellement `supabase/migrations/20260827_player_identity_and_room_code.sql` dans l'editeur SQL Supabase. Ne pas ecraser `supabase/schema.sql`.

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

## Flux Gameplay MVP

Le flux actuel vise une partie simple :

```text
Home -> Pseudo -> Creer/Rejoindre/Code -> Figurine -> Lobby -> Plateau -> Actions/Des -> Journal
```

Les rooms, joueurs et evenements utilisent Supabase. Le plateau utilise `Assets/Plateau.png` et les pions utilisent `Assets/figurines.png`.

Limites actuelles :

- pas de moteur de regles JDR complet ;
- auth anonyme + pseudo, pas encore d'email/mot de passe ;
- Railway ecrit les narrations MJ, le client n'ecrit que les actions joueur.
