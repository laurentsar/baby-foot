# Game Passes à créer (Robux)

Les IDs **ne peuvent pas être écrits à l'avance** : Roblox attribue le nombre au
moment de la création, et il n'existe pas d'API Open Cloud pour créer une passe
(l'Open Cloud gère les DataStore, les messages et l'upload d'assets — pas la
monétisation). Il faut donc passer par le Creator Hub une fois, puis coller les
7 nombres dans `Config.PassIds`.

## Où créer

1. Publie le jeu (File → Publish to Roblox) — une passe appartient à une
   expérience, donc l'expérience doit exister.
2. <https://create.roblox.com/dashboard/creations> → ton expérience →
   **Associated Items** → **Passes** → **Create a Pass**.
3. Nom + description ci-dessous, puis **Sales** → *Item for Sale* activé → prix.
4. L'ID est le nombre dans l'URL de la passe :
   `https://www.roblox.com/game-pass/`**`1234567890`**`/VIP`

## Les 7 passes

| Clé (`Config.PassIds`) | Nom à saisir | Prix conseillé | Description à coller |
|---|---|---|---|
| `VIP` | VIP | 199 R$ | x2 argent, dés 30 % moins chers et étiquette VIP au-dessus de ton nom. |
| `MoneyX2` | Argent x2 | 149 R$ | Double tout l'argent gagné. Cumulable avec le VIP. |
| `RebirthX2` | Renaissance x2 | 249 R$ | Double le multiplicateur gagné à chaque renaissance. |
| `LuckyDice` | Dés Chanceux | 299 R$ | Beaucoup moins de Communs : les raretés sortent bien plus souvent aux dés. |
| `BallSpeedX2` | Vitesse Balle x2 | 129 R$ | La balle part deux fois plus vite. |
| `BigField` | Grand Terrain | 179 R$ | Le fond du baby-foot est deux fois plus grand : marquer devient plus facile. |
| `AutoShoot` | Tir Automatique | 349 R$ | Le jeu tire tout seul, en balayant le terrain. Gratuit pour tout le monde à partir de 500Qa d'argent gagné. |

## Ensuite

Dans `src/ReplicatedStorage/Config.lua` :

```lua
Config.PassIds = {
    VIP         = 1234567890,
    MoneyX2     = 1234567891,
    RebirthX2   = 1234567892,
    LuckyDice   = 1234567893,
    BallSpeedX2 = 1234567894,
    BigField    = 1234567895,
    AutoShoot   = 1234567896,
}
```

Rien d'autre à toucher : prix, libellés et effets sont déjà câblés.

Au démarrage, le serveur écrit dans la console la liste des passes encore sans
ID, et la boutique les affiche « ⚙️ à configurer » sans permettre de cliquer —
un ID à `0` ne déclenche donc jamais un achat dans le vide.

## Vérifier

- Redémarre le serveur : la console doit afficher
  `[BabyFoot] Les 7 game passes sont configurés.`
- En jeu, ouvrir la boutique : les 7 boutons doivent être violets avec 🟣.
- Un achat test se fait avec un **compte différent** du propriétaire du jeu : le
  créateur possède déjà ses propres passes, `UserOwnsGamePassAsync` renvoie
  `true` pour lui et l'invite d'achat ne s'ouvre pas.

## Cas particulier : Tir Automatique

C'est la seule passe qui a un équivalent gratuit. Le tir automatique se débloque
aussi tout seul à `Config.AutoShoot.freeUnlockEarned` d'argent **cumulé**
(500Qa par défaut), et le seuil porte sur le cumul et non sur l'argent en poche :
une renaissance remet l'argent à zéro, un déblocage qui se reperdrait à chaque
renaissance serait incompréhensible.

La passe reste donc vendable — elle sert à l'avoir tout de suite plutôt qu'après
des heures de jeu. Si tu veux la rendre exclusive, mets `freeUnlockEarned` à
`math.huge`.
