# DragonsLair

DragonsLair est un jeu de rôle médiéval-fantasy assisté par IA, jouable en solo ou en multijoueur.

Le projet combine une application Flutter, un backend Python, Supabase et un maître du jeu génératif. L'IA construit la narration et propose des actions structurées, tandis que les règles du jeu, les jets de dés et les mutations de l'état sont contrôlés par le backend.

Le jeu est déployé sur le Web et distribué sur Android.

## Principe technique

DragonsLair ne confie pas directement l'état du jeu au modèle génératif.

Une action joueur suit principalement ce flux :

    Action joueur
          |
          v
    Application Flutter
          |
          v
    Backend Python
          |
          v
    Contexte de partie
    joueurs, ennemis, combat,
    mémoire, événements, scénario
          |
          v
    Maître du jeu IA
          |
          v
    Réponse JSON structurée
          |
          v
    Validation Pydantic
          |
          v
    Moteur de règles
          |
          v
    Supabase
          |
          v
    État partagé par les joueurs

Le maître du jeu peut notamment proposer des actions comme :

- demander un jet de caractéristique
- démarrer ou terminer un combat
- faire apparaître ou déplacer un ennemi
- infliger ou restaurer des points de vie
- gérer des objets et des effets
- modifier l'ambiance musicale
- terminer une aventure

Ces intentions sont interprétées et validées par le backend avant de modifier l'état persistant de la partie.

## IA générative et règles déterministes

La séparation entre narration générative et règles de jeu est un principe central du projet.

Lorsqu'une action possède une issue incertaine, le maître du jeu demande un jet plutôt que d'appliquer immédiatement ses conséquences.

Le backend contrôle ensuite :

- la caractéristique utilisée
- la difficulté du jet
- les bonus d'équipement
- les effets actifs
- le modificateur du personnage
- le résultat final

Une fois le jet résolu, son résultat est réinjecté dans le contexte du maître du jeu afin de poursuivre la scène.

L'IA dirige donc la narration et propose les intentions. Le moteur conserve la responsabilité des règles et de l'état du jeu.

## Mémoire de campagne

Une partie peut évoluer sur une longue période sans renvoyer l'intégralité de son historique au modèle.

DragonsLair combine :

- les événements récents pour le contexte immédiat
- un résumé de campagne compact pour la mémoire longue
- l'état courant des joueurs et ennemis
- l'état du combat
- le monde et l'objectif du scénario
- des informations réservées au maître du jeu

Les informations privées du maître du jeu sont séparées de l'état public transmis aux joueurs.

## Fonctionnalités

- Jeu de rôle solo et multijoueur
- Actions libres en langage naturel
- Maître du jeu génératif
- Génération de scénarios
- Mémoire de campagne
- Jets de dés et caractéristiques
- Combats et gestion des ennemis
- Inventaire et équipement
- Buffs, debuffs, blessures et effets temporaires
- Plateau avec figurines
- Journal des événements
- Sauvegarde et reprise des parties
- Ambiance musicale dynamique
- Démo limitée et accès complet
- Paiements Web avec Stripe
- Google Play Billing sur Android
- Suivi de consommation des appels IA
- Français, anglais, espagnol et allemand

## Stack

### Application

- Flutter / Dart
- Riverpod
- GoRouter
- Supabase Flutter
- just_audio

### Backend

- Python
- Pydantic
- httpx
- Supabase
- OpenRouter

### Services

- Supabase pour l'authentification, la persistance et le temps réel
- OpenRouter pour l'orchestration des modèles génératifs
- Stripe pour les achats Web
- Google Play Billing pour Android
- Cloudflare R2 pour la distribution privée de l'installeur Windows

### Déploiement

- Firebase Hosting pour l'application Web
- Backend Python déployable via Procfile
- Google Play pour Android

## Structure du projet

    lib/
      core/
      features/
        access/
        auth/
        board/
        combat/
        dice/
        enemies/
        events/
        figurines/
        game/
        game_master/
        music/
        players/
        rooms/
        scenarios/

    backend/
      models.py
      openrouter_client.py
      apply_actions.py
      state_effects.py
      campaign_memory.py
      scenario_generator.py
      supabase_admin.py
      ...

L'application Flutter est organisée par fonctionnalités avec séparation des responsabilités entre domaine, données et présentation lorsque le module le nécessite.

Le backend porte les frontières de confiance liées à l'IA, les mutations de l'état du jeu, les accès privilégiés à Supabase, les paiements et les règles qui ne doivent pas dépendre du client.

## Tests

Le projet possède des tests Flutter et Python couvrant notamment :

- règles de combat
- jets et résolutions
- inventaire et personnages
- scénarios
- mémoire de campagne
- effets d'état
- sécurité et contrats SQL
- droits d'accès
- achats Stripe
- Google Play Billing et RTDN
- rate limiting
- consommation IA
- comportement responsive

## Philosophie produit

DragonsLair cherche à conserver la liberté d'un jeu de rôle sur table sans laisser un modèle génératif devenir l'unique source de vérité.

L'IA raconte et improvise.

Le moteur contrôle les règles.

La partie conserve son état.

Les joueurs décident de l'histoire.
