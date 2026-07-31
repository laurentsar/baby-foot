# ⚽ Baby-Foot Power

Jeu Roblox (Rojo) — simulateur baby-foot : entraîne-toi aux haltères pour gagner
de la puissance, recrute tes joueurs aux dés, vise à la caméra et touche-les pour
gagner de l'argent, marque entre les poteaux pour un **x3**, améliore ton matériel, fais
des **renaissances** et grimpe au **classement mondial**.

## Boucle de jeu

1. **S'entraîner** 🏋️ — tiens le bouton haltères pour accumuler de la *Puissance*
   (les meilleurs haltères en donnent plus par rep).
2. **Tirer** ⚽ — la *visée suit ta caméra* : tourne-toi vers l'endroit du terrain
   que tu veux frapper (borné à ±55° par le serveur), puis maintiens **TIRER** :
   la jauge oscille et se lit en 4 paliers — 🔴 nul, 🟡 moyen, 🟢 bien,
   🟩 vert foncé très bien. Vitesse du tir = puissance × palier atteint au relâcher.

   Tu tires de **derrière la ligne rouge** : la moitié « approche » du terrain a
   été retirée et la ligne est infranchissable pour les personnages (la balle,
   elle, la traverse).
3. **Recruter aux dés** 🎲 — chaque lancer coûte de l'argent et donne **un joueur
   de foot** à collectionner : Commun ×1, Rare ×3, Épique ×8, Légendaire ×22,
   Mythique ×60, Divin ×120, puis les deux cartes « personnage » :
   **Exclusif ×500** (Le Prodige, ~1 tirage sur 5 000) et **Astral ×1000**
   (L'Astral, ~1 sur 20 000). Le tirage est fait par le serveur (le client
   n'envoie que « je lance »).
4. **Composer l'équipe** 👥 — le terrain est un vrai baby-foot : **4 bases**
   (Attaque 3, Milieu 5, Défense 2, Gardien 1) = **11 joueurs**, en maillot de
   Paris. L'équipe est **complète dès la première partie** (11 Communs offerts) :
   la progression n'est pas le nombre de joueurs mais leur rareté — les dés
   remplacent les Communs, les meilleures cartes se placent automatiquement.
   La **rareté se lit sur le socle lumineux** sous chaque joueur — sauf les
   deux cartes « personnage », reconnaissables de loin à leur tenue
   (`Config.Skins`) : l'Exclusif en maillot bleu-violet, bras nus, chaussettes
   turquoise et baskets blanches ; l'Astral en violet galaxie lumineux, liseré
   et couronne dorés. Contrairement aux autres, ces deux-là ne tirent pas un
   nom au hasard : chacune EST un personnage, avec un nom fixe
   (`cardName`).
5. **Toucher / Marquer** — chaque joueur touché rapporte selon **sa rareté**
   (valeur du joueur × multiplicateur de la carte × balle × bonus).
   Si la balle finit **dans le but** (il ne fait que 30 % de la largeur : il faut
   viser entre les poteaux) → **×3 sur le total du tir**, joueurs touchés en
   chemin compris.
   Un tir trop faible s'arrête avant le but → tu gagnes seulement les touches,
   **sans multiplicateur**.
6. **Améliorer** 🛒 — meilleurs haltères, meilleure balle, valeur des joueurs, et
   **Chance** 🍀 : 8 niveaux qui multiplient jusqu'à **×5** le poids de tout ce qui
   sort mieux qu'un Commun aux dés (le Commun, lui, n'est jamais touché : la
   chance reste bornée). Le **×20** est réservé à la passe Robux, et les deux se
   cumulent (plafond ×100).
7. **Mondes** 🌍 — trois décors qui multiplient l'argent : Stade (×1),
   **Galactique** (1 Sx → ×2), **Radioactif** (1 Oc → ×4). Achat **définitif**
   (ni la renaissance ni une déconnexion ne les reprennent), et on se
   **téléporte** ensuite librement entre les mondes débloqués depuis la boutique.
   Le multiplicateur est celui du monde **où l'on se trouve** : revenir au Stade
   pour le décor, c'est accepter de gagner moins. Terrain reconstruit à chaque
   passage (sol, murs, but, plateforme des œufs) et ambiance client assortie
   (ciel, brume, étalonnage).
