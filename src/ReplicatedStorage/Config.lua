--!strict
-- Config partagée client/serveur : upgrades, prix, game passes, géométrie du terrain.
-- Tout est éditable ici : c'est la source de vérité de l'équilibrage du jeu.

local Config = {}

Config.SaveKey = "BabyFootPower_v1"  -- change la clé => reset des sauvegardes

-------------------------------------------------------------------------------
-- HALTÈRES (haltères = vitesse de gain de puissance à l'entraînement)
-- powerGain = puissance gagnée par "rep" d'entraînement.
-------------------------------------------------------------------------------
-- Gains divisés par deux : la puissance montait trop vite, le tir atteignait le
-- fond du terrain avant que la collection ne serve à quelque chose.
Config.Dumbbells = {
	{ name = "Haltère Mousse",   powerGain = 1,   cost = 0 },
	{ name = "Haltère Rouille",  powerGain = 2,   cost = 500 },
	{ name = "Haltère Fer",      powerGain = 4,   cost = 4000 },
	{ name = "Haltère Acier",    powerGain = 10,  cost = 25000 },
	{ name = "Haltère Titane",   powerGain = 28,  cost = 150000 },
	{ name = "Haltère Diamant",  powerGain = 75,  cost = 900000 },
	{ name = "Haltère Néon",     powerGain = 210, cost = 6000000 },
	{ name = "Haltère Galaxie",  powerGain = 600, cost = 40000000 },
}

-------------------------------------------------------------------------------
-- BALLONS (améliore la balle => plus d'argent par joueur touché)
-- moneyMult = multiplicateur d'argent par joueur touché.
-------------------------------------------------------------------------------
Config.Balls = {
	{ name = "Balle Mousse",   moneyMult = 1,    cost = 0 },
	{ name = "Balle Cuir",     moneyMult = 2,    cost = 1500 },
	{ name = "Balle Pro",      moneyMult = 4,    cost = 12000 },
	{ name = "Balle Or",       moneyMult = 9,    cost = 80000 },
	{ name = "Balle Plasma",   moneyMult = 22,   cost = 500000 },
	{ name = "Balle Cosmos",   moneyMult = 60,   cost = 4000000 },
	{ name = "Balle Trou Noir",moneyMult = 180,  cost = 30000000 },
}

-------------------------------------------------------------------------------
-- ÉQUIPE : 4 BASES (les tiges du baby-foot), 11 JOUEURS DE BASE (davantage à
-- chaque renaissance, voir Config.extraSlotsFromRebirths).
-- Répartition d'un vrai baby-foot vue depuis le tireur : attaque adverse en
-- premier, gardien au fond. 3 + 5 + 2 + 1 = 11.
-- depth = position de la base entre la ligne d'engagement (0) et le but (1).
-------------------------------------------------------------------------------
Config.Bases = {
	{ name = "Attaque", slots = 3, depth = 0.26 },
	{ name = "Milieu",  slots = 5, depth = 0.48 },
	{ name = "Défense", slots = 2, depth = 0.70 },
	{ name = "Gardien", slots = 1, depth = 0.90 },
}

-- PASSERELLES : une par ligne de touche, posée sur la crête des murs latéraux.
-- Pas à la hauteur des tiges : à 6 studs, derrière un mur de 10, elle était
-- invisible depuis le terrain.
Config.Walkway = {
	-- Débord vers l'extérieur au-delà du bord du terrain. 4 = l'aplomb des bouts
	-- de tiges (les barres font width + 8), c'est là que descendent les équerres.
	overhang = 4,
	railHeight = 1.6,   -- garde-corps, côté extérieur seulement
	margin = 6,         -- dépassement avant la 1re base et après la dernière
	walkable = false,   -- décor : la balle est simulée sans collision de toute façon
}

Config.MaxSquad = 11        -- plafond de base : chaque renaissance l'augmente (voir extraSlotsFromRebirths)
-- L'équipe est COMPLÈTE dès le départ : 11 emplacements ouverts, 11 joueurs
-- posés. Les acheter un par un laissait le terrain à moitié vide et donnait
-- l'impression qu'il manquait des joueurs. La progression, ce n'est pas le
-- nombre : ce sont les dés, qui remplacent les Communs par des raretés.
Config.StartingSlots = 11
Config.StarterRarity = "commun"

-- Coût du prochain emplacement (du 5e au 11e).
Config.Slot = {
	baseCost = 3000,
	costGrowth = 2.2,
}

function Config.slotCost(unlocked: number): number
	local step = math.max(0, unlocked - Config.StartingSlots)
	return math.floor(Config.Slot.baseCost * (Config.Slot.costGrowth ^ step))
end

-- Nombre total d'emplacements du terrain (= somme des bases, + les emplacements
-- bonus gagnés par renaissance).
function Config.totalSlots(extra: number?): number
	local n = 0
	for _, base in Config.Bases do
		n += base.slots
	end
	return n + (extra or 0)
end

-- Config.Bases avec `extra` emplacements en plus, répartis au prorata entre les
-- 4 bases (méthode du plus grand reste, jamais de slot retiré). Utilisé par
-- FieldBuilder pour agrandir l'équipe à chaque renaissance sans toucher à
-- l'équilibre attaque/milieu/défense/gardien.
function Config.basesWithExtra(extra: number?)
	local e = math.max(0, math.floor(extra or 0))
	if e == 0 then return Config.Bases end

	local total = Config.totalSlots()
	local shares = {}
	local assigned = 0
	for i, base in Config.Bases do
		local raw = e * (base.slots / total)
		local whole = math.floor(raw)
		shares[i] = { whole = whole, frac = raw - whole }
		assigned += whole
	end

	local order = {}
	for i in Config.Bases do table.insert(order, i) end
	table.sort(order, function(a, b) return shares[a].frac > shares[b].frac end)
	local remaining = e - assigned
	for k = 1, remaining do
		local i = order[((k - 1) % #order) + 1]
		shares[i].whole += 1
	end

	local out = {}
	for i, base in Config.Bases do
		out[i] = { name = base.name, slots = base.slots + shares[i].whole, depth = base.depth }
	end
	return out
end

-------------------------------------------------------------------------------
-- COLLECTION : chaque joueur de foot est une carte tirée aux dés.
-- mult = multiplicateur d'argent quand ce joueur est touché par la balle.
-- weight = poids de tirage (plus c'est haut, plus c'est fréquent).
-------------------------------------------------------------------------------
Config.Rarities = {
	{ key = "commun",     name = "Commun",     mult = 1,  weight = 54, color = Color3.fromRGB(190, 195, 205) },
	{ key = "rare",       name = "Rare",       mult = 3,  weight = 27, color = Color3.fromRGB(70, 160, 255)  },
	{ key = "epique",     name = "Épique",     mult = 8,  weight = 13, color = Color3.fromRGB(180, 110, 255) },
	{ key = "legendaire", name = "Légendaire", mult = 22, weight = 5,  color = Color3.fromRGB(255, 180, 40)  },
	{ key = "mythique",   name = "Mythique",   mult = 60, weight = 1,  color = Color3.fromRGB(255, 80, 120)  },
	{ key = "divin",      name = "Divin",      mult = 120, weight = 0.15, color = Color3.fromRGB(255, 255, 255) },
	-- EXCLUSIF : la carte du haut du tableau. Poids 0.02 = environ un tirage sur
	-- 5000, soit un objectif de très longue haleine plutôt qu'une surprise.
	-- Pour la rendre totalement inobtenable aux dés (et réservée aux dons ou aux
	-- commandes admin), mettre weight = 0 : rollRarity ne la choisira jamais.
	-- Seule rareté à porter sa propre tenue, cf. Config.Skins.
	-- cardName : cette rareté n'est pas un lot de joueurs, c'est UN personnage.
	-- Toutes ses cartes portent donc le même nom et la même tenue, au lieu de
	-- tirer un nom au hasard comme les autres.
	{ key = "exclusif",   name = "Exclusif",   mult = 500, weight = 0.02, color = Color3.fromRGB(150, 160, 235),
	  cardName = "Le Prodige" },
	-- Au-dessus de l'Exclusif : la carte la plus rare du jeu. x1000 et un tirage
	-- sur 20000 — à ce niveau, l'obtenir aux dés relève de l'accident heureux,
	-- c'est surtout une carte à offrir ou à accorder.
	{ key = "astral",     name = "Astral",     mult = 1000, weight = 0.005, color = Color3.fromRGB(196, 92, 255),
	  cardName = "L'Astral" },
}

function Config.rarity(key: string)
	for _, r in Config.Rarities do
		if r.key == key then return r end
	end
	return Config.Rarities[1]
end

-- Noms inventés (pas de vrai joueur : on ne veut pas de nom sous licence).
Config.NamePool = {
	first = { "Léo", "Marco", "Kylian", "Enzo", "Tibo", "Ravi", "Sacha", "Nino",
		"Diego", "Yanis", "Milo", "Aki", "Zoran", "Bruno", "Kofi", "Iker" },
	last = { "Foudre", "Tornade", "Bulldozer", "Comète", "Panthère", "Roquette",
		"Muraille", "Tonnerre", "Éclair", "Cyclone", "Marteau", "Faucon",
		"Requin", "Vortex", "Dragon", "Guépard" },
}

-------------------------------------------------------------------------------
-- INDEX : le catalogue complet des joueurs recrutables.
--
-- Il n'existe pas de « liste des 200 joueurs » quelque part : une carte est un
-- prénom du pool + un nom du pool, tirés aux dés. Le catalogue, c'est donc
-- l'ensemble des combinaisons possibles — 16 x 16 = 256 joueurs. L'index dit,
-- pour chacun, s'il a déjà été recruté et dans quelle meilleure rareté.
--
-- Construit une seule fois au chargement du module : la liste ne change jamais,
-- et le client la parcourt à chaque ouverture du panneau.
-------------------------------------------------------------------------------
local CATALOGUE: { string } = {}
for _, first in Config.NamePool.first do
	for _, last in Config.NamePool.last do
		table.insert(CATALOGUE, first .. " " .. last)
	end
end
table.sort(CATALOGUE)

-- Les personnages uniques (raretés à cardName) ne sortent pas des pools : sans
-- cet ajout ils seraient introuvables dans l'index, et la complétion ne pourrait
-- jamais être atteinte. Ils ferment la liste, à leur place de pièce maîtresse.
for _, r in Config.Rarities do
	if r.cardName then
		table.insert(CATALOGUE, r.cardName)
	end
end

function Config.catalogue(): { string }
	return CATALOGUE
end

function Config.catalogueSize(): number
	return #CATALOGUE
end

-------------------------------------------------------------------------------
-- DÉS : on paie, on lance, on obtient un joueur.
-- Le coût monte avec la taille de la collection pour que la chasse au Mythique
-- reste un objectif de fin de partie.
-------------------------------------------------------------------------------
Config.Dice = {
	baseCost = 600,
	costGrowth = 1.035,    -- coût *= par carte déjà possédée
	-- Plafond du coût de base. Il est ensuite multiplié par le coefficient de
	-- renaissance (Config.upgradeCostMultiplier), donc le prix réel monte encore
	-- au-delà. À 50 M il était atteint dès ~330 lancers et le prix se figeait de
	-- nouveau, ce qui était précisément le défaut corrigé.
	maxCost = 5e12,
	cooldown = 0.6,        -- délai serveur min entre deux lancers
	vipDiscount = 0.7,     -- pass VIP : dés 30 % moins chers
	luckyRerollWeight = 3, -- pass Dés Chanceux : le poids des communs est divisé par 3
}

-- Le coût monte avec le NOMBRE DE LANCERS DÉJÀ FAITS, pas avec la taille de la
-- collection. La collection est plafonnée (MAX_CARDS côté serveur : un lancer
-- ajoute une carte puis jette la plus faible) ; indexer le prix dessus le
-- figeait définitivement une fois le plafond atteint — le bouton RECRUTER
-- restait au même prix pour toujours.
function Config.diceCost(rolls: number, hasVIP: boolean): number
	local c = Config.Dice.baseCost * (Config.Dice.costGrowth ^ math.max(0, rolls))
	if hasVIP then c *= Config.Dice.vipDiscount end
	return math.floor(math.min(c, Config.Dice.maxCost))
end

-------------------------------------------------------------------------------
-- VALEUR DES JOUEURS (multipliée ensuite par la rareté de la carte touchée).
-------------------------------------------------------------------------------
-- Avec 11 cibles au maximum (contre des dizaines de figurines avant), la valeur
-- de base a dû monter d'autant. 51 = 60 moins 15 %, l'ajustement demandé après
-- essai en jeu.
Config.PlayerValue = {
	base = 51,
	growth = 1.5,          -- valeur *= 1.5 par niveau
	baseCost = 600,
	costGrowth = 1.5,
}

-------------------------------------------------------------------------------
-- RENAISSANCE (rebirth) : reset argent + upgrades, gagne un multiplicateur permanent.
-- 1 renaissance = x2, 2 = x4, 3 = x6, puis +2 par renaissance (mult = 2 * n).
-------------------------------------------------------------------------------
-- La collection de joueurs n'est PAS remise à zéro : c'est la progression longue
-- du jeu. Une renaissance ne reprend que l'argent, la puissance et le matériel.
--
-- Chaque renaissance agrandit aussi le terrain et l'équipe (donc plus de
-- joueurs à toucher, donc plus d'argent par tir) — mais le but s'éloigne
-- d'autant (il faut plus de puissance pour l'atteindre) et TOUTES les
-- améliorations (haltères, balle, dés, valeur joueur) coûtent bien plus cher :
-- juste après une renaissance, argent et puissance repartent de zéro, donc on
-- gagne beaucoup moins qu'avant tout en payant beaucoup plus.
Config.Rebirth = {
	baseCost = 50000,      -- coût de la 1re renaissance
	costGrowth = 4,        -- coût *= 4 par renaissance

	fieldGrowthPerRebirth = 0.15,  -- +15 % de longueur/largeur du terrain par renaissance
	maxFieldGrowth = 1.5,          -- plafond : terrain au maximum 2.5x plus grand

	extraSlotsPerRebirth = 3,      -- +3 emplacements de joueurs par renaissance
	maxExtraSlots = 30,            -- plafond des emplacements bonus (donc 41 joueurs max)

	upgradeCostGrowthPerRebirth = 0.4,  -- +40 % sur le coût des améliorations par renaissance
}

function Config.rebirthMultiplier(rebirths: number, hasRebirthPass: boolean): number
	local m = if rebirths >= 1 then rebirths * 2 else 1
	if hasRebirthPass then m *= 2 end
	return m
end

function Config.rebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.baseCost * (Config.Rebirth.costGrowth ^ rebirths))
end

-- Multiplicateur de taille du terrain (longueur/largeur), plafonné pour ne
-- jamais empiéter sur le plot du voisin (voir SLOT_SPACING dans Main.server).
function Config.fieldSizeMultiplier(rebirths: number): number
	return 1 + math.min(rebirths * Config.Rebirth.fieldGrowthPerRebirth, Config.Rebirth.maxFieldGrowth)
end

-- Emplacements de joueurs supplémentaires (au-delà des 11 de base) gagnés par
-- les renaissances, plafonnés.
function Config.extraSlotsFromRebirths(rebirths: number): number
	return math.min(rebirths * Config.Rebirth.extraSlotsPerRebirth, Config.Rebirth.maxExtraSlots)
end

-- Coût des améliorations (haltère, balle, dés, emplacement, valeur joueur) :
-- multiplie le coût de base. La renaissance elle-même (Config.rebirthCost)
-- n'est PAS concernée, sinon la boucle s'auto-alimenterait.
function Config.upgradeCostMultiplier(rebirths: number): number
	return (1 + Config.Rebirth.upgradeCostGrowthPerRebirth) ^ rebirths
end

-------------------------------------------------------------------------------
-- ★★★ LES SEULES LIGNES À REMPLIR : LES IDS DES GAME PASSES ★★★
--
-- Crée les 6 passes dans le Creator Hub (Expérience → Associated Items →
-- Passes → Create Pass), puis colle ici l'ID de chacun. Rien d'autre à changer :
-- les prix, libellés et effets sont déjà câblés plus bas.
--
-- L'ID est le nombre dans l'URL de la passe :
--   https://www.roblox.com/game-pass/ 1234567890 /VIP  →  1234567890
--
-- Ces IDs ne peuvent pas être générés à l'avance : Roblox les attribue à la
-- création, et il n'existe pas d'API Open Cloud pour créer une passe. Voir
-- PASSES.md pour la liste exacte à créer (noms, prix, descriptions).
--
-- Tant qu'un ID vaut 0, la passe est affichée « à configurer » et n'est ni
-- vendue ni accordée — jamais d'achat dans le vide.
-------------------------------------------------------------------------------
Config.PassIds = {
	VIP         = 0,
	MoneyX2     = 0,
	RebirthX2   = 0,
	LuckyDice   = 0,
	BallSpeedX2 = 0,
	BigField    = 0,
	AutoShoot   = 0,
}

Config.Passes = {
	VIP          = { id = Config.PassIds.VIP,         price = 199, label = "VIP",              desc = "x2 argent + dés 30% moins chers + étiquette VIP au-dessus du nom" },
	MoneyX2      = { id = Config.PassIds.MoneyX2,     price = 149, label = "Argent x2",        desc = "Double tout l'argent gagné (cumulable avec VIP)" },
	RebirthX2    = { id = Config.PassIds.RebirthX2,   price = 249, label = "Renaissance x2",   desc = "Double le multiplicateur de renaissance" },
	LuckyDice    = { id = Config.PassIds.LuckyDice,   price = 299, label = "Dés Chanceux",     desc = "Bien moins de communs : les raretés sortent beaucoup plus souvent" },
	BallSpeedX2  = { id = Config.PassIds.BallSpeedX2, price = 129, label = "Vitesse Balle x2", desc = "La balle part deux fois plus vite" },
	BigField     = { id = Config.PassIds.BigField,    price = 179, label = "Grand Terrain",    desc = "Le fond du baby-foot est deux fois plus grand (but plus facile)" },
	AutoShoot    = { id = Config.PassIds.AutoShoot,   price = 349, label = "Tir Automatique",  desc = "Tire tout seul, en balayant le terrain. Gratuit pour tous à 500Qa gagnés" },
}

-- Passes encore sans ID, pour l'avertissement au démarrage et l'affichage boutique.
function Config.unconfiguredPasses(): { string }
	local missing = {}
	for key, pass in Config.Passes do
		if pass.id == 0 then
			table.insert(missing, pass.label .. " (" .. key .. ")")
		end
	end
	table.sort(missing)
	return missing
end

-------------------------------------------------------------------------------
-- DROIT À L'OUBLI (RGPD).
--
-- Le jeu n'enregistre que l'état de partie, sous deux clés : p_<userId> dans le
-- DataStore et u_<userId> dans le classement. Aucun nom, e-mail ni adresse IP.
--
-- Quand Roblox transmet une demande de suppression (Creator Dashboard → e-mail
-- « Right to Erasure ») pour un joueur qui ne revient pas, colle son UserId ici :
-- le prochain démarrage de serveur efface ses données, puis tu peux retirer la
-- ligne.
--
--   Config.ErasureRequests = { 1234567890, 987654321 }
-------------------------------------------------------------------------------
Config.ErasureRequests = {} :: { number }

-- Délai pendant lequel une demande de suppression reste « armée » : le premier
-- clic prévient, le second dans cette fenêtre exécute. Une suppression est
-- définitive, elle ne doit pas partir sur un clic malheureux.
Config.ErasureConfirmWindow = 30

-------------------------------------------------------------------------------
-- TIR AUTOMATIQUE
--
-- Deux façons de l'obtenir, et elles donnent exactement la même chose :
--   - la passe Robux « Tir Automatique », tout de suite ;
--   - gratuitement, à partir de `freeUnlockEarned` d'argent CUMULÉ.
--
-- Le seuil porte sur le cumul gagné (totalEarned), pas sur l'argent en poche :
-- une renaissance remet l'argent à zéro, et un déblocage qui se reperd à la
-- renaissance suivante serait incompréhensible.
--
-- Le serveur reste maître : il ne fait qu'appeler son propre code de tir, avec
-- les mêmes verrous (une balle en vol, cooldown, relevage des figurines). Le
-- client n'envoie qu'un interrupteur marche/arrêt.
-------------------------------------------------------------------------------
Config.AutoShoot = {
	freeUnlockEarned = 500e15,  -- 500 Qa cumulés (Qa = 1e15, cf. Config.abbreviate)
	interval = 0.35,            -- fréquence des tentatives de tir
	-- Charge appliquée aux tirs automatiques. Dans le palier « TRÈS BIEN » sans
	-- être parfaite : le tir auto est un confort, pas un tir meilleur que le
	-- meilleur tir à la main.
	charge = 0.95,
	-- Balayage : l'angle avance de ce pas à chaque tir, puis repart de l'autre
	-- bord. Sans ça le tir auto taperait toujours la même colonne de figurines.
	sweepStep = 9,
}

-------------------------------------------------------------------------------
-- ROULEMENT AUTOMATIQUE DES DÉS
--
-- Se débloque en jeu contre de l'argent, une fois pour toutes, puis se pilote
-- depuis le bouton RECRUTER. Ça n'accélère rien et ça ne rend rien gratuit :
-- chaque lancer automatique paie le prix courant et respecte le même cooldown
-- que le bouton. Ce qu'on achète, c'est de ne plus avoir à appuyer.
-------------------------------------------------------------------------------
Config.AutoRoll = {
	unlockCost = 100e6,   -- 100 M $, déblocage définitif
	interval = 1.0,       -- fréquence des tentatives (le cooldown des dés vaut 0,6 s)
}

function Config.autoShootUnlockedBy(totalEarned: number, hasPass: boolean): boolean
	return hasPass or totalEarned >= Config.AutoShoot.freeUnlockEarned
end

-------------------------------------------------------------------------------
-- DONS ENTRE JOUEURS
--
-- Un joueur peut offrir de l'argent ou une carte à un autre joueur du même
-- serveur. C'est du transfert, jamais de la création : ce qui part de l'un
-- arrive à l'autre, à l'unité près.
--
-- Attention, c'est structurellement exploitable : rien n'empêche quelqu'un de
-- lancer un second compte, de le faire farmer et de tout transférer au premier.
-- Le cooldown et le plafond limitent la casse sans supprimer le problème.
-------------------------------------------------------------------------------
Config.Gift = {
	cooldown = 5,          -- délai serveur min entre deux dons du même joueur
	maxShare = 0.5,        -- part max de son argent offerte en une fois
	minMoney = 1,
}

-------------------------------------------------------------------------------
-- ADMINS : UserId autorisés à s'attribuer argent et cartes.
--
-- Pour trouver le tien : ouvre ton profil Roblox, l'UserId est le nombre dans
-- l'URL (roblox.com/users/ 1234567890 /profile).
--
-- Tant que la liste est vide, le panneau admin n'existe pour personne. Le
-- contrôle est fait SUR LE SERVEUR à chaque commande : un client modifié qui
-- s'affiche le panneau ne peut rien en tirer.
-------------------------------------------------------------------------------
Config.Admins = {} :: { number }

function Config.isAdmin(userId: number): boolean
	for _, id in Config.Admins do
		if id == userId then return true end
	end
	return false
end

-------------------------------------------------------------------------------
-- ENTRAÎNEMENT
-------------------------------------------------------------------------------
Config.Train = {
	repCooldown = 0.35,    -- délai serveur min entre deux reps (anti-triche + rythme)
}

-------------------------------------------------------------------------------
-- TIR / PHYSIQUE
-------------------------------------------------------------------------------
Config.Shot = {
	baseSpeed = 90,        -- vitesse de base d'un tir
	powerToSpeed = 0.35,   -- studs/s de vitesse ajoutés par point de puissance
	maxSpeed = 1400,
	-- Distance parcourue ≈ v²/(2*decel) : calée sur la longueur du demi-terrain
	-- (agrandi), pour que marquer demande une vraie puissance.
	decel = 95,            -- décélération (studs/s²)
	hitRadius = 6,         -- rayon de collision balle<->joueur
	-- Multiplie le TOTAL du tir : les joueurs touchés en chemin sont cumulés,
	-- puis l'ensemble est multiplié si la balle finit au fond.
	scoreMultiplier = 3,
	-- Valeur plancher d'un but (en « figurines communes »). Sans ça, un tir qui
	-- passe entre les figurines et rentre au fond affichait « BUT ! 0 touchés,
	-- +0 $ » : le tir le plus précis du jeu ne rapportait rien.
	goalBaseValue = 1,
	ballLifetime = 6,      -- durée de vie max d'une balle (s)
	cooldown = 0.30,       -- délai min serveur entre deux tirs
	maxAngle = 55,         -- angle de tir max de part et d'autre de l'axe
	-- Délai avant que les figurines touchées ne se relèvent. Le verrou de tir
	-- court jusque-là : un terrain vide entre deux tirs oblige à viser plutôt
	-- qu'à mitrailler.
	respawnDelay = 2.2,
}

-------------------------------------------------------------------------------
-- QUALITÉ DE CHARGE : la jauge de tir se lit en 4 paliers.
-- Partagé client/serveur : le client colore la barre, le serveur applique le
-- multiplicateur de vitesse — les deux ne peuvent pas diverger.
-------------------------------------------------------------------------------
Config.ChargeTiers = {
	{ upTo = 0.40, label = "NUL",       speedMult = 0.50, color = Color3.fromRGB(220, 60, 60)   },
	{ upTo = 0.70, label = "MOYEN",     speedMult = 0.78, color = Color3.fromRGB(240, 200, 60)  },
	{ upTo = 0.90, label = "BIEN",      speedMult = 1.00, color = Color3.fromRGB(90, 220, 90)   },
	{ upTo = 1.01, label = "TRÈS BIEN", speedMult = 1.30, color = Color3.fromRGB(20, 130, 55)   },
}

-- Vitesse de va-et-vient de la jauge de charge, en unites de charge par seconde.
-- Partagee client/serveur : le client anime la jauge avec, le serveur recalcule
-- la charge attendue a partir de la duree d'appui et refuse une charge qui ne
-- correspond pas (sinon un client modifie envoie 1.0 a chaque tir).
Config.ChargeRate = 1.4
Config.ChargeTolerance = 0.25   -- marge de latence reseau
-- Charge maximale accordee a un tir sans appui prealable (client non conforme).
Config.ChargeNoPressCap = 0.70

-- Position de la jauge apres `elapsed` secondes d'appui : triangle 0 -> 1 -> 0.
function Config.chargeAt(elapsed: number): number
	if elapsed ~= elapsed or elapsed < 0 then return 0 end
	local phase = (elapsed * Config.ChargeRate) % 2
	return if phase <= 1 then phase else 2 - phase
end

function Config.chargeTier(charge: number)
	local c = math.clamp(charge, 0, 1)
	for _, tier in Config.ChargeTiers do
		if c < tier.upTo then
			return tier
		end
	end
	return Config.ChargeTiers[#Config.ChargeTiers]
end

-------------------------------------------------------------------------------
-- GÉOMÉTRIE DU TERRAIN (studs) — le baby-foot est généré proProcéduralement.
-------------------------------------------------------------------------------
-- Une SEULE moitié de baby-foot, mais bien plus grande qu'un demi-terrain : on
-- tire de derrière la ligne d'engagement et les 4 bases occupent tout l'espace.
-- La ligne est infranchissable pour les personnages ; la balle la traverse
-- (elle est simulée en Anchored, sans collision).
Config.Field = {
	origin = Vector3.new(0, 3, 0),   -- centre du terrain
	length = 150,                    -- longueur (axe de tir, +Z = but adverse)
	width = 110,                     -- largeur
	wallHeight = 10,
	goalDepth = 12,                  -- profondeur du fond/but
	shootLine = -66,                 -- Z du point de tir (ton côté)
	barrierOffset = 6,               -- ligne infranchissable, en avant du point de tir
	barrierHeight = 16,              -- assez haut pour qu'on ne saute pas par-dessus
	fenceHeight = 45,                -- murs invisibles du pourtour (anti-saut)
	holeRadius = 7,                  -- trou d'entrée de la balle, début du terrain
	-- Le but ne fait plus toute la largeur : il faut viser. La balle qui arrive au
	-- fond à côté des poteaux ne marque pas.
	goalWidthRatio = 0.30,
}

Config.BigGoalMultiplier = 2        -- pass Grand Terrain : but deux fois plus large


-------------------------------------------------------------------------------
-- PARVIS D'ARRIVÉE + ENTRÉE DU STADE
-- On apparaît sur le parvis, puis on remonte l'allée bordée d'arbres et on passe
-- sous le portique pour arriver au terrain.
-------------------------------------------------------------------------------
Config.Entrance = {
	plazaOffset = 150,   -- distance du parvis derrière le point de tir (studs)
	plazaSize = 60,
	gateOffset = 66,     -- position du portique, entre le parvis et le stade
	pathWidth = 22,
	trees = 7,           -- arbres de chaque côté de l'allée
}

-------------------------------------------------------------------------------
-- MAILLOT DE L'ÉQUIPE — couleurs de Paris (bleu nuit, bande rouge, liseré blanc).
-- Uniquement des couleurs : ni nom de club, ni écusson, ni sponsor. Un logo ou
-- un nom d'équipe réelle est une marque déposée, et Roblox retire les jeux qui
-- les utilisent.
-------------------------------------------------------------------------------
Config.Jersey = {
	body = Color3.fromRGB(16, 26, 72),
	stripe = Color3.fromRGB(214, 38, 48),
	trim = Color3.fromRGB(240, 240, 245),
	shorts = Color3.fromRGB(12, 18, 52),
	head = Color3.fromRGB(255, 220, 180),
	shoes = nil,   -- pas de chaussures sur la tenue de base
}

-------------------------------------------------------------------------------
-- TENUES PAR RARETÉ.
--
-- Par défaut toutes les figurines portent Config.Jersey : la rareté se lit au
-- socle lumineux, pas au maillot. Une rareté listée ici fait exception et porte
-- sa propre tenue — c'est ce qui rend une carte Exclusive reconnaissable de
-- loin, sans avoir à lire son étiquette.
--
-- Les champs absents retombent sur Config.Jersey.
--
-- Deux options en plus des couleurs :
--   glow = true   → corps et bande en Neon (la figurine s'éclaire d'elle-même)
--   halo = Color3 → anneau lumineux au-dessus de la tête
-------------------------------------------------------------------------------
Config.Skins = {
	exclusif = {
		body = Color3.fromRGB(132, 143, 220),    -- maillot bleu-violet
		stripe = Color3.fromRGB(150, 160, 235),  -- bande à peine plus claire : tenue unie
		trim = Color3.fromRGB(120, 130, 205),
		shorts = Color3.fromRGB(58, 96, 168),    -- bas bleu
		head = Color3.fromRGB(226, 178, 142),
		arms = Color3.fromRGB(226, 178, 142),    -- bras nus
		socks = Color3.fromRGB(64, 196, 208),    -- rayures turquoise
		shoes = Color3.fromRGB(242, 242, 248),   -- baskets blanches
	},
	astral = {
		body = Color3.fromRGB(58, 40, 118),      -- violet profond « galaxie »
		stripe = Color3.fromRGB(214, 72, 226),   -- magenta des cornes
		trim = Color3.fromRGB(255, 202, 64),     -- le liseré fait la couronne dorée
		shorts = Color3.fromRGB(38, 28, 88),
		head = Color3.fromRGB(74, 52, 146),
		arms = Color3.fromRGB(58, 40, 118),
		socks = Color3.fromRGB(120, 88, 232),
		shoes = Color3.fromRGB(236, 238, 250),   -- bottes blanches
		glow = true,
		halo = Color3.fromRGB(255, 202, 64),
	},
}

-- Tenue effective d'une rareté : la tenue dédiée si elle existe, complétée par
-- la tenue de base pour tout ce qu'elle ne précise pas.
function Config.skinFor(rarityKey: string)
	local skin = Config.Skins[rarityKey]
	if not skin then return Config.Jersey end
	local out = {}
	for k, v in Config.Jersey do out[k] = v end
	for k, v in skin do out[k] = v end
	return out
end

-------------------------------------------------------------------------------
-- MATCH : cycle affiché sur le grand écran.
-- Toutes les `cycle` secondes, coup de sifflet : tous les gains sont multipliés
-- pendant `boostTime` secondes. Le compte à rebours vit côté serveur (le client
-- ne fait que l'afficher via le panneau).
-------------------------------------------------------------------------------
Config.Match = {
	cycle = 30,
	boostTime = 10,
	boostMult = 2,
}

-------------------------------------------------------------------------------
-- PUBLIC
-- soundId : cri de foule joué sur but. Laisse "" si tu n'as pas d'audio : depuis
-- la mise à jour "audio privacy" de Roblox, un son uploadé par quelqu'un d'autre
-- n'est PAS lisible dans ton jeu. Mets ici l'ID d'un son que tu as toi-même
-- téléversé (Creator Hub → Audio), sinon les supporters sautent en silence.
-------------------------------------------------------------------------------
-- MUSIQUE D'AMBIANCE (relaxante), jouée en boucle côté client avec un bouton
-- muet. Même contrainte que le cri du public : il faut l'ID d'un audio que TU as
-- téléversé (Creator Hub → Audio), ou un audio créé par Roblox lui-même. Un son
-- uploadé par un tiers ne joue pas dans ton expérience depuis la mise à jour
-- audio privacy. Laisse "" et le bouton s'affiche « musique à configurer ».
Config.Music = {
	soundId = "",        -- ex. "rbxassetid://123456789"
	volume = 0.25,       -- discret : c'est un fond, pas un concert
}

Config.Crowd = {
	soundId = "",        -- ex. "rbxassetid://123456789"
	volume = 0.6,
	jumpHeight = 3,      -- hauteur du bond des supporters
	jumpTime = 0.28,
	-- Supporters par gradin et par côté. 6 gradins => seatsPerTier x 6 modèles
	-- de 2 parts chacun, par plot et par joueur connecté. À 14 la tribune
	-- coûtait 168 parts par plot et autant de CFrame répliqués à chaque but.
	seatsPerTier = 8,
	-- Rafraîchissement de l'ola. Le bond durant ~0,28 s, 30 Hz suffit largement
	-- et divise par deux le trafic de réplication d'un but.
	waveFps = 30,
	-- Décalage du bond d'un supporter au suivant : plus il est grand, moins il y
	-- a de supporters en l'air en même temps (donc de CFrame à écrire).
	waveOffset = 0.012,
}

-------------------------------------------------------------------------------
-- Helpers de coût / valeur.
-------------------------------------------------------------------------------
function Config.playerValueCost(level: number): number
	return math.floor(Config.PlayerValue.baseCost * (Config.PlayerValue.costGrowth ^ level))
end

function Config.playerValueAt(level: number): number
	return math.floor(Config.PlayerValue.base * (Config.PlayerValue.growth ^ level))
end

-- Tirage d'une rareté. `lucky` = pass Dés Chanceux : le poids des communs est
-- divisé, ce qui remonte mécaniquement toutes les autres raretés.
function Config.rollRarity(rng: Random, lucky: boolean): string
	local weights = {}
	local total = 0
	for i, r in Config.Rarities do
		local w = r.weight
		if lucky and r.key == "commun" then
			w /= Config.Dice.luckyRerollWeight
		end
		weights[i] = w
		total += w
	end
	local pick = rng:NextNumber() * total
	local acc = 0
	for i, r in Config.Rarities do
		acc += weights[i]
		if pick <= acc then
			return r.key
		end
	end
	return Config.Rarities[1].key
end

function Config.randomPlayerName(rng: Random): string
	local pool = Config.NamePool
	return pool.first[rng:NextInteger(1, #pool.first)]
		.. " " .. pool.last[rng:NextInteger(1, #pool.last)]
end

-- Nom de la carte à créer pour une rareté donnée. Les raretés « personnage »
-- (cardName) imposent leur nom ; les autres tirent dans les pools.
function Config.cardNameFor(rarityKey: string, rng: Random): string
	local r = Config.rarity(rarityKey)
	if r.key == rarityKey and r.cardName then return r.cardName end
	return Config.randomPlayerName(rng)
end

-- Formatage abrégé des grands nombres (1.2K, 3.4M, ...).
-- La table s'arrêtait à Qi (1e18) : au-delà, la boucle rendait la main sans
-- avoir fini de diviser et l'écran affichait « 2706349910968550400.00Qi ».
-- Les gains étant multiplicatifs (renaissances × rareté × valeur), on va bien
-- plus haut que 1e18 : la table est allongée et, une fois épuisée, on bascule
-- en notation scientifique plutôt que de cracher le nombre entier.
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Config.abbreviate(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "∞"
	end
	local sign = n < 0 and "-" or ""
	local v = math.abs(n)
	local i = 1
	-- Seuil à 999.995 et pas 1000 : le %.2f final arrondit 999.9999 en
	-- « 1000.00K », qui devrait se lire « 1.00M ».
	while v >= 999.995 and i < #SUFFIXES do
		v /= 1000
		i += 1
	end
	if v >= 999.995 then
		return sign .. string.format("%.2e", v * 1000 ^ (#SUFFIXES - 1))
	end
	if i == 1 then
		return sign .. tostring(math.floor(v))
	end
	return sign .. string.format("%.2f%s", v, SUFFIXES[i])
end

return Config
