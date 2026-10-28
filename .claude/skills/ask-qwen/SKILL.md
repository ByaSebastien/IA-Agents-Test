---
name: ask-qwen
description: Délègue une tâche SIMPLE au modèle local Qwen (LM Studio, gratuit) pour économiser des tokens — README, documentation, commentaires, docstrings, boilerplate, reformatage, résumé de texte, données factices (JSON, CSV). Ne pas utiliser pour du code complexe, de l'architecture, du débogage ou de la relecture.
---
# Déléguer à Qwen (local)

Qwen2.5-Coder 7B tourne en local via LM Studio. Gratuit, mais lent (CPU) et limité : réserve-le aux tâches simples et bien cadrées.

## Commande

Toujours écrire le résultat dans un fichier avec `-OutFile` (ne pas récupérer le texte dans la conversation) :

    powershell -NoProfile -ExecutionPolicy Bypass -File .claude/skills/ask-qwen/ask-qwen.ps1 -Prompt "<consigne>" -OutFile "<chemin>"

Pour lui donner un fichier existant en entrée (code à documenter, texte à résumer) :

    powershell -NoProfile -ExecutionPolicy Bypass -File .claude/skills/ask-qwen/ask-qwen.ps1 -Prompt "<consigne>" -InputFile "<fichier source>" -OutFile "<chemin>"

## Règles

- Consigne courte, précise, autonome : Qwen ne connaît rien du projet en dehors de ce que tu lui donnes.
- Précise le format attendu (Markdown, JSON...) et la langue.
- Réponse longue = lent : pour plus de ~1500 mots, découpe en plusieurs appels.
- Après l'appel, vérifie rapidement le fichier produit (structure, absence d'hallucination évidente). Pour un livrable important, fais-le relire par `sonnet-reviewer`.
- Si le script renvoie "LM Studio unreachable" : préviens l'utilisateur que LM Studio est arrêté et confie la tâche à `sonnet-coder` à la place.
- Si la tâche porte sur des fichiers existants (README, doc, commentaires), passe-les TOUJOURS via `-InputFile` : Qwen ne doit rien deviner.
- Qwen est lent (plusieurs minutes) : ne l'utilise que pour des tâches qui ne bloquent pas la suite, ou lance-le dès que ses entrées sont prêtes.