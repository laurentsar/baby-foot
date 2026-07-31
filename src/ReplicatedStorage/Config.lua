--!strict
-- Config partagée client/serveur : upgrades, prix, game passes, géométrie du terrain.
-- Tout est éditable ici : c'est la source de vérité de l'équilibrage du jeu.

local Config = {}

Config.SaveKey = "BabyFootPower_v1"  -- change la clé => reset des sauvegardes

-------------------------------------------------------------------------------
-- NOUVEAUTÉS DE LA VERSION.
--
-- À CHAQUE MISE À JOUR : incrémenter `version` et réécrire `notes`. Le client
-- compare cette chaîne à la dernière version vue par le joueur (gardée dans sa
-- sauvegarde) et n'affiche le pop-up qu'une fois, à la première connexion qui
-- suit la mise à jour. Ne rien changer d'autre : le bouton 📣 permet de le
-- rouvrir quand on veut.
--
-- Une version non modifiée = aucun pop-up. C'est volontaire : republier le jeu
-- pour corriger une faute de frappe ne doit pas relancer une annonce.
-------------------------------------------------------------------------------
Config.Release = {
	version = "1.2.0",
	title = "🐾 Mise à jour 1.2 — Pets, Œufs & Téléportation",
	notes = {
		"🥚 ŒUFS & PETS : une plateforme juste à côté du point d'apparition, 3 œufs par monde (9 en tout), 36 pets à collectionner. Chaque pet multiplie l'argent — de ×1,1 à ×6000, et l'œuf éclot sous tes yeux.",
		"🐾 SAC À DOS : tes pets s'y rangent, un seul s'équipe à la fois et te suit en jeu. Bouton ⭐ ÉQUIPER LE MEILLEUR pour ne jamais se tromper.",
		"🚀 TÉLÉPORTATION : va dans n'importe quel monde déjà débloqué depuis la boutique. Attention, c'est le monde OÙ TU ES qui donne son multiplicateur.",
		"🌍 MONDES BEAUCOUP PLUS CHERS : Galactique 1 Sx, Radioactif 1 Oc — ce sont des paliers de fin de partie, plus des cases à cocher.",
		"🎁 DONS : trois boutons 10 % / 25 % / MAX pour offrir sans ouvrir le clavier du téléphone (c'est lui qui faisait quitter la partie).",
		"🗑 La suppression de données passe maintenant par une fenêtre de confirmation en deux temps : plus moyen de se faire éjecter par erreur.",
	},
}

-- Historique : seul `Config.Release` est affiché. On garde la version
-- précédente ici pour retrouver ce qui a été annoncé quand (et pour recopier la
-- forme des notes à la prochaine mise à jour).
Config.PreviousRelease = {
	version = "1.1.0",
	title = "🎉 Mise à jour 1.1 — Chance, Mondes & Défis",
	notes = {
		"🍀 CHANCE : nouvelle amélioration en boutique, jusqu'à x5 de chance de recruter mieux qu'un Commun. Passe Robux « Chance x20 » pour les pressés.",
		"🌍 MONDES : Galactique (1 Qa) donne x2 argent pour toujours, Radioactif (1 Sx) x4. Le terrain change de décor et rien n'est perdu à la renaissance.",
		"🏹 DÉFI DU LOIN : toutes les 10 min, le terrain se vide — un seul but, tirer le plus loin. Les 3 premiers gagnent des potions.",
		"🎒 SAC À DOS : range tes potions (x2 puissance 5 ou 10 min, x3 argent 30 min) et bois-les quand tu veux.",
		"💤 HORS LIGNE : ton équipe continue de jouer quand tu quittes, tu récupères une partie des gains au retour.",
		"📚 TUTORIEL : 8 écrans pour comprendre le jeu, rejouables par le bouton ❓.",
		"🏟️ DÉCOR : pelouse tondue en bandes, marquages au sol, filet de but, toitures de tribunes, éclairage et ciel retravaillés.",
		"🐛 CORRECTIONS : les tirs très puissants ne traversent plus les figurines sans les toucher, « Grand Terrain » s'applique dès l'achat, et plus de trous dans le sol des plots.",
	},
}

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
-- CHANCE : améliore les tirages de dés, s'achète en jeu.
--
-- Le multiplicateur porte sur le POIDS DES RARETÉS AU-DESSUS DU COMMUN, jamais
-- sur le commun lui-même : c'est ce qui garde le calcul lisible (« x3 de chance
-- de sortir mieux qu'un commun ») et empêche la chance de dépasser 100 %.
--
-- Plafond volontaire à x5 : au-delà, le Mythique tombe si souvent que la
-- collection n'a plus d'objectif. Le x20, c'est la passe Robux — et seulement
-- elle (voir Config.LuckPassMultiplier).
-------------------------------------------------------------------------------
Config.Luck = {
	maxLevel = 8,          -- 8 niveaux pour aller de x1 à x5
	multPerLevel = 0.5,    -- x1 -> x1.5 -> ... -> x5
	baseCost = 8000,
	costGrowth = 3.2,
	maxTotal = 100,        -- garde-fou : chance cumulée (upgrade x passe) jamais au-delà
}

