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
	version = "1.4.0",
	title = "🐾 Mise à jour 1.4 — Équipe nommée, Quêtes & Gemmes",
	notes = {
		"🏷 NOMME TON ÉQUIPE : à ta toute première partie, choisis le nom de ton équipe. Il est sauvegardé — on ne te le redemandera plus.",
		"📜 QUÊTES SUR LES MURS : les murs derrière ta zone de tir affichent des quêtes à ton nom. Chaque quête accomplie te donne des 💎 gemmes ; plus elle est difficile, plus tu gagnes.",
		"💎 GEMMES : une nouvelle monnaie. Dépense-la pour acheter directement des niveaux de VALEUR JOUEUR et de CHANCE, dans le nouveau panneau AMÉLIORATION.",
		"🔧 NOUVEL AGENCEMENT : les améliorations quittent la boutique pour un bouton carré AMÉLIORATION en bas à gauche ; le bouton COÉQUIPIERS passe lui aussi en bas.",
		"🏆 CLASSEMENTS SÉPARÉS : trois classements mondiaux (Argent, Puissance, Gemmes) côte à côte sur trois écrans, plus jolis et plus compacts.",
		"🥅 FINISSEUR : nouvelle amélioration qui fait rapporter PLUS D'ARGENT quand tu marques un but.",
		"🥅 PLUS DE PLACE : les murs de la zone de tir ont reculé pour qu'on soit à l'aise pour jouer.",
		"💰 ÉCONOMIE REVUE : les gains d'argent sont fortement réduits, et un don ne peut plus dépasser 500 $.",
		"💎 GROS NOMBRES : au-delà des suffixes, l'échelle passe en « Diamant 1, Diamant 2… » au lieu d'« Infini ».",
	},
}

