--!strict
-- Config partagée client/serveur : upgrades, prix, game passes, géométrie du terrain.
-- Tout est éditable ici : c'est la source de vérité de l'équilibrage du jeu.

local Config = {}

Config.SaveKey = "BabyFootPower_v1"  -- change la clé => reset des sauvegardes

-------------------------------------------------------------------------------
-- HALTÈRES (haltères = vitesse de gain de puissance à l'entraînement)
-- powerGain = puissance gagnée par "rep" d'entraînement.
-------------------------------------------------------------------------------
Config.Dumbbells = {
	{ name = "Haltère Mousse",   powerGain = 1,    cost = 0 },
	{ name = "Haltère Rouille",  powerGain = 3,    cost = 500 },
	{ name = "Haltère Fer",      powerGain = 8,    cost = 4000 },
	{ name = "Haltère Acier",    powerGain = 20,   cost = 25000 },
	{ name = "Haltère Titane",   powerGain = 55,   cost = 150000 },
	{ name = "Haltère Diamant",  powerGain = 150,  cost = 900000 },
	{ name = "Haltère Néon",     powerGain = 420,  cost = 6000000 },
	{ name = "Haltère Galaxie",  powerGain = 1200, cost = 40000000 },
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
-- ÉQUIPE : 4 BASES (les tiges du baby-foot), 11 JOUEURS AU MAXIMUM.
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

Config.MaxSquad = 11        -- plafond dur : on ne place jamais plus de 11 joueurs
Config.StartingSlots = 4    -- emplacements débloqués au départ

-- Équipe de départ : autant de joueurs que d'emplacements, tous dans la pire
-- rareté. Le terrain n'est jamais vide au premier lancement — on voit tout de
-- suite ce qu'on tire, et les dés servent à REMPLACER ces joueurs médiocres.
Config.StarterCards = Config.StartingSlots
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

-- Nombre total d'emplacements du terrain (= somme des bases).
function Config.totalSlots(): number
	local n = 0
	for _, base in Config.Bases do
		n += base.slots
	end
	return n
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
-- DÉS : on paie, on lance, on obtient un joueur.
-- Le coût monte avec la taille de la collection pour que la chasse au Mythique
-- reste un objectif de fin de partie.
-------------------------------------------------------------------------------
Config.Dice = {
	baseCost = 600,
	costGrowth = 1.035,    -- coût *= par carte déjà possédée
	maxCost = 50000000,
	cooldown = 0.6,        -- délai serveur min entre deux lancers
	vipDiscount = 0.7,     -- pass VIP : dés 30 % moins chers
	luckyRerollWeight = 3, -- pass Dés Chanceux : le poids des communs est divisé par 3
}

function Config.diceCost(cardsOwned: number, hasVIP: boolean): number
	local c = Config.Dice.baseCost * (Config.Dice.costGrowth ^ cardsOwned)
	if hasVIP then c *= Config.Dice.vipDiscount end
	return math.floor(math.min(c, Config.Dice.maxCost))
end

-------------------------------------------------------------------------------
-- VALEUR DES JOUEURS (multipliée ensuite par la rareté de la carte touchée).
-------------------------------------------------------------------------------
-- Gains revus à la hausse : avec 11 cibles au maximum (contre des dizaines de
-- figurines avant), la valeur de base devait monter d'autant, sinon un tir
-- réussi rapportait des clopinettes.
Config.PlayerValue = {
	base = 60,
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
Config.Rebirth = {
	baseCost = 50000,      -- coût de la 1re renaissance
	costGrowth = 4,        -- coût *= 4 par renaissance
}

function Config.rebirthMultiplier(rebirths: number, hasRebirthPass: boolean): number
	local m = if rebirths >= 1 then rebirths * 2 else 1
	if hasRebirthPass then m *= 2 end
	return m
end

function Config.rebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.baseCost * (Config.Rebirth.costGrowth ^ rebirths))
end

-------------------------------------------------------------------------------
-- GAME PASSES ROBUX
-- IMPORTANT : remplace les IDs 0 par les vrais IDs créés dans Roblox Creator Hub.
-------------------------------------------------------------------------------
Config.Passes = {
	VIP          = { id = 0, price = 199, label = "VIP",              desc = "x2 argent + dés 30% moins chers + étiquette VIP au-dessus du nom" },
	MoneyX2      = { id = 0, price = 149, label = "Argent x2",        desc = "Double tout l'argent gagné (cumulable avec VIP)" },
	RebirthX2    = { id = 0, price = 249, label = "Renaissance x2",   desc = "Double le multiplicateur de renaissance" },
	LuckyDice    = { id = 0, price = 299, label = "Dés Chanceux",     desc = "Bien moins de communs : les raretés sortent beaucoup plus souvent" },
	BallSpeedX2  = { id = 0, price = 129, label = "Vitesse Balle x2", desc = "La balle part deux fois plus vite" },
	BigField     = { id = 0, price = 179, label = "Grand Terrain",    desc = "Le fond du baby-foot est deux fois plus grand (but plus facile)" },
}

-------------------------------------------------------------------------------
-- ENTRAÎNEMENT
-------------------------------------------------------------------------------
Config.Train = {
	repCooldown = 0.20,    -- délai serveur min entre deux reps (anti-triche)
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
	scoreMultiplier = 4,   -- x4 argent si la balle atteint le fond du baby-foot
	ballLifetime = 6,      -- durée de vie max d'une balle (s)
	cooldown = 0.30,       -- délai min serveur entre deux tirs
	bigFieldScoreFactor = 0.55, -- pass Grand Terrain : but atteint plus tôt
	maxAngle = 55,         -- angle de tir max de part et d'autre de l'axe
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
}

Config.BigFieldMultiplier = 2       -- terrain x2 avec le pass Grand Terrain

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
}

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
Config.Crowd = {
	soundId = "",        -- ex. "rbxassetid://123456789"
	volume = 0.6,
	jumpHeight = 3,      -- hauteur du bond des supporters
	jumpTime = 0.28,
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

-- Formatage abrégé des grands nombres (1.2K, 3.4M, ...).
function Config.abbreviate(n: number): string
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local i = 1
	local v = n
	while v >= 1000 and i < #suffixes do
		v /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(math.floor(v))
	end
	return string.format("%.2f%s", v, suffixes[i])
end

return Config