Config.LuckPassMultiplier = 20   -- passe « Chance x20 »

-- Chance apportée par le niveau d'amélioration seul (x1 à x5).
function Config.luckFromLevel(level: number): number
	local l = math.clamp(math.floor(level or 0), 0, Config.Luck.maxLevel)
	return 1 + l * Config.Luck.multPerLevel
end

-- Chance totale appliquée au tirage : amélioration x passe, plafonnée.
function Config.luckMultiplier(level: number, hasLuckPass: boolean): number
	local m = Config.luckFromLevel(level)
	if hasLuckPass then m *= Config.LuckPassMultiplier end
	return math.min(m, Config.Luck.maxTotal)
end

function Config.luckCost(level: number): number
	return math.floor(Config.Luck.baseCost * (Config.Luck.costGrowth ^ math.max(0, level)))
end

-------------------------------------------------------------------------------
-- MONDES : le terrain change de décor ET tous les gains sont multipliés.
--
-- Un monde s'achète UNE fois avec l'argent du jeu, définitivement (une
-- renaissance ne le reprend pas : ce serait acheter deux fois la même chose).
-- Le multiplicateur du monde le plus haut débloqué s'applique en permanence, il
-- n'y a rien à réactiver.
--
-- Les seuils sont volontairement énormes : un monde n'est pas une amélioration
-- de plus, c'est un palier de fin de partie.
-------------------------------------------------------------------------------
-- Prix relevés le 2026-07-31 : à 1 Qa / 1 Sx, les deux mondes tombaient dans la
-- même soirée de jeu et le Radioactif n'était plus un objectif. Un monde doit
-- rester un palier qu'on VISE, pas une case qu'on coche en passant.
Config.Worlds = {
	{ key = "stade",      name = "Stade",       cost = 0,     moneyMult = 1,
	  ground = Color3.fromRGB(30, 140, 70),   groundMaterial = Enum.Material.Grass,
	  wall = Color3.fromRGB(120, 80, 45),     accent = Color3.fromRGB(80, 220, 255) },
	{ key = "galactique", name = "Galactique",  cost = 1e21,  moneyMult = 2,
	  ground = Color3.fromRGB(38, 26, 78),    groundMaterial = Enum.Material.Slate,
	  wall = Color3.fromRGB(70, 58, 130),     accent = Color3.fromRGB(180, 110, 255) },
	{ key = "radioactif", name = "Radioactif",  cost = 1e27,  moneyMult = 4,
	  ground = Color3.fromRGB(96, 168, 40),   groundMaterial = Enum.Material.Ground,
	  wall = Color3.fromRGB(64, 92, 30),      accent = Color3.fromRGB(180, 255, 60) },
}

