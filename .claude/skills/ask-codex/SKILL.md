---
name: ask-codex
description: Confie une tâche à Codex (OpenAI) via son CLI — en priorité la GÉNÉRATION D'IMAGES (avatars, illustrations, icônes bitmap, assets visuels) avec son outil intégré image_gen. Codex lit AGENTS.md à la racine du projet.
---
# Déléguer à Codex (CLI)

Codex tourne en non-interactif avec `codex exec`. Il lit automatiquement `AGENTS.md` (son rôle : générateur d'images, sortie dans `assets/`).

## Commande

Depuis la racine du projet :

    codex exec --sandbox workspace-write -c approval_policy=never --output-last-message .codex-last.txt "<consigne>"

- `--sandbox workspace-write` : Codex peut écrire dans le projet (sinon il est en lecture seule et ne peut pas copier l'image).
- `-c approval_policy=never` : aucune demande de validation (le mode exec n'est pas interactif).
- `--output-last-message` : la réponse finale de Codex est écrite dans `.codex-last.txt`.

## Règles

- Timeout long (jusqu'à 10 minutes) : la génération d'image est lente.
- Ne lis PAS toute la sortie console (très verbeuse) : lis seulement `.codex-last.txt`.
- Consigne autonome : sujet, style, usage prévu, nom de fichier souhaité dans `assets/`, et « utilise ton outil image_gen ».
- Une image = une consigne claire ; plusieurs images peuvent être demandées dans le même appel.
- Après l'appel, vérifie que le fichier existe bien dans `assets/`.
- Si `codex` est introuvable ou échoue : préviens l'utilisateur et propose une alternative (image en SVG faite par `sonnet-coder`, ou plus tard).