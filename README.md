# ⚽ Baby-Foot Power

Jeu Roblox (Rojo) — simulateur baby-foot : entraîne-toi aux haltères pour gagner
de la puissance, recrute tes joueurs aux dés, vise à la caméra et touche-les pour
gagner de l'argent, marque au fond pour un **x4**, améliore ton matériel, fais
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
   Mythique ×60. Le tirage est fait par le serveur (le client n'envoie que
   « je lance »).
4. **Composer l'équipe** 👥 — le terrain est un vrai baby-foot : **4 bases**
   (Attaque 3, Milieu 5, Défense 2, Gardien 1) = **11 joueurs**, en maillot de
   Paris. L'équipe est **complète dès la première partie** (11 Communs offerts) :
   la progression n'est pas le nombre de joueurs mais leur rareté — les dés
   remplacent les Communs, les meilleures cartes se placent automatiquement.
   La **rareté se lit sur le socle lumineux** sous chaque joueur.
5. **Toucher / Marquer** — chaque joueur touché rapporte selon **sa rareté**
   (valeur du joueur × multiplicateur de la carte × balle × bonus).
   Si la balle atteint le **fond du baby-foot (but adverse)** → **×4** sur le tir.
   Un tir trop faible s'arrête avant le but → tu gagnes seulement les touches,
   **sans multiplicateur**.
6. **Améliorer** 🛒 — meilleurs haltères, meilleure balle, emplacements
   supplémentaires, valeur des joueurs.
7. **Renaissance** 🔄 — reset argent + upgrades + emplacements contre un
   multiplicateur permanent (1 = ×2, 2 = ×4, 3 = ×6, puis +2).
   **La collection de joueurs est conservée.**
8. **Coup de sifflet** 📣 — le grand écran affiche un compte à rebours de **30 s** ;
   à zéro, **tous les gains sont doublés pendant 10 s**, pour tout le serveur.
   Le cycle vit côté serveur, le panneau ne fait que l'afficher.
9. **Classement mondial** 🏆 — **deux** panneaux alimentés par le même
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
| **Grand Terrain** | fond du baby-foot 2× plus grand → but plus facile |

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
- **Cri du public** : les supporters bondissent en ola à chaque but. Le son est
  optionnel — renseigne `Config.Crowd.soundId` avec un audio **que tu as
  toi-même téléversé** : depuis la mise à jour *audio privacy* de Roblox, un son
  uploadé par un tiers n'est pas lisible dans ton jeu.
- Tir **serveur-autoritaire** (simulation de la balle côté serveur, anti-triche).
- La description du jeu à coller dans Roblox est dans `DESCRIPTION.md`.