function Config.world(index: number?)
	return Config.Worlds[math.clamp(math.floor(index or 1), 1, #Config.Worlds)]
end

function Config.worldMultiplier(index: number?): number
	return Config.world(index).moneyMult
end

-- Monde suivant à débloquer (nil si on a déjà tout).
function Config.nextWorld(index: number?)
	local i = math.clamp(math.floor(index or 1), 1, #Config.Worlds)
	return Config.Worlds[i + 1]
end

-------------------------------------------------------------------------------
-- ŒUFS ET PETS.
--
-- Trois œufs par monde, de plus en plus chers, sur la plateforme du parvis
-- (juste à côté du point d'apparition). Un œuf ne donne QUE des pets de son
-- monde : c'est ce qui fait qu'on veut débloquer le monde suivant, et pas
-- seulement son multiplicateur.
--
-- Les prix sont calés sur le PRIX DU MONDE : le premier œuf d'un monde est
-- abordable dès qu'on vient de le débloquer, le troisième reste un objectif.
-- Trop bas (première version), les neuf œufs tombaient dans la foulée du monde
-- et la collection de pets se terminait en une soirée.
--
-- Un pet multiplie l'argent gagné, et UN SEUL est équipé à la fois : sans cette
-- règle, la collection de pets remplacerait toute la boucle du jeu (il suffirait
-- d'ouvrir des œufs). Les autres restent dans le sac à dos.
--
-- `weight` = poids de tirage dans l'œuf. `mult` = multiplicateur d'argent.
-------------------------------------------------------------------------------
Config.Eggs = {
	-- MONDE 1 — STADE
	{
		{ key = "oeuf_herbe", name = "Œuf d'Herbe", cost = 250e3,
		  color = Color3.fromRGB(120, 200, 110), pets = {
			{ key = "p_balle",    name = "Balle Rebondissante", mult = 1.1,  weight = 60, color = Color3.fromRGB(230, 230, 235) },
			{ key = "p_chaton",   name = "Chaton du Stade",     mult = 1.25, weight = 30, color = Color3.fromRGB(235, 180, 120) },
			{ key = "p_coq",      name = "Petit Coq",           mult = 1.5,  weight = 9,  color = Color3.fromRGB(230, 90, 70)   },
			{ key = "p_coq_or",   name = "Coq d'Or",            mult = 2,    weight = 1,  color = Color3.fromRGB(255, 205, 60)  },
		} },
		{ key = "oeuf_cuir", name = "Œuf de Cuir", cost = 50e6,
		  color = Color3.fromRGB(150, 110, 70), pets = {
			{ key = "p_sifflet",  name = "Sifflet Vivant",      mult = 1.6,  weight = 55, color = Color3.fromRGB(200, 200, 210) },
			{ key = "p_crampon",  name = "Crampon Fou",         mult = 2,    weight = 32, color = Color3.fromRGB(120, 130, 160) },
			{ key = "p_mascotte", name = "Mascotte",            mult = 2.6,  weight = 11, color = Color3.fromRGB(240, 120, 180) },
			{ key = "p_capitaine",name = "Capitaine",           mult = 3.5,  weight = 2,  color = Color3.fromRGB(255, 170, 40)  },
		} },
		{ key = "oeuf_trophee", name = "Œuf Trophée", cost = 5e9,
		  color = Color3.fromRGB(255, 200, 70), pets = {
			{ key = "p_gant",     name = "Gant de Gardien",     mult = 3,    weight = 55, color = Color3.fromRGB(90, 200, 160)  },
			{ key = "p_ballon_or",name = "Ballon d'Or",         mult = 4,    weight = 30, color = Color3.fromRGB(255, 215, 80)  },
			{ key = "p_coupe",    name = "Petite Coupe",        mult = 5.5,  weight = 13, color = Color3.fromRGB(255, 235, 150) },
			{ key = "p_legende",  name = "Légende du Baby",     mult = 8,    weight = 2,  color = Color3.fromRGB(255, 120, 200) },
		} },
	},
	-- MONDE 2 — GALACTIQUE
	{
		{ key = "oeuf_meteore", name = "Œuf Météore", cost = 5e18,
		  color = Color3.fromRGB(120, 110, 150), pets = {
			{ key = "p_cailloustre", name = "Caillou Astral",   mult = 10,   weight = 58, color = Color3.fromRGB(150, 145, 170) },
			{ key = "p_satellite",   name = "Petit Satellite",  mult = 13,   weight = 30, color = Color3.fromRGB(180, 190, 220) },
			{ key = "p_comete",      name = "Comète",           mult = 17,   weight = 10, color = Color3.fromRGB(120, 200, 255) },
			{ key = "p_pulsar",      name = "Pulsar",           mult = 24,   weight = 2,  color = Color3.fromRGB(210, 130, 255) },
		} },
		{ key = "oeuf_nebuleuse", name = "Œuf Nébuleuse", cost = 5e20,
		  color = Color3.fromRGB(170, 100, 235), pets = {
			{ key = "p_nuage",       name = "Nuage Stellaire",  mult = 26,   weight = 55, color = Color3.fromRGB(190, 150, 255) },
			{ key = "p_alien",       name = "Petit Alien",      mult = 34,   weight = 31, color = Color3.fromRGB(120, 255, 170) },
			{ key = "p_ovni",        name = "OVNI",             mult = 45,   weight = 12, color = Color3.fromRGB(160, 220, 255) },
			{ key = "p_supernova",   name = "Supernova",        mult = 65,   weight = 2,  color = Color3.fromRGB(255, 200, 120) },
		} },
		{ key = "oeuf_trou_noir", name = "Œuf Trou Noir", cost = 5e22,
		  color = Color3.fromRGB(40, 30, 60), pets = {
			{ key = "p_etoile",      name = "Étoile Naine",     mult = 70,   weight = 55, color = Color3.fromRGB(255, 240, 190) },
			{ key = "p_orbite",      name = "Anneau d'Orbite",  mult = 95,   weight = 30, color = Color3.fromRGB(190, 190, 255) },
			{ key = "p_galaxie",     name = "Mini Galaxie",     mult = 130,  weight = 13, color = Color3.fromRGB(210, 120, 255) },
			{ key = "p_singularite", name = "Singularité",      mult = 190,  weight = 2,  color = Color3.fromRGB(90, 60, 160)   },
		} },
	},
	-- MONDE 3 — RADIOACTIF
	{
		{ key = "oeuf_fut", name = "Œuf Fût", cost = 5e24,
		  color = Color3.fromRGB(150, 200, 60), pets = {
			{ key = "p_goutte",   name = "Goutte Verte",        mult = 220,  weight = 58, color = Color3.fromRGB(160, 255, 90)  },
			{ key = "p_rat",      name = "Rat Mutant",          mult = 300,  weight = 30, color = Color3.fromRGB(140, 180, 110) },
			{ key = "p_masque",   name = "Masque à Gaz",        mult = 420,  weight = 10, color = Color3.fromRGB(90, 130, 90)   },
			{ key = "p_barril",   name = "Barril Instable",     mult = 600,  weight = 2,  color = Color3.fromRGB(210, 255, 80)  },
		} },
		{ key = "oeuf_reacteur", name = "Œuf Réacteur", cost = 5e26,
		  color = Color3.fromRGB(200, 255, 90), pets = {
			{ key = "p_noyau",    name = "Noyau Chaud",         mult = 700,  weight = 55, color = Color3.fromRGB(255, 220, 90)  },
			{ key = "p_isotope",  name = "Isotope",             mult = 950,  weight = 31, color = Color3.fromRGB(180, 255, 140) },
			{ key = "p_geiger",   name = "Compteur Geiger",     mult = 1300, weight = 12, color = Color3.fromRGB(230, 230, 130) },
			{ key = "p_fusion",   name = "Cœur de Fusion",      mult = 1900, weight = 2,  color = Color3.fromRGB(120, 255, 255) },
		} },
		{ key = "oeuf_mutation", name = "Œuf Mutation", cost = 5e28,
		  color = Color3.fromRGB(120, 255, 160), pets = {
			{ key = "p_tentacule",name = "Tentacule",           mult = 2200, weight = 55, color = Color3.fromRGB(150, 100, 200) },
			{ key = "p_hydre",    name = "Hydre à Trois Têtes", mult = 3000, weight = 30, color = Color3.fromRGB(90, 220, 140)  },
			{ key = "p_colosse",  name = "Colosse Vert",        mult = 4200, weight = 13, color = Color3.fromRGB(80, 255, 100)  },
			{ key = "p_omega",    name = "Oméga",               mult = 6000, weight = 2,  color = Color3.fromRGB(255, 90, 220)  },
		} },
	},
}

-- Index construit une fois : clé de pet -> pet, et clé d'œuf -> œuf + monde.
local PET_INDEX: { [string]: any } = {}
local EGG_INDEX: { [string]: any } = {}
for worldIndex, eggs in Config.Eggs do
	for eggIndex, egg in eggs do
		EGG_INDEX[egg.key] = { egg = egg, world = worldIndex, index = eggIndex }
		for _, pet in egg.pets do
			PET_INDEX[pet.key] = { pet = pet, world = worldIndex, egg = egg.key }
		end
	end
end

function Config.eggsFor(worldIndex: number?)
	return Config.Eggs[math.clamp(math.floor(worldIndex or 1), 1, #Config.Eggs)]
end

-- Œuf par sa clé, avec le monde auquel il appartient (nil si clé inconnue).
function Config.eggInfo(key: string)
	return EGG_INDEX[key]
end

function Config.pet(key: string)
	local entry = PET_INDEX[key]
	return entry and entry.pet or nil
end

function Config.petMultiplier(key: string?): number
	if not key or key == "" then return 1 end
	local pet = Config.pet(key)
	return pet and pet.mult or 1
end

-- Tirage d'un pet dans un œuf. Fait UNIQUEMENT côté serveur : le client ne
-- connaît que le résultat.
function Config.rollPet(rng: Random, egg): string
	local total = 0
	for _, pet in egg.pets do total += pet.weight end
	local pick = rng:NextNumber() * total
	local acc = 0
	for _, pet in egg.pets do
		acc += pet.weight
		if pick <= acc then return pet.key end
	end
	return egg.pets[1].key
end

-- Meilleur pet possédé (celui au plus gros multiplicateur), pour le bouton
-- « équiper le meilleur ». `owned` = { [clé] = nombre }.
function Config.bestOwnedPet(owned: { [string]: number }?): string?
	if not owned then return nil end
	local bestKey, bestMult = nil, 0
	for key, count in owned do
		if (tonumber(count) or 0) > 0 then
			local pet = Config.pet(key)
			if pet and pet.mult > bestMult then
				bestKey, bestMult = key, pet.mult
			end
		end
	end
	return bestKey
end

-------------------------------------------------------------------------------
-- DÉFI DU LOIN (toutes les 10 minutes).
--
-- Pendant la fenêtre de défi, le terrain se vide : plus de figurines, plus de
-- but, plus de murs — un baby-foot infini. Un seul objectif : envoyer la balle
-- LE PLUS LOIN possible. Aucun argent n'est gagné pendant un tir de défi, c'est
-- une épreuve d'adresse, pas une source de revenus (sinon elle remplacerait le
-- jeu normal).
--
-- Les récompenses sont des potions, rangées dans le sac à dos : elles ne
-- s'appliquent pas toutes seules, c'est le joueur qui choisit quand les boire.
-------------------------------------------------------------------------------
Config.Challenge = {
	interval = 600,     -- un défi toutes les 10 minutes
	duration = 60,      -- durée de la fenêtre de tir
	warmup = 10,        -- annonce avant le départ
	-- Durée de vol max d'une balle de défi. C'est elle qui borne le temps de
	-- l'épreuve : au-delà de cette durée, la décélération est augmentée pour que
	-- la balle s'arrête à temps (la distance reste strictement croissante avec la
	-- puissance, donc le classement reste juste — cf. performShot).
	maxFlight = 12,
	-- Récompenses par place. Une place sans participant ne distribue rien.
	rewards = { "argent3_30", "puissance2_10", "puissance2_5" },
}

-------------------------------------------------------------------------------
-- POTIONS (sac à dos).
--
-- kind = "money" (multiplie l'argent gagné) ou "power" (multiplie la puissance
-- du tir). Boire une potion du même type qu'un effet en cours ne cumule pas les
-- multiplicateurs : on garde le meilleur et on ADDITIONNE le temps, sinon deux
-- potions bues coup sur coup en gaspillaient une.
-------------------------------------------------------------------------------
Config.Potions = {
	{ key = "puissance2_5",  name = "Potion de Puissance",  kind = "power", mult = 2, duration = 300,
	  desc = "x2 puissance de tir pendant 5 min",  color = Color3.fromRGB(90, 200, 255) },
	{ key = "puissance2_10", name = "Grande Potion de Puissance", kind = "power", mult = 2, duration = 600,
	  desc = "x2 puissance de tir pendant 10 min", color = Color3.fromRGB(70, 160, 255) },
	{ key = "argent3_30",    name = "Potion d'Or",          kind = "money", mult = 3, duration = 1800,
	  desc = "x3 argent pendant 30 min",           color = Color3.fromRGB(255, 200, 50) },
}

function Config.potion(key: string)
	for _, p in Config.Potions do
		if p.key == key then return p end
	end
	return nil
end

-------------------------------------------------------------------------------
-- GAINS HORS LIGNE.
--
-- On ne simule rien : on retient le rythme de gain observé pendant la partie
-- (argent par seconde) et on en reverse une fraction pour le temps passé
-- déconnecté, plafonné. Une simulation complète donnerait le même ordre de
-- grandeur pour beaucoup plus de code — et récompenserait la déconnexion autant
-- que le jeu, ce qu'on ne veut pas : d'où le `rate` bien en dessous de 1.
-------------------------------------------------------------------------------
Config.Offline = {
	rate = 0.35,          -- part du rythme de jeu accordée hors ligne
	maxSeconds = 8 * 3600, -- au-delà de 8 h, on ne compte plus
	minSeconds = 60,      -- en dessous d'une minute, on ne dit rien
}

function Config.offlineEarnings(earnPerSec: number, seconds: number): number
	if earnPerSec ~= earnPerSec or earnPerSec <= 0 then return 0 end
	if seconds ~= seconds or seconds < Config.Offline.minSeconds then return 0 end
	local t = math.min(seconds, Config.Offline.maxSeconds)
	return math.floor(earnPerSec * t * Config.Offline.rate)
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
	LuckX20     = 0,
}

Config.Passes = {
	VIP          = { id = Config.PassIds.VIP,         price = 199, label = "VIP",              desc = "x2 argent + dés 30% moins chers + étiquette VIP au-dessus du nom" },
	MoneyX2      = { id = Config.PassIds.MoneyX2,     price = 149, label = "Argent x2",        desc = "Double tout l'argent gagné (cumulable avec VIP)" },
	RebirthX2    = { id = Config.PassIds.RebirthX2,   price = 249, label = "Renaissance x2",   desc = "Double le multiplicateur de renaissance" },
	LuckyDice    = { id = Config.PassIds.LuckyDice,   price = 299, label = "Dés Chanceux",     desc = "Bien moins de communs : les raretés sortent beaucoup plus souvent" },
	BallSpeedX2  = { id = Config.PassIds.BallSpeedX2, price = 129, label = "Vitesse Balle x2", desc = "La balle part deux fois plus vite" },
	BigField     = { id = Config.PassIds.BigField,    price = 179, label = "Grand Terrain",    desc = "Le fond du baby-foot est deux fois plus grand (but plus facile)" },
	AutoShoot    = { id = Config.PassIds.AutoShoot,   price = 349, label = "Tir Automatique",  desc = "Tire tout seul, en balayant le terrain. Gratuit pour tous à 500Qa gagnés" },
	LuckX20      = { id = Config.PassIds.LuckX20,     price = 499, label = "Chance x20",       desc = "x20 de chance de recruter mieux qu'un Commun (se cumule avec l'amélioration Chance)" },
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

-- Tirage d'une rareté.
--   `lucky`    = pass Dés Chanceux : le poids des communs est divisé, ce qui
--                remonte mécaniquement toutes les autres raretés.
--   `luckMult` = chance (amélioration en jeu x passe Chance x20) : multiplie le
--                poids de TOUT ce qui est au-dessus du commun. Le commun n'est
--                jamais touché, donc la chance reste bornée : même à x100, il
--                reste une part de communs.
function Config.rollRarity(rng: Random, lucky: boolean, luckMult: number?): string
	local luck = math.max(1, luckMult or 1)
	local weights = {}
	local total = 0
	for i, r in Config.Rarities do
		local w = r.weight
		if r.key == "commun" then
			if lucky then
				w /= Config.Dice.luckyRerollWeight
			end
		else
			w *= luck
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
-- Jusqu'a 1e63. La table s'arretait a Dc (1e33) et un solde de 8e37 sortait
-- en notation scientifique en plein ecran de jeu, illisible.
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
	"Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg" }

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
