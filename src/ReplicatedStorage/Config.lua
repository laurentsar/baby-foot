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
-- JOUEURS DU BABY-FOOT (les figurines sur les tiges)
-- playerCount : combien de figurines sur le terrain (= nb de cibles).
-- playerValue : argent de base que donne chaque figurine touchée.
-------------------------------------------------------------------------------
Config.PlayerCount = {
	base = 10,
	perLevel = 2,          -- +2 figurines par niveau
	maxLevel = 80,         -- plafond (repoussé par renaissance / pass)
	baseCost = 800,
	costGrowth = 1.6,      -- coût *= 1.6 par niveau
}

Config.PlayerValue = {
	base = 10,
	growth = 1.5,          -- valeur *= 1.5 par niveau
	baseCost = 600,
	costGrowth = 1.55,
}

-------------------------------------------------------------------------------
-- RENAISSANCE (rebirth) : reset argent + upgrades, gagne un multiplicateur permanent.
-- 1 renaissance = x2, 2 = x4, 3 = x6, puis +2 par renaissance (mult = 2 * n).
-------------------------------------------------------------------------------
Config.Rebirth = {
	baseCost = 50000,      -- coût de la 1re renaissance
	costGrowth = 4,        -- coût *= 4 par renaissance
	capacityBonus = 10,    -- +10 au plafond de figurines par renaissance
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
	VIP          = { id = 0, price = 199, label = "VIP",              desc = "x2 argent + capacité de joueurs + étiquette VIP au-dessus du nom" },
	MoneyX2      = { id = 0, price = 149, label = "Argent x2",        desc = "Double tout l'argent gagné (cumulable avec VIP)" },
	RebirthX2    = { id = 0, price = 249, label = "Renaissance x2",   desc = "Double le multiplicateur de renaissance" },
	InfPlayers   = { id = 0, price = 299, label = "Joueurs Infinis",  desc = "Place autant de figurines que tu veux sur le terrain" },
	BallSpeedX2  = { id = 0, price = 129, label = "Vitesse Balle x2", desc = "La balle part deux fois plus vite" },
	BigField     = { id = 0, price = 179, label = "Grand Terrain",    desc = "Le fond du baby-foot est deux fois plus grand (but plus facile)" },
}

-- Capacité bonus de figurines apportée par VIP.
Config.VIPCapacityBonus = 12

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
	-- Distance parcourue ≈ v²/(2*decel) : le terrain ayant été réduit de moitié,
	-- la décélération est doublée pour que marquer demande autant de puissance.
	decel = 180,           -- décélération (studs/s²)
	hitRadius = 5,         -- rayon de collision balle<->figurine
	scoreMultiplier = 3,   -- x3 argent si la balle atteint le fond du baby-foot
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
-- Le terrain ne fait plus que la moitié avant : on tire depuis juste derrière la
-- ligne d'engagement, tout l'espace restant est la zone de jeu (plus de longue
-- approche vide). La ligne est infranchissable pour les personnages, la balle
-- la traverse (elle est simulée en Anchored, sans collision).
Config.Field = {
	origin = Vector3.new(0, 3, 0),   -- centre du terrain
	length = 80,                     -- longueur (axe de tir, +Z = but adverse)
	width = 60,                      -- largeur
	wallHeight = 8,
	rows = 5,                        -- nb de rangées de figurines
	goalDepth = 10,                  -- profondeur du fond/but
	shootLine = -34,                 -- Z du point de tir (ton côté)
	barrierOffset = 6,               -- ligne infranchissable, en avant du point de tir
	barrierHeight = 14,              -- assez haut pour qu'on ne saute pas par-dessus
}

Config.BigFieldMultiplier = 2       -- terrain x2 avec le pass Grand Terrain

-------------------------------------------------------------------------------
-- Helpers de coût / valeur.
-------------------------------------------------------------------------------
function Config.playerCountCost(level: number): number
	return math.floor(Config.PlayerCount.baseCost * (Config.PlayerCount.costGrowth ^ level))
end

function Config.playerCountAt(level: number): number
	return Config.PlayerCount.base + level * Config.PlayerCount.perLevel
end

function Config.playerValueCost(level: number): number
	return math.floor(Config.PlayerValue.baseCost * (Config.PlayerValue.costGrowth ^ level))
end

function Config.playerValueAt(level: number): number
	return math.floor(Config.PlayerValue.base * (Config.PlayerValue.growth ^ level))
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