-- Historique : seul `Config.Release` est affiché. On garde la version
-- précédente ici pour retrouver ce qui a été annoncé quand (et pour recopier la
-- forme des notes à la prochaine mise à jour).
Config.PreviousRelease = {
	version = "1.3.0",
	title = "🐾 Mise à jour 1.3 — Équipe, Pets multiples & Spectateur",
	notes = {
		"👥 COMPOSITION D'ÉQUIPE : choisis QUI joue à QUEL poste.",
		"🐾 PLUSIEURS PETS À LA FOIS : jusqu'à 6, bonus additionnés.",
		"📕 INDEX DES PETS, 👁 MODE SPECTATEUR, 💤 MODE AFK.",
		"🎁 DONS réglés au doigt, jusqu'à 100 % de ta fortune.",
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
	{ name = "Haltère Quantique",powerGain = 1700,  cost = 250000000 },
	{ name = "Haltère Abyssal",  powerGain = 5000,  cost = 1500000000 },
	{ name = "Haltère Céleste",  powerGain = 15000, cost = 10000000000 },
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
	{ name = "Balle Abyssale", moneyMult = 500,  cost = 200000000 },
	{ name = "Balle Céleste",  moneyMult = 1400, cost = 1500000000 },
	{ name = "Balle Divine",   moneyMult = 4000, cost = 10000000000 },
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
	-- Tiers au-dessus de l'Astral : de plus en plus rares, à offrir ou à viser sur
	-- le très long terme. Chacun est un personnage unique (cardName).
	{ key = "cosmique",   name = "Cosmique",   mult = 2500,  weight = 0.002,  color = Color3.fromRGB(120, 220, 255),
	  cardName = "Le Cosmique" },
	{ key = "eternel",    name = "Éternel",    mult = 6000,  weight = 0.0008, color = Color3.fromRGB(255, 150, 60),
	  cardName = "L'Éternel" },
	-- ADMIN : la rareté ULTRA RARE. weight = 0 => JAMAIS tirée aux dés. On ne
	-- l'obtient que par le panneau admin (ou un don). C'est la carte au sommet
	-- absolu du tableau, tenue et couleur uniques (cf. Config.Skins.admin).
	{ key = "admin",      name = "Admin",      mult = 100000, weight = 0,     color = Color3.fromRGB(255, 40, 40),
	  cardName = "Administrateur" },
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
	{ key = "abysses",    name = "Abysses",     cost = 1e33,  moneyMult = 8,
	  ground = Color3.fromRGB(12, 52, 62),    groundMaterial = Enum.Material.Slate,
	  wall = Color3.fromRGB(18, 74, 86),      accent = Color3.fromRGB(64, 224, 208) },
	{ key = "celeste",    name = "Céleste",     cost = 1e39,  moneyMult = 16,
	  ground = Color3.fromRGB(232, 216, 150), groundMaterial = Enum.Material.Marble,
	  wall = Color3.fromRGB(210, 190, 96),    accent = Color3.fromRGB(255, 240, 160) },
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
	-- MONDE 4 — ABYSSES
	{
		{ key = "oeuf_corail", name = "Œuf de Corail", cost = 5e30,
		  color = Color3.fromRGB(60, 150, 160), pets = {
			{ key = "p_ab_meduse",  name = "Méduse Lumineuse",  mult = 7000,   weight = 58, color = Color3.fromRGB(140, 220, 230) },
			{ key = "p_ab_crabe",   name = "Crabe des Fonds",   mult = 9500,   weight = 30, color = Color3.fromRGB(200, 90, 80)   },
			{ key = "p_ab_hippo",   name = "Hippocampe",        mult = 13000,  weight = 10, color = Color3.fromRGB(120, 200, 180) },
			{ key = "p_ab_perle",   name = "Perle Noire",       mult = 19000,  weight = 2,  color = Color3.fromRGB(60, 70, 90)    },
		} },
		{ key = "oeuf_fosse", name = "Œuf de la Fosse", cost = 5e32,
		  color = Color3.fromRGB(30, 90, 110), pets = {
			{ key = "p_ab_anguille",name = "Anguille Électrique",mult = 22000, weight = 55, color = Color3.fromRGB(150, 230, 255) },
			{ key = "p_ab_pieuvre", name = "Pieuvre Géante",    mult = 30000,  weight = 31, color = Color3.fromRGB(150, 80, 160)  },
			{ key = "p_ab_requin",  name = "Requin Abyssal",    mult = 42000,  weight = 12, color = Color3.fromRGB(90, 110, 130)  },
			{ key = "p_ab_kraken",  name = "Kraken",            mult = 60000,  weight = 2,  color = Color3.fromRGB(40, 90, 100)   },
		} },
		{ key = "oeuf_tresor", name = "Œuf au Trésor", cost = 5e34,
		  color = Color3.fromRGB(90, 200, 200), pets = {
			{ key = "p_ab_ancre",   name = "Ancre Maudite",     mult = 70000,  weight = 55, color = Color3.fromRGB(120, 140, 150) },
			{ key = "p_ab_sirene",  name = "Sirène",            mult = 95000,  weight = 30, color = Color3.fromRGB(120, 230, 200) },
			{ key = "p_ab_leviathan",name = "Léviathan",        mult = 130000, weight = 13, color = Color3.fromRGB(50, 130, 140)  },
			{ key = "p_ab_neptune", name = "Trident de Neptune",mult = 190000, weight = 2,  color = Color3.fromRGB(80, 220, 230)  },
		} },
	},
	-- MONDE 5 — CÉLESTE
	{
		{ key = "oeuf_nuage", name = "Œuf de Nuage", cost = 5e36,
		  color = Color3.fromRGB(235, 235, 245), pets = {
			{ key = "p_ce_plume",   name = "Plume d'Ange",      mult = 220000,  weight = 58, color = Color3.fromRGB(250, 250, 255) },
			{ key = "p_ce_colombe", name = "Colombe Dorée",     mult = 300000,  weight = 30, color = Color3.fromRGB(255, 235, 160) },
			{ key = "p_ce_harpe",   name = "Harpe Céleste",     mult = 420000,  weight = 10, color = Color3.fromRGB(255, 220, 120) },
			{ key = "p_ce_aureole", name = "Auréole",           mult = 600000,  weight = 2,  color = Color3.fromRGB(255, 245, 180) },
		} },
		{ key = "oeuf_astre", name = "Œuf d'Astre", cost = 5e38,
		  color = Color3.fromRGB(255, 220, 120), pets = {
			{ key = "p_ce_seraphin",name = "Séraphin",          mult = 700000,  weight = 55, color = Color3.fromRGB(255, 240, 190) },
			{ key = "p_ce_phenix",  name = "Phénix",            mult = 950000,  weight = 31, color = Color3.fromRGB(255, 140, 60)  },
			{ key = "p_ce_pegase",  name = "Pégase",            mult = 1300000, weight = 12, color = Color3.fromRGB(240, 240, 255) },
			{ key = "p_ce_licorne", name = "Licorne Astrale",   mult = 1900000, weight = 2,  color = Color3.fromRGB(220, 180, 255) },
		} },
		{ key = "oeuf_divin", name = "Œuf Divin", cost = 5e40,
		  color = Color3.fromRGB(255, 245, 200), pets = {
			{ key = "p_ce_titan",   name = "Titan Céleste",     mult = 2200000, weight = 55, color = Color3.fromRGB(255, 230, 150) },
			{ key = "p_ce_gardien", name = "Gardien des Cieux", mult = 3000000, weight = 30, color = Color3.fromRGB(200, 220, 255) },
			{ key = "p_ce_dragon",  name = "Dragon Solaire",    mult = 4200000, weight = 13, color = Color3.fromRGB(255, 180, 70)  },
			{ key = "p_ce_divinite",name = "Divinité",          mult = 6000000, weight = 2,  color = Color3.fromRGB(255, 255, 240) },
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

-- Chances d'obtention (%) de chaque pet d'un œuf, d'après les poids de tirage.
-- Trié du plus fréquent au plus rare. Utilisé par l'affichage à l'approche d'un
-- œuf (billboard « chances »).
function Config.eggChances(egg)
	local total = 0
	for _, pet in egg.pets do total += pet.weight end
	local out = {}
	for _, pet in egg.pets do
		table.insert(out, {
			key = pet.key, name = pet.name, color = pet.color, mult = pet.mult,
			pct = if total > 0 then pet.weight / total * 100 else 0,
		})
	end
	table.sort(out, function(a, b) return a.pct > b.pct end)
	return out
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
-- ÉQUIPER PLUSIEURS PETS.
--
-- Les multiplicateurs des pets équipés s'ADDITIONNENT (1 + somme des bonus) et
-- ne se multiplient pas : trois pets à x6000 donneraient sinon x2 x 10^11, un
-- nombre qui écrase tout le reste du jeu en une fois. Additionnés, trois pets
-- valent trois fois un pet — c'est déjà beaucoup, et ça reste lisible.
--
-- Le nombre de places monte avec les renaissances : c'est une raison de plus de
-- renaître, et ça évite d'avoir tout de suite six pets sur le dos.
-------------------------------------------------------------------------------
Config.PetSlots = {
	base = 2,
	perRebirth = 1,   -- une place de plus toutes les `rebirthsPer` renaissances
	rebirthsPer = 2,
	max = 6,
}

function Config.petSlots(rebirths: number?): number
	local r = math.max(0, math.floor(rebirths or 0))
	local extra = math.floor(r / Config.PetSlots.rebirthsPer) * Config.PetSlots.perRebirth
	return math.clamp(Config.PetSlots.base + extra, Config.PetSlots.base, Config.PetSlots.max)
end

-- Multiplicateur total d'une liste de pets équipés.
function Config.petsMultiplier(keys: { string }?): number
	if not keys then return 1 end
	local bonus = 0
	for _, key in keys do
		local pet = Config.pet(key)
		if pet then bonus += pet.mult - 1 end
	end
	return 1 + bonus
end

-- Catalogue des pets pour l'index : tous les pets du jeu, dans l'ordre monde →
-- œuf → multiplicateur. Construit une fois, comme le catalogue des joueurs.
local PET_CATALOGUE: { any } = {}
for worldIndex, eggs in Config.Eggs do
	for _, egg in eggs do
		for _, pet in egg.pets do
			table.insert(PET_CATALOGUE, {
				key = pet.key, name = pet.name, mult = pet.mult, color = pet.color,
				egg = egg.name, eggKey = egg.key, world = worldIndex,
				worldName = Config.Worlds[worldIndex] and Config.Worlds[worldIndex].name or "?",
			})
		end
	end
end

function Config.petCatalogue()
	return PET_CATALOGUE
end

function Config.petCatalogueSize(): number
	return #PET_CATALOGUE
end

-------------------------------------------------------------------------------
-- ORDRE DES EMPLACEMENTS DU TERRAIN.
--
-- Partagé client/serveur : le serveur y place les figurines, le client s'en sert
-- pour l'écran de composition d'équipe. Les deux DOIVENT lire la même liste,
-- sinon « poser le Mythique au gardien » ne poserait pas le Mythique au gardien.
--
-- L'ordre est un tour de table du gardien vers l'attaque : les premiers
-- emplacements couvrent donc les quatre lignes plutôt que d'entasser l'attaque.
-------------------------------------------------------------------------------
-- `basesOverride` : liste de bases déjà calculée (le serveur la garde dans le
-- terrain). Sans elle, on la recalcule depuis le nombre d'emplacements bonus.
function Config.slotOrder(extra: number?, basesOverride: any?)
	local bases = basesOverride or Config.basesWithExtra(extra)
	local perBase = {}
	local total = 0
	for b, base in bases do
		perBase[b] = base.slots
		total += base.slots
	end

	local order = { 4, 3, 2, 1 }   -- Gardien, Défense, Milieu, Attaque
	local cursor = { 0, 0, 0, 0 }
	local slots = {}
	while #slots < total do
		local placedOne = false
		for _, b in order do
			if perBase[b] and cursor[b] < perBase[b] then
				cursor[b] += 1
				table.insert(slots, { baseIndex = b, base = bases[b].name, indexInBase = cursor[b] })
				placedOne = true
				if #slots >= total then break end
			end
		end
		if not placedOne then break end
	end
	return slots
end

-------------------------------------------------------------------------------
-- MODE AFK : la puissance monte toute seule, mais moins vite qu'à la main.
--
-- `rate` = part du rythme manuel. À 1, personne ne toucherait plus au bouton
-- d'entraînement ; trop bas, le mode ne sert à rien. Un peu plus de la moitié
-- laisse l'entraînement actif meilleur tout en rendant l'absence utile.
-------------------------------------------------------------------------------
Config.Afk = {
	rate = 0.55,
	interval = 1,   -- fréquence des gains automatiques (s)
}

-- Puissance gagnée par seconde en AFK, pour un haltère donné.
function Config.afkPowerPerSecond(powerGain: number): number
	return powerGain * (1 / Config.Train.repCooldown) * Config.Afk.rate
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
-- FINISSEUR : amélioration qui augmente l'argent gagné QUAND ON MARQUE.
-- N'affecte que les buts (pas les simples touches) : c'est la récompense de la
-- précision. Multiplicateur = 1 + niveau * bonusPerLevel, cumulatif avec le x3
-- de but déjà en place (Config.Shot.scoreMultiplier).
-------------------------------------------------------------------------------
Config.GoalBonus = {
	bonusPerLevel = 0.5,   -- +50 % d'argent sur un but par niveau
	baseCost = 5000,
	costGrowth = 1.7,
}

function Config.goalBonusMult(level: number): number
	return 1 + math.max(0, math.floor(level or 0)) * Config.GoalBonus.bonusPerLevel
end

function Config.goalBonusCost(level: number): number
	return math.floor(Config.GoalBonus.baseCost * (Config.GoalBonus.costGrowth ^ math.max(0, level)))
end

-------------------------------------------------------------------------------
-- ÉQUILIBRAGE GLOBAL DES GAINS.
--
-- Knob unique appliqué à TOUT l'argent gagné en jeu (via moneyMultiplier dans
-- Main.server). N'affecte NI les dons (transferts entre joueurs) NI les commandes
-- admin : ceux-ci ne passent pas par moneyMultiplier.
--
-- 1 = gains d'avant. 0.02 = gains à 2 % (≈ 50× moins) — réglé car on gagnait
-- beaucoup trop d'argent (« argent infini » ressenti). Baisser encore vers 0
-- pour ralentir davantage, remonter vers 1 pour revenir aux gains d'origine.
-------------------------------------------------------------------------------
Config.MoneyGain = 0.02

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
	-- Part max de sa fortune offerte EN UNE FOIS. À 0,5, on ne pouvait pas offrir
	-- la somme qu'on voulait... sauf en donnant deux fois de suite : le plafond
	-- ne protégeait donc de rien, il ne faisait qu'agacer. Ce qui limite l'abus,
	-- c'est le cooldown, et le fait qu'un don ne CRÉE jamais d'argent.
	maxShare = 1,
	minMoney = 1,
	-- Plafond ABSOLU d'un don d'argent : quoi qu'il arrive, un don ne dépasse
	-- jamais cette somme, même si le donneur est riche. Réglé à 500 pour que les
	-- dons restent un coup de pouce entre joueurs, pas un transfert de fortune.
	maxAbsolute = 500,
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
-- 5393457901 : l'UserId vu dans le log de ton test en Studio (clé p_5393457901).
-- Vérifie qu'il correspond bien au nombre dans l'URL de ton profil Roblox — un
-- id erroné donnerait le panneau admin à un inconnu.
Config.Admins = { 5393457901 } :: { number }

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
-- GARDIEN.
--
-- Quand la balle arrive dans le cadre, le gardien TENTE un arrêt : il ne prend
-- pas tout, mais parfois il détourne le tir (pas de but). Un tir parfait
-- (« TRÈS BIEN ») passe beaucoup plus souvent — le skill récompense le joueur.
-------------------------------------------------------------------------------
Config.Keeper = {
	saveChance = 0.28,        -- arrêt sur un tir normal
	perfectSaveChance = 0.10, -- arrêt sur un tir « TRÈS BIEN »
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
	-- ADMIN : rouge néon + halo doré, reconnaissable entre toutes.
	admin = {
		body = Color3.fromRGB(220, 30, 30),
		stripe = Color3.fromRGB(255, 90, 60),
		trim = Color3.fromRGB(255, 215, 80),
		shorts = Color3.fromRGB(30, 30, 34),
		head = Color3.fromRGB(255, 220, 180),
		arms = Color3.fromRGB(220, 30, 30),
		socks = Color3.fromRGB(255, 215, 80),
		shoes = Color3.fromRGB(20, 20, 24),
		glow = true,
		halo = Color3.fromRGB(255, 60, 60),
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
-- Toutes les `cycle` secondes, coup de sifflet : un ÉVÉNEMENT tiré au hasard
-- dans Config.Events s'ouvre pour tout le serveur. Le compte à rebours vit côté
-- serveur (le client ne fait que l'afficher via le panneau).
-------------------------------------------------------------------------------
Config.Match = {
	cycle = 30,
}

-------------------------------------------------------------------------------
-- ÉVÉNEMENTS : la liste dans laquelle le coup de sifflet pioche.
--
-- Le même événement pour tout le serveur, annoncé à chacun et écrit sur le
-- grand écran. Pendant `duration` secondes :
--   money = multiplicateur d'argent gagné,
--   power = multiplicateur de puissance du tir,
--   luck  = multiplicateur de chance aux dés.
-- 1 = pas d'effet. AJOUTER UN ÉVÉNEMENT = ajouter une ligne ici, rien d'autre.
-------------------------------------------------------------------------------
Config.Events = {
	{ key = "sifflet", name = "📣 COUP DE SIFFLET", desc = "argent ×2",
	  duration = 10, money = 2, power = 1, luck = 1, color = Color3.fromRGB(120, 255, 140) },
	{ key = "jackpot", name = "💰 JACKPOT", desc = "argent ×5",
	  duration = 8,  money = 5, power = 1, luck = 1, color = Color3.fromRGB(255, 215, 80) },
	{ key = "muscle",  name = "💪 COUP DE MUSCLE", desc = "tir ×2",
	  duration = 15, money = 1, power = 2, luck = 1, color = Color3.fromRGB(255, 140, 90) },
	{ key = "etoile",  name = "🍀 ÉTOILE FILANTE", desc = "chance ×3 aux dés",
	  duration = 20, money = 1, power = 1, luck = 3, color = Color3.fromRGB(140, 220, 255) },
	{ key = "fete",    name = "🎉 GRANDE FÊTE", desc = "argent ×3 et tir ×1.5",
	  duration = 12, money = 3, power = 1.5, luck = 1, color = Color3.fromRGB(255, 150, 220) },
	{ key = "tempete", name = "⚡ TEMPÊTE", desc = "argent ×2 et chance ×2",
	  duration = 15, money = 2, power = 1, luck = 2, color = Color3.fromRGB(180, 160, 255) },
	{ key = "canon",   name = "🚀 MODE CANON", desc = "tir ×3",
	  duration = 10, money = 1, power = 3, luck = 1, color = Color3.fromRGB(255, 90, 90) },
}

-------------------------------------------------------------------------------
-- SAISONS : toutes les Config.SeasonCycle secondes, une saison est tirée au
-- hasard entre printemps, été, automne et hiver. Elle dure jusqu'à la suivante
-- et son bonus se cumule avec l'événement en cours (mêmes champs money / power
-- / luck que Config.Events).
-------------------------------------------------------------------------------
Config.SeasonCycle = 1800   -- 30 minutes

Config.Seasons = {
	{ key = "printemps", name = "🌸 PRINTEMPS", desc = "chance ×2",
	  money = 1, power = 1, luck = 2, color = Color3.fromRGB(150, 240, 150) },
	{ key = "ete",       name = "☀️ ÉTÉ", desc = "argent ×2",
	  money = 2, power = 1, luck = 1, color = Color3.fromRGB(255, 220, 90) },
	{ key = "automne",   name = "🍂 AUTOMNE", desc = "tir ×2",
	  money = 1, power = 2, luck = 1, color = Color3.fromRGB(255, 160, 80) },
	{ key = "hiver",     name = "❄️ HIVER", desc = "argent ×1.5 et chance ×1.5",
	  money = 1.5, power = 1, luck = 1.5, color = Color3.fromRGB(150, 220, 255) },
}

-------------------------------------------------------------------------------
-- ÉVÉNEMENTS ADMIN : le coup de sifflet ne les tire JAMAIS au sort. Seul un
-- UserId de Config.Admins peut les lancer, depuis le panneau 🛠 — l'événement
-- s'ouvre alors pour tout le serveur. Mêmes champs que Config.Events.
-- AJOUTER UN ÉVÉNEMENT ADMIN = ajouter une ligne ici, rien d'autre.
-------------------------------------------------------------------------------
Config.AdminEvents = {
	{ key = "pluie",    name = "💵 PLUIE DE BILLETS", desc = "argent ×10",
	  duration = 30, money = 10, power = 1, luck = 1, color = Color3.fromRGB(120, 255, 180) },
	{ key = "supertir", name = "🔥 SUPER TIR", desc = "tir ×5",
	  duration = 30, money = 1, power = 5, luck = 1, color = Color3.fromRGB(255, 120, 60) },
	{ key = "trefle",   name = "🍀 TRÈFLE D'OR", desc = "chance ×5 aux dés",
	  duration = 30, money = 1, power = 1, luck = 5, color = Color3.fromRGB(255, 230, 120) },
	{ key = "carnaval", name = "🎪 CARNAVAL", desc = "argent ×5, tir ×2 et chance ×2",
	  duration = 60, money = 5, power = 2, luck = 2, color = Color3.fromRGB(255, 140, 230) },
	{ key = "folie",    name = "🌈 FOLIE TOTALE", desc = "tout ×10",
	  duration = 20, money = 10, power = 10, luck = 10, color = Color3.fromRGB(200, 140, 255) },
}

-- La ligne de Config.AdminEvents portant cette clé, ou nil si elle n'existe pas.
function Config.adminEvent(key: string)
	for _, ev in Config.AdminEvents do
		if ev.key == key then return ev end
	end
	return nil
end

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

-------------------------------------------------------------------------------
-- GEMMES : deuxième monnaie, gagnée aux QUÊTES (voir Config.Quests).
--
-- Les gemmes ne se farment pas : on les gagne en accomplissant des quêtes, une
-- fois chacune. Elles servent à acheter DIRECTEMENT des niveaux de « valeur
-- joueur » et de « chance » — un raccourci de progression payé en gemmes plutôt
-- qu'en argent. Les coûts sont bas EN NOMBRE parce que les gemmes sont rares.
-------------------------------------------------------------------------------
Config.Gems = {
	valueBaseCost = 2, valueGrowth = 1.15,
	luckBaseCost = 5,  luckGrowth = 1.6,
}

function Config.gemValueCost(level: number): number
	return math.max(1, math.floor(Config.Gems.valueBaseCost * (Config.Gems.valueGrowth ^ math.max(0, level))))
end

function Config.gemLuckCost(level: number): number
	return math.max(1, math.floor(Config.Gems.luckBaseCost * (Config.Gems.luckGrowth ^ math.max(0, level))))
end

-------------------------------------------------------------------------------
-- QUÊTES : des objectifs affichés sur les murs de la zone de tir, avec le nom de
-- ton équipe. Chaque quête accomplie donne des gemmes UNE fois. Plus la quête
-- est difficile, plus la récompense est grosse.
--
-- Une quête se mesure sur une statistique DÉJÀ suivie (argent cumulé,
-- renaissances, joueurs recrutés, puissance) : aucun compteur nouveau à tenir,
-- et le serveur crédite les gemmes dès que le seuil est franchi.
-------------------------------------------------------------------------------
Config.QuestColors = {
	facile    = Color3.fromRGB(90, 220, 120),
	moyen     = Color3.fromRGB(255, 200, 60),
	difficile = Color3.fromRGB(255, 100, 110),
}

-- Les quêtes se RÉACTUALISENT toutes les `QuestCycle` secondes : leurs objectifs
-- se mesurent sur ce que tu gagnes PENDANT LE CYCLE (pas sur ton total à vie), et
-- le compteur repart à zéro à chaque réactualisation. On peut donc les refaire.
Config.QuestCycle = 180   -- 3 minutes

Config.Quests = {
	{ id = "q_earn1",  title = "Gagner 25K $ (ce cycle)",     difficulty = "facile",    metric = "earned", target = 25e3,  gems = 2 },
	{ id = "q_cards1", title = "Recruter 5 joueurs",          difficulty = "facile",    metric = "cards",  target = 5,     gems = 2 },
	{ id = "q_pow0",   title = "Gagner 500 de puissance",     difficulty = "facile",    metric = "power",  target = 500,   gems = 2 },
	{ id = "q_earn2",  title = "Gagner 1M $ (ce cycle)",      difficulty = "moyen",     metric = "earned", target = 1e6,   gems = 5 },
	{ id = "q_pow1",   title = "Gagner 1 500 de puissance",   difficulty = "moyen",     metric = "power",  target = 1500,  gems = 5 },
	{ id = "q_cards2", title = "Recruter 20 joueurs",         difficulty = "moyen",     metric = "cards",  target = 20,    gems = 8 },
	{ id = "q_earn3",  title = "Gagner 50M $ (ce cycle)",     difficulty = "difficile", metric = "earned", target = 50e6,  gems = 12 },
	{ id = "q_pow2",   title = "Gagner 25K de puissance",     difficulty = "difficile", metric = "power",  target = 25e3,  gems = 18 },
}

-- Valeur courante de la statistique mesurée par une quête, lue dans le profil.
function Config.questMetricValue(data, metric: string): number
	if metric == "earned" then return tonumber(data.totalEarned) or 0
	elseif metric == "rebirths" then return tonumber(data.rebirths) or 0
	elseif metric == "cards" then return #(data.cards or {})
	elseif metric == "power" then return tonumber(data.power) or 0
	end
	return 0
end

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
	-- Au-delà de la table des suffixes (1e63), on ne bascule plus en notation
	-- scientifique illisible : on continue par paliers « Diamant ». Chaque tranche
	-- de 1000 en plus = un cran (Diamant 1 = « infini une fois », Diamant 2 = deux
	-- fois, Diamant 3, … et ainsi de suite).
	if v >= 999.995 then
		local tier = 0
		while v >= 999.995 do
			v /= 1000
			tier += 1
		end
		return sign .. string.format("%.2f Diamant %d", v, tier)
	end
	if i == 1 then
		return sign .. tostring(math.floor(v))
	end
	return sign .. string.format("%.2f%s", v, SUFFIXES[i])
end

return Config