8. **Œufs & pets** 🥚 — une plateforme **au parvis, à côté du point
   d'apparition**, porte **3 œufs par monde** (9 au total). On clique un œuf :
   il tremble, éclate et **le pet s'élève au-dessus du socle** — l'animation vit
   côté serveur, les autres joueurs la voient donc aussi. Chaque pet
   **multiplie l'argent** (×1,1 au Stade jusqu'à ×6000 en Radioactif). Les pets
   se rangent dans le **sac à dos**, **un seul est équipé** à la fois et suit le
   joueur — bouton ⭐ *équiper le meilleur*.

   Les prix sont **calés sur le prix du monde** (250 K → 5 B au Stade,
   5 Qi → 50 Sx en Galactique, 5 Sp → 50 Oc en Radioactif) : le premier œuf d'un
   monde est abordable dès qu'on vient de le débloquer, le troisième reste un
   objectif. Ils sont **fixes**, sans coefficient de renaissance : l'étiquette
   posée sur l'œuf dit toujours la vérité.
9. **Renaissance** 🔄 — reset argent + upgrades contre un multiplicateur
   permanent : **×2, ×4, ×6, ×8… (2 × le nombre de renaissances)**.
   **La collection de joueurs, la Chance et les Mondes sont conservés.**
10. **Défi du loin** 🏹 — **toutes les 10 minutes**, une manche d'une minute : le
   terrain se vide (plus de figurines, plus de but, plus de murs) et le seul score
   est la **distance** du tir. Aucun argent n'y est gagné — les récompenses sont
   des **potions** : 1er ×3 argent 30 min, 2e ×2 puissance 10 min, 3e ×2 puissance
   5 min. Elles atterrissent dans le **sac à dos** 🎒 et se boivent quand on veut
   (deux potions du même type n'empilent pas les multiplicateurs : on garde le
   meilleur et on additionne le temps).
11. **Hors ligne** 💤 — le jeu retient ton rythme de gain (argent/seconde) et t'en
   reverse **35 %** pour le temps passé déconnecté, plafonné à **8 h**. Rien n'est
   simulé : c'est une moyenne glissante, honnête et incapable de dériver.
12. **Tutoriel & nouveautés** 📚 — 8 écrans à la première partie (rejouables par
   ❓), et un pop-up 📣 qui annonce les nouveautés à la première connexion suivant
   une mise à jour (une seule ligne à changer : `Config.Release`).
13. **Coup de sifflet** 📣 — le grand écran affiche un compte à rebours de **30 s** ;
   à zéro, **tous les gains sont doublés pendant 10 s**, pour tout le serveur.
   Le cycle vit côté serveur, le panneau ne fait que l'afficher.
