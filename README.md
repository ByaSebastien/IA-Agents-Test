# Équipe d'agents IA — Workspace de démonstration

Ce workspace met en place une **équipe d'agents IA** qui travaillent ensemble sur une même demande :

- **Claude Opus** joue le rôle d'**orchestrateur** : il planifie, délègue, vérifie et assemble.
- Des **agents Claude Sonnet** font le gros du travail : recherche, code, relecture.
- **Codex** (OpenAI) génère les **images**.
- **Qwen**, un modèle **local** et gratuit qui tourne dans LM Studio, prend en charge les **tâches simples**.

Ce document explique **ce qui a été mis en place, pourquoi, et comment tout s'articule**, ainsi que les problèmes rencontrés et la façon dont ils ont été résolus.

---

## Sommaire

1. [Vue d'ensemble](#1-vue-densemble)
2. [Les concepts à comprendre](#2-les-concepts-à-comprendre)
3. [Prérequis et installation](#3-prérequis-et-installation)
4. [Structure du projet](#4-structure-du-projet)
5. [Chaque fichier expliqué](#5-chaque-fichier-expliqué)
6. [La démo : ce qui s'est passé](#6-la-démo--ce-qui-sest-passé)
7. [Problèmes rencontrés et solutions](#7-problèmes-rencontrés-et-solutions)
8. [Utilisation au quotidien](#8-utilisation-au-quotidien)
9. [Pour aller plus loin](#9-pour-aller-plus-loin)

---

## 1. Vue d'ensemble

```
                           UTILISATEUR
                                │  une demande
                                ▼
         ┌──────────── OPUS (orchestrateur) ────────────┐
         │  lit CLAUDE.md au démarrage → les règles     │
         │  connaît la description des agents et skills │
         └───┬───────────────┬──────────────┬───────────┘
             │               │              │
      délègue (Agent)   skill ask-qwen   skill ask-codex
             │               │              │
             ▼               ▼              ▼
   ┌──────────────────┐  ask-qwen.ps1    codex exec
   │ sonnet-researcher │      │              │  lit AGENTS.md
   │ sonnet-coder      │      ▼              ▼
   │ sonnet-reviewer   │  LM Studio       image_gen
   └──────────────────┘  (Qwen local)    → assets/*.webp|png
     (Claude Sonnet)
```

| Membre | Rôle | Moteur | Comment on l'appelle | Coût |
|---|---|---|---|---|
| Orchestrateur | Planifie, délègue, vérifie, rédige le rapport | Claude Opus | C'est la session elle-même | Quota Claude (le plus cher) |
| `sonnet-researcher` | Cherche et vérifie l'information avant d'agir | Claude Sonnet | Sous-agent | Quota Claude |
| `sonnet-coder` | Écrit et modifie le code | Claude Sonnet | Sous-agent | Quota Claude |
| `sonnet-reviewer` | Relit tout avant la livraison | Claude Sonnet | Sous-agent | Quota Claude |
| Qwen 2.5 Coder 7B | Tâches simples (README, doc, boilerplate…) | LM Studio (local) | Skill `ask-qwen` | **Gratuit** |
| Codex | Génération d'images | OpenAI (abonnement ChatGPT Plus) | Skill `ask-codex` | Abonnement ChatGPT |

**Le principe :** le modèle le plus capable (Opus) **réfléchit et coordonne**, et les autres **exécutent**. On économise ainsi des tokens et on travaille en parallèle, chaque membre faisant ce qu'il fait le mieux.

---

## 2. Les concepts à comprendre

### 2.1 Le `CLAUDE.md` : le règlement intérieur

C'est un fichier texte que Claude **lit automatiquement au démarrage de chaque session**. Il contient les règles du projet : ici, *qui fait quoi* et *comment travailler*.

- Il est **toujours chargé**, donc il consomme des tokens à chaque session. Il faut le garder **court**.
- Claude lit aussi les `CLAUDE.md` des **dossiers parents**. Un fichier `Documents/Formation/CLAUDE.md` s'applique donc à tous les projets rangés dans `Formation/`.
- Le fichier est lu **au démarrage** : après une modification, il faut ouvrir une **nouvelle session** pour qu'elle soit prise en compte.

### 2.2 Les sous-agents : des employés

Un sous-agent est **une autre instance de Claude** que l'orchestrateur lance pour lui confier une tâche.

| Caractéristique | Conséquence |
|---|---|
| Il a **son propre contexte** | Il ne voit **pas** la conversation, seulement le **brief** que l'orchestrateur lui écrit |
| Il a **son propre modèle** | Ici Sonnet, défini par `model: sonnet` |
| Il a **sa propre consigne** | Le texte de son fichier `.md`, sa « fiche de poste » |
| On peut **limiter ses outils** | Par exemple en lecture seule pour le researcher et le reviewer |
| Il ne renvoie qu'**un résumé final** | L'orchestrateur ne voit pas tout son travail, d'où l'intérêt d'un relecteur |

**Comment l'orchestrateur choisit un agent :** il lit le champ `description` de chaque agent. C'est la ligne **la plus importante** du fichier : elle dit *quand* utiliser l'agent.

**Les avantages :**
- **Contexte propre :** les fichiers lus par l'agent ne remplissent pas la mémoire de l'orchestrateur.
- **Parallélisme :** plusieurs agents travaillent en même temps.
- **Coût :** Sonnet est moins cher qu'Opus.
- **Spécialisation :** chaque agent a une consigne adaptée à son rôle.

**Les limites :**
- Un agent ne sait que ce que dit son brief : un brief vague donne un résultat vague.
- Un sous-agent ne peut pas lancer d'autres sous-agents.

### 2.3 Les skills : des recettes

Un skill est **une recette ou un savoir-faire** que Claude charge **seulement quand il en a besoin**. Ce n'est pas un travailleur supplémentaire : c'est une compétence que **Claude applique lui-même**.

- C'est un dossier qui contient un `SKILL.md`, et éventuellement des scripts ou de la documentation.
- Au démarrage, Claude ne lit que la `description` de chaque skill. Le contenu complet n'est chargé que quand une tâche correspond. C'est très économe en tokens.
- On peut aussi l'appeler à la main avec `/nom-du-skill`.

### 2.4 Agent, skill ou `CLAUDE.md` : lequel choisir ?

| | C'est… | Chargé quand ? | Exemple ici |
|---|---|---|---|
| `CLAUDE.md` | Le **règlement** | Toujours | « Délègue le code à `sonnet-coder` » |
| Skill | Une **recette** (le *comment*) | Quand c'est utile | « Comment appeler Qwen » |
| Agent | Un **employé** (le *qui*) | Quand l'orchestrateur délègue | `sonnet-coder` |

### 2.5 `AGENTS.md` : le `CLAUDE.md` de Codex

Codex lit automatiquement le fichier `AGENTS.md` à la racine du dossier dans lequel il travaille. On l'utilise pour lui donner son rôle dans l'équipe.

### 2.6 MCP (pour information)

MCP (*Model Context Protocol*) est un protocole standard qui permet de brancher des outils externes sur un assistant IA. Il était prévu au départ pour connecter Codex, mais **la version de Codex utilisée (0.165) n'offre plus de mode serveur MCP** : on est donc passé par la ligne de commande. Voir la [section 7](#7-problèmes-rencontrés-et-solutions).

---

## 3. Prérequis et installation

### 3.1 Claude Code

- **L'application de bureau Claude** (onglet Code) pour travailler au quotidien.
- **La commande `claude`**, utile pour gérer les plugins et les serveurs MCP depuis un terminal :
  ```powershell
  irm https://claude.ai/install.ps1 | iex
  ```
  Si `claude` n'est pas reconnu après l'installation, il faut ajouter son dossier au PATH utilisateur :
  ```powershell
  [Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", "User") + ";$env:USERPROFILE\.local\bin", "User")
  ```
  Ferme ensuite **tous** les terminaux et rouvre-en un, puis vérifie avec `claude --version`.

### 3.2 Codex

1. Installe l'application Codex. Elle fournit aussi la commande `codex` ; vérifie avec `codex --version`.
2. Connecte-toi avec `codex login`, puis vérifie avec `codex login status`.
3. **Il faut un abonnement ChatGPT payant (Plus).** Avec un compte gratuit, l'outil intégré `image_gen` n'est pas disponible.
4. Codex refuse de travailler en dehors d'un **dépôt git**. Lance donc `git init` dans le projet, ou utilise l'option `--skip-git-repo-check`.

On peut vérifier que la génération d'images est activée avec la commande suivante :
```bash
codex features list
```
La ligne `image_generation` doit indiquer `stable` et `true`.

### 3.3 LM Studio + Qwen

**Le modèle choisi : Qwen2.5-Coder 7B Instruct (Q4_K_M, environ 4,7 Go).**

Pourquoi pas Qwen3-Coder 30B ? Il pèse environ 18 Go et ne tient pas dans **16 Go de RAM** : Windows et les autres applications en occupent déjà 5 à 7.

**La machine de référence :** Intel i7-1260P (12 cœurs), 16 Go de RAM, carte graphique intégrée Intel Iris Xe.

Comme l'Iris Xe n'a pas de mémoire propre (elle emprunte la RAM), le modèle tourne **sur le processeur**.

#### Réglages par défaut du modèle

Ils se trouvent dans **My Models**, puis l'**engrenage** à côté du modèle, onglet **Load**. Comme ce sont des réglages par défaut, ils s'appliquent aussi au chargement automatique.

| Réglage | Valeur | Pourquoi |
|---|---|---|
| Context Length | 8192 | Suffisant pour des tâches simples, et économe en RAM |
| GPU Offload | 0 | L'Iris Xe partage la RAM : décharger sur elle n'apporte rien |
| CPU Thread Pool Size | 8 | Sur un processeur hybride, utiliser tous les threads ralentit souvent l'ensemble |
| Max Concurrent Predictions | 1 | Une seule requête à la fois, ce qui économise la RAM |
| Offload KV Cache to GPU Memory | Désactivé | Pas de vraie mémoire graphique |
| Flash Attention | Désactivé | Sans intérêt quand tout tourne sur le processeur |
| K/V Cache Quantization | Décoché | Expérimental, et inutile avec un contexte de 8192 |
| Keep Model in Memory | Activé | Évite de recharger le modèle à chaque requête |
| Try mmap() | Activé | Chargement plus rapide |

#### Réglages du serveur

Ils se trouvent dans l'onglet **Developer**, bouton **Server Settings**.

| Réglage | Valeur | Rôle |
|---|---|---|
| Just-in-Time Model Loading | Activé | Le modèle se charge tout seul à la première requête |
| Auto unload unused JIT loaded models | Activé | Libère la RAM quand le modèle ne sert plus |
| Max idle TTL | 10 à 15 minutes | Délai d'inactivité avant le déchargement |
| Only Keep Last JIT Loaded Model | Activé | Évite d'avoir deux copies du modèle en mémoire (le fameux `:2`) |

Dans les réglages de l'application, active le **démarrage du serveur à l'ouverture de session** (« Run LLM server on login » ou « headless service »).

**Vérifier que le serveur répond :**
```bash
curl http://localhost:1234/v1/models
```

**À savoir :** mets le PC sur secteur, en mode d'alimentation « Performances optimales ». Sur batterie, le processeur bride fortement sa vitesse.

---

## 4. Structure du projet

```
IA-Workspace-test/
├── README.md                         ← ce document
├── CLAUDE.md                         ← règles de l'orchestrateur (Opus)
├── AGENTS.md                         ← rôle de Codex (générateur d'images)
├── .gitignore                        ← ignore .codex-last.txt
├── assets/                           ← images produites par Codex
└── .claude/
    ├── agents/                       ← les sous-agents Sonnet
    │   ├── sonnet-researcher.md
    │   ├── sonnet-coder.md
    │   └── sonnet-reviewer.md
    └── skills/                       ← les recettes
        ├── ask-qwen/
        │   ├── SKILL.md              ← quand et comment appeler Qwen
        │   └── ask-qwen.ps1          ← l'appel HTTP à LM Studio
        └── ask-codex/
            └── SKILL.md              ← quand et comment appeler Codex
```

| Fichier | Lu par | Quand |
|---|---|---|
| `CLAUDE.md` | Claude (Opus) | Au démarrage de chaque session |
| `.claude/agents/*.md` | Claude Code | La description au démarrage, la consigne quand l'agent est lancé |
| `.claude/skills/*/SKILL.md` | Claude | La description au démarrage, le contenu quand c'est utile |
| `ask-qwen.ps1` | PowerShell | Quand le skill `ask-qwen` l'exécute |
| `AGENTS.md` | Codex | À chaque tâche envoyée à Codex |

---

## 5. Chaque fichier expliqué

### 5.1 `CLAUDE.md`

Il contient trois parties :

1. **Le rôle :** « Tu es l'orchestrateur. Tu planifies, tu délègues, tu vérifies et tu assembles. » Sans cette règle, Opus aurait tendance à tout faire lui-même.
2. **Le tableau de l'équipe :** il associe chaque besoin à un membre. Les noms doivent correspondre **exactement** à ceux des agents et des skills.
3. **La méthode**, en 7 points. Les plus importants :
   - **Les briefs autonomes (point 3)** : un agent ne connaît que son brief. C'est **le** facteur de qualité.
   - **Les livrables passent par des fichiers (point 4)** : c'est ce qui permet à Qwen, Codex et Sonnet de collaborer. Chacun dépose ses fichiers, les autres les lisent.
   - **Fixer les éléments partagés avant de paralléliser (point 7)** : cette règle a été ajoutée après la démo (voir la [section 6](#6-la-démo--ce-qui-sest-passé)).

La section **Conventions** prévoit un **plan de secours** : si un outil ne répond pas, l'orchestrateur le signale et passe à une alternative au lieu de bloquer.

### 5.2 Les agents (`.claude/agents/`)

Chaque fichier d'agent a la même structure :

```markdown
---
name: nom-de-l-agent        ← identifiant
description: QUAND l'utiliser (lu pour décider de déléguer)
model: sonnet               ← modèle utilisé
tools: Read, Grep, Glob     ← optionnel : limite les outils (sinon, tous)
---
Consigne permanente de l'agent (sa « fiche de poste »)
```

| Agent | Outils | Choix de conception |
|---|---|---|
| `sonnet-researcher` | Read, Grep, Glob, WebSearch, WebFetch | **Lecture seule**, il ne peut rien casser. Réponse limitée à 5 à 15 lignes, avec ses sources. Il doit préciser s'il répond de mémoire |
| `sonnet-coder` | Tous | Il doit pouvoir écrire et exécuter. Règle clé : « fais UNIQUEMENT ce que demande le brief », pour éviter qu'il réécrive tout le projet |
| `sonnet-reviewer` | Read, Grep, Glob | **Il signale, il ne corrige pas.** C'est l'orchestrateur qui renvoie les corrections au coder. C'est le filet de sécurité de l'équipe |

Point commun aux trois : chaque consigne précise **le format de la réponse finale**. Ça oblige l'agent à rendre un résumé exploitable plutôt que de déverser tout ce qu'il a lu.

### 5.3 Le skill `ask-qwen`

**`SKILL.md`** :

- Sa **description** dit *quand* l'utiliser (README, doc, boilerplate, données factices), mais aussi *quand ne pas* l'utiliser (code complexe, débogage, relecture). C'est aussi important : sinon, l'orchestrateur risquerait de confier du vrai code à un modèle 7B.
- Il impose **toujours `-OutFile`** : Qwen écrit dans un fichier, et l'orchestrateur ne reçoit qu'une ligne de confirmation. Si Qwen renvoyait son texte dans la conversation, Opus devrait le lire en entier, et l'économie serait perdue.
- Il impose **`-InputFile`** pour les tâches portant sur des fichiers existants : Qwen ne doit rien deviner.
- Il prévoit un **plan de secours** : si LM Studio ne répond pas, la tâche passe à `sonnet-coder`.

**`ask-qwen.ps1`** appelle l'API de LM Studio, qui est compatible avec celle d'OpenAI (`/v1/chat/completions`).

| Partie du script | Pourquoi |
|---|---|
| `-Prompt` | La consigne |
| `-InputFile` | Ajoute le contenu d'un fichier à la consigne |
| `-OutFile` | Écrit la réponse dans un fichier, et ne renvoie que « OK » |
| Le message `system` | Empêche le petit modèle de bavarder (« Voici votre README ! ») et d'entourer sa réponse de balises de code |
| `temperature = 0.2` | Des réponses stables et peu « créatives » |
| UTF-8 partout | PowerShell 5.1 abîme les accents par défaut |
| `TimeoutSec 600` | Le modèle tourne sur le processeur : une réponse longue peut prendre plusieurs minutes |
| Le `catch` | Renvoie un message clair si LM Studio est éteint |
| Aucun accent dans le script | Windows PowerShell 5.1 lit mal les scripts `.ps1` qui en contiennent |

On l'appelle avec `-ExecutionPolicy Bypass`, qui autorise l'exécution du script **pour ce lancement uniquement**, sans changer le réglage du système.

**Tester le script à la main :**
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .claude/skills/ask-qwen/ask-qwen.ps1 -Prompt "Écris une phrase de bienvenue." -OutFile test.md
```

### 5.4 Le skill `ask-codex`

Il lance Codex en mode non interactif :

```
codex exec --sandbox workspace-write -c approval_policy=never --output-last-message .codex-last.txt "<consigne>"
```

| Option | Rôle |
|---|---|
| `--sandbox workspace-write` | Codex peut **écrire** dans le projet. Sans elle, il est en lecture seule et ne peut pas copier l'image dans `assets/` |
| `-c approval_policy=never` | Aucune demande de validation. L'option `--ask-for-approval` n'existe pas en mode `exec`, d'où ce réglage de configuration. Pas de guillemets : une valeur qui n'est pas du TOML valide est prise telle quelle |
| `--output-last-message .codex-last.txt` | Seule la **réponse finale** de Codex est écrite dans ce fichier. La sortie console fait des centaines de lignes : Claude n'en lit que deux. C'est le même principe que `-OutFile` pour Qwen |

Règles du skill :
- **Timeout long** : une image prend 1 à 3 minutes. L'application lance donc la commande **en arrière-plan**.
- Vérifier que le fichier existe bien dans `assets/`.
- Plan de secours : une image SVG faite par `sonnet-coder`.

### 5.5 `AGENTS.md` (Codex)

- « Utilise **toujours** ton outil intégré `image_gen`… **ne dessine pas l'image avec du code**. » Lors d'un premier test, Codex avait **dessiné** un avatar en PowerShell, avec des formes géométriques, au lieu de générer une vraie image. Cette règle l'en empêche.
- « Ne modifie **aucun** autre fichier que ceux que tu crées dans `assets/`. » Sonnet travaille sur le code : on évite que deux membres de l'équipe touchent aux mêmes fichiers.
- « Ne remplace jamais un fichier existant » : il crée une variante (`-v2`).
- Le format de la réponse finale est imposé (chemin du fichier et prompt utilisé), comme pour les agents.

### 5.6 `.gitignore`

Il ignore `.codex-last.txt`, un fichier temporaire réécrit à chaque appel de Codex.

---

## 6. La démo : ce qui s'est passé

**La demande :**
> Crée une page HTML « Mon profil » (index.html + style.css) avec un avatar. Le researcher vérifie les bonnes pratiques d'une page profil accessible, le coder fait la page, Qwen écrit le README, Codex génère l'avatar dans assets/ (format adapté au web), et le reviewer relit le tout avant que tu me fasses le rapport.

### 6.1 Le déroulé observé

| Ordre | Événement | Durée | Ce que ça montre |
|---|---|---|---|
| 1 | Le **researcher** et **Codex** partent **en même temps** | 27 s pour le researcher, environ 2 min pour Codex | Le parallélisme des tâches indépendantes |
| 2 | Codex produit `avatar.webp` en 512×512, **16 Ko** | | La consigne « format web » est respectée (2,9 Mo en PNG lors d'un test précédent) |
| 3 | Le **coder** démarre une fois la recherche et l'avatar disponibles | 31 s | L'orchestrateur gère les dépendances |
| 4 | **Qwen** écrit le README, **après** le code | **Plus de 5 min** | Choix logique : un README décrit le code, il faut donc que le code existe |
| 5 | Le **reviewer** relit tout | | Il calcule tous les contrastes (niveau AA atteint) et trouve 2 problèmes |
| 6 | Le **coder** corrige, et l'orchestrateur vérifie | | La boucle relecture → correction → vérification |
| 7 | **Rapport final** : qui a fait quoi, et ce qui n'a pas été vérifié | | Un rapport honnête (pas de test au navigateur ni au lecteur d'écran) |

### 6.2 Où observer ce qui se passe

- **Dans le fil de la conversation :** chaque action est un bloc repliable. Clique sur ▸ pour le déplier.
  - « A exécuté l'agent … » correspond au lancement d'un agent.
  - « Message de sous-agent ▸ » contient le **résultat** renvoyé par l'agent.
  - « Skill exécuté /ask-qwen » correspond à l'utilisation d'une recette.
- **Dans la liste de tâches** sous le message : le plan de l'orchestrateur et son avancement.
- **Dans le panneau « Tâches en arrière-plan » :** les commandes longues, comme Codex.
- **Dans LM Studio, onglet Developer :** les requêtes reçues par Qwen et la génération en direct.
- **Avec `git status` :** les fichiers réellement créés ou modifiés.
- **Avec `/explain-usage` :** la répartition des tokens entre Opus et Sonnet.

### 6.3 Les leçons de la démo

| Problème | Cause réelle | Correction appliquée |
|---|---|---|
| L'avatar montre un **homme barbu**, alors que le texte parle d'une « développeuse » | Codex et le coder ont travaillé **en parallèle sans information commune**, et chacun a inventé le personnage | **Point 7** ajouté dans `CLAUDE.md` : fixer les éléments partagés et les mettre dans **chaque** brief |
| Le README de Qwen **ne correspondait pas au code** (mauvais identifiants, mauvais texte alternatif) | Qwen n'avait pas reçu les fichiers réels, alors il a **deviné** | Règle ajoutée dans `ask-qwen` : toujours passer les fichiers sources avec `-InputFile` |
| Qwen a mis **plus de 5 minutes** pour un README que Sonnet aurait écrit en 30 secondes | Modèle 7B sur le processeur, environ 8 tokens par seconde | Règle ajoutée dans `ask-qwen` : réserver Qwen aux tâches **qui ne bloquent pas la suite** |
| Le coder a ajouté un menu qui n'était pas demandé | Léger écart par rapport à « UNIQUEMENT ce que demande le brief » | À surveiller |
| Le researcher a répondu **de mémoire**, sans sources | Le sujet était connu, il n'a pas jugé utile de chercher | Règle ajoutée : vérifier sur le web si le sujet est récent, sinon préciser qu'il répond de mémoire |

**Le grand enseignement :** le **reviewer** est indispensable. C'est lui qui a trouvé les deux vraies erreurs, et elles venaient toutes les deux d'une **mauvaise circulation de l'information** entre les membres de l'équipe, pas d'un manque de compétence.

### 6.4 Le compromis Qwen et Sonnet

| | Sonnet | Qwen local (sur cette machine) |
|---|---|---|
| Coût | Consomme le quota Claude | Gratuit |
| Vitesse | Rapide (environ 30 s pour une page entière) | Lent (plusieurs minutes pour un README) |
| Qualité | Élevée | Correcte pour des tâches simples, mais à relire |
| À utiliser pour | Tout ce qui est important ou bloquant | Les gros volumes de tâches simples, en arrière-plan |

---

## 7. Problèmes rencontrés et solutions

| Problème | Cause | Solution |
|---|---|---|
| Qwen3-Coder 30B ne tient pas en mémoire | Environ 18 Go pour 16 Go de RAM | Qwen2.5-Coder 7B (environ 4,7 Go) |
| Le modèle apparaît **deux fois** (`qwen…:2`) dans LM Studio | Chargé à la fois dans l'interface et par `lms load` (ou par le chargement automatique) | **Eject** sur la copie, et activer « Only Keep Last JIT Loaded Model » |
| `codex exec` : « Not inside a trusted directory » | Codex exige un dépôt git | `git init` dans le projet |
| Codex : « accès en lecture seule » | `exec` démarre par défaut en lecture seule | `--sandbox workspace-write` |
| Codex **dessine** l'image avec du code | Le mot « simple » dans la demande l'a poussé à préférer du code | Demander explicitement `image_gen`, et l'imposer dans `AGENTS.md` |
| Codex : « outil image_gen non disponible » | Compte ChatGPT **gratuit** | Passer à l'abonnement **Plus** |
| `claude` : commande introuvable | L'application de bureau n'installe pas la commande | Installer la commande, puis ajouter `%USERPROFILE%\.local\bin` au PATH |
| Serveur MCP Codex : « Connection closed » | **`codex mcp-server` n'existe plus** en version 0.165 (`app-server` utilise un autre protocole) | Abandon du serveur MCP au profit du skill `ask-codex`, basé sur `codex exec` |
| Le plugin `codex-dispatch` ne fonctionne pas | Il dépend du serveur MCP de Codex | Plugin **désactivé**, pour éviter qu'il soit choisi à la place de `ask-codex` (deux descriptions proches entrent en concurrence) |
| `--ask-for-approval` refusé par `codex exec` | L'option n'existe qu'en mode interactif | `-c approval_policy=never` |

---

## 8. Utilisation au quotidien

### Avant de lancer une session
1. **LM Studio** doit tourner. C'est automatique s'il démarre à l'ouverture de session ; sinon, vérifie avec `curl http://localhost:1234/v1/models`.
2. **Codex** doit être connecté (`codex login status`).
3. Ouvre une **nouvelle session** Claude Code dans le dossier du projet.

### Bien formuler ses demandes
- **Décris le résultat attendu**, pas seulement la tâche : formats, contraintes, public visé.
- **Précise les éléments partagés** quand plusieurs membres de l'équipe sont concernés : personnage, palette, ton.
- Tu peux **imposer** un membre de l'équipe (« utilise sonnet-researcher pour… »), mais tu peux aussi laisser l'orchestrateur décider.

### Après une modification de la configuration
Toute modification de `CLAUDE.md`, d'un agent ou d'un skill n'est prise en compte que dans une **nouvelle session**.

---

## 9. Pour aller plus loin

### 9.1 Plusieurs équipes sans qu'elles se marchent dessus

Si tous les agents sont globaux, l'orchestrateur voit **tous** les agents dans **tous** les projets : risque de confusion, de mauvais choix et de conflits de noms. L'organisation recommandée est en couches :

| Couche | Où | Contenu |
|---|---|---|
| Socle commun | Plugin `socle`, ou `~/.claude/` | Qwen, Codex, règles d'orchestration |
| Équipe de domaine | **Un plugin par équipe** (`team-webdev`, `team-formation`, `team-unity`) | Les agents et skills spécialisés, **activés seulement dans les projets concernés** |
| Règles de domaine | `CLAUDE.md` dans `Web/`, `Formation/`, `Unity/` | Les conventions communes à tous les projets d'un domaine |
| Règles du projet | Le `CLAUDE.md` du projet | Ce qui est propre au projet |

Les agents d'un plugin portent le nom du plugin en préfixe (`team-unity:coder`), ce qui supprime les conflits de noms.

### 9.2 Retrouver ses équipes sur un autre PC

- Range tous les plugins dans **un seul dépôt GitHub privé**, qui sert de *marketplace*.
- Sur un nouveau PC :
  ```
  /plugin marketplace add ton-pseudo/mes-equipes-claude
  /plugin install team-webdev@mes-equipes-claude
  ```
- Mise à jour : un `git push` d'un côté, puis `/plugin marketplace update` de l'autre.
- Le plugin transporte la **configuration**, pas les **logiciels** : Claude Code, Codex, LM Studio, Qwen et git restent à installer sur chaque PC.
- **Ne jamais mettre de secret** (clé API, mot de passe) dans le dépôt, même privé.

### 9.3 Transporter les règles d'orchestration avec un hook

Un plugin ne peut pas contenir de `CLAUDE.md`. Pour que les règles d'orchestration voyagent avec le plugin `socle`, on peut utiliser un **hook `SessionStart`** : une commande exécutée automatiquement au démarrage de la session, qui lit un fichier de règles et le transmet à Claude. C'est optionnel : un `~/.claude/CLAUDE.md` court fait le même travail, mais doit être recopié sur chaque PC.

### 9.4 Un orchestrateur côté Codex

- Codex dispose d'une fonction multi-agents (`multi_agent = true` dans `codex features list`). Le plus simple est de demander à Codex lui-même comment la configurer dans sa version.
- `codex exec --oss --local-provider lmstudio` permet à Codex d'utiliser **le Qwen local** pour ses propres petites tâches.

### 9.5 Générer des images en local

LM Studio ne génère pas d'images. Des outils comme **FastSD CPU** (optimisé pour les processeurs Intel) ou **ComfyUI** le permettent, mais sur une machine avec 16 Go de RAM et une carte graphique intégrée, c'est lent et la qualité est limitée. Codex reste nettement meilleur.