14. **Classement mondial** 🏆 — **deux** panneaux alimentés par le même
   OrderedDataStore : un au parvis (visible dès l'arrivée) et le grand écran
   derrière le but. Une seule requête sert tous les panneaux.

## Game Passes (Robux)

| Pass | Effet |
|------|-------|
| **VIP** | ×2 argent + dés 30 % moins chers + étiquette « VIP » au-dessus du nom |
| **Argent x2** | ×2 argent (cumulable avec VIP) |
| **Renaissance x2** | double le multiplicateur de renaissance |
| **Dés Chanceux** | poids des communs divisé par 3 → bien plus de raretés |
| **Vitesse Balle x2** | la balle part 2× plus vite |
| **Grand Terrain** | but 2× plus large → marquer devient bien plus facile (appliqué **dès l'achat**) |
| **Tir Automatique** | tire tout seul en balayant le terrain (gratuit pour tous à 500 Qa cumulés) |
| **Chance x20** | ×20 de chance de recruter mieux qu'un Commun, cumulable avec l'amélioration Chance |

> Les IDs vivent dans un seul bloc, `Config.PassIds` en tête de
> `src/ReplicatedStorage/Config.lua`. Ils ne peuvent pas être fournis à
> l'avance : Roblox les attribue à la création et aucune API Open Cloud ne crée
> de passe. Marche à suivre complète dans **[PASSES.md](PASSES.md)**.
> Tant qu'un ID vaut `0`, la passe s'affiche « ⚙️ à configurer », n'est pas
> vendue et n'est jamais accordée ; le serveur liste les manquantes au démarrage.

## Structure (Rojo)

```
default.project.json          # arborescence Rojo
serve.sh                      # rojo serve (port 34875)
src/ReplicatedStorage/
  Config.lua                  # ÉQUILIBRAGE : upgrades, prix, passes, terrain
  Remotes.lua                 # RemoteEvents partagés
src/ServerScriptService/
  Main.server.lua             # orchestration : plots, tir, dés, équipe, renaissance
  FieldBuilder.lua            # génération procédurale du terrain
  DataStore.lua               # sauvegarde des profils
  Leaderboard.lua             # classement mondial (OrderedDataStore)
  Erasure.lua                 # droit à l'oubli (RGPD) : suppression des données
src/StarterPlayer/StarterPlayerScripts/
  Client.client.lua           # UI : entraînement, visée caméra, jauge, dés, collection
```

## Lancer

```bash
./serve.sh                    # démarre rojo serve (LAN, port 34875)
```

Puis dans **Roblox Studio** : plugin Rojo → *Connect* (127.0.0.1:34875).
Active **Studio Access to API Services** (Game Settings → Security) pour les
DataStore et le classement mondial.

Build one-shot d'un place :

```bash
rojo build -o BabyFootPower.rbxlx
```

## Données joueur & droit à l'oubli (RGPD)

Le jeu écrit **deux clés** par joueur, et rien d'autre :

| Où | Clé | Contenu |
|---|---|---|
| DataStore `BabyFootPower_v1` | `p_<userId>` | argent, puissance, haltère, balle, niveau de valeur, collection, renaissances, total gagné |
| OrderedDataStore `BabyFootPower_v1_top` | `u_<userId>` | total gagné (classement mondial) |

Aucun nom, e-mail, adresse IP ni journal de connexion. Le `DisplayName` affiché
sur le panneau de classement est lu à la volée via l'API Roblox, jamais stocké.

**Le joueur se sert lui-même** : boutique → section « 🔒 Mes données » → *Supprimer
mes données*. Deux clics (le second confirme dans les 30 s), puis le serveur
efface les deux clés et l'éjecte — sa session en mémoire recréerait sinon le
profil à la sauvegarde de sortie.

**Demande transmise par Roblox** pour un joueur qui ne revient pas (Creator
Dashboard → e-mail *Right to Erasure*) : colle son UserId dans
`Config.ErasureRequests`, publie, et le prochain démarrage de serveur s'en charge
(traitement espacé de 7 s par joueur pour respecter les quotas DataStore). Le
serveur imprime `[BabyFoot] Droit a l'oubli <id> : profil=efface classement=efface`
— garde la ligne comme preuve de traitement, puis retire l'UserId de la liste.

```lua
Config.ErasureRequests = { 1234567890 }
```

L'opération est **idempotente** : rejouer une demande déjà traitée ne coûte que
deux requêtes et n'échoue pas.

## Notes

- Chaque joueur a **son propre terrain** (plot décalé dans le monde) — pas de
  conflit d'équipe entre joueurs.
- **Arrivée** : on apparaît **au début de l'allée**, face au stade, puis on
  remonte le chemin bordé d'arbres et on entre par le passage percé dans le mur
  arrière. Le `SpawnLocation` par défaut est créé **hors plot** : les plots sont
  détruits quand leur joueur part, et un spawn qui disparaît ferait apparaître
  les suivants à l'origine du monde. Le serveur téléporte ensuite chacun devant
  son propre stade.
- Les plots libérés sont **réutilisés** (pile de slots) : sans ça ils
  s'éloignaient indéfiniment au fil des allées et venues.
- **Sons** : les supporters bondissent en ola à chaque but, et une musique
  d'ambiance tourne en boucle avec un bouton muet. Les deux sont optionnels —
  `Config.Crowd.soundId` et `Config.Music.soundId` attendent l'ID d'un audio
  **que tu as toi-même téléversé** : depuis la mise à jour *audio privacy* de
  Roblox, un son uploadé par un tiers n'est pas lisible dans ton jeu. Vides, la
  ola reste silencieuse et le bouton affiche « à configurer ».
- Tir **serveur-autoritaire** (simulation de la balle côté serveur, anti-triche).
- La description du jeu à coller dans Roblox est dans `DESCRIPTION.md`.
