--!strict
-- Serveur principal Baby-Foot Power : plots par joueur, entraînement, tir, upgrades,
-- renaissance, game passes Robux, classement mondial.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)   -- crée le dossier Remotes côté serveur

local Server = script.Parent
local FieldBuilder = require(Server.FieldBuilder)
local DataStore = require(Server.DataStore)
local Leaderboard = require(Server.Leaderboard)
local Erasure = require(Server.Erasure)

-- Remotes
local rTrain = Remotes.get("Train")
local rChargeStart = Remotes.get("ChargeStart")
local rShoot = Remotes.get("Shoot")
local rBuy = Remotes.get("BuyUpgrade")
local rRebirth = Remotes.get("Rebirth")
local rBuyPass = Remotes.get("BuyPass")
local rRoll = Remotes.get("RollDice")
local rStats = Remotes.get("StatsUpdate")
local rShotResult = Remotes.get("ShotResult")
local rDiceResult = Remotes.get("DiceResult")
local rCollection = Remotes.get("Collection")
local rToast = Remotes.get("Toast")
local rErase = Remotes.get("EraseData")
local rAutoShoot = Remotes.get("AutoShoot")
local rAutoRoll = Remotes.get("AutoRoll")
local rGift = Remotes.get("Gift")
local rAdmin = Remotes.get("Admin")
local rRoster = Remotes.get("Roster")
local rUsePotion = Remotes.get("UsePotion")
local rTutorial = Remotes.get("Tutorial")
local rChallenge = Remotes.get("Challenge")
local rReleaseSeen = Remotes.get("ReleaseSeen")

-- Tirage des dés : un seul générateur serveur, jamais le client.
local rng = Random.new()

-------------------------------------------------------------------------------
-- État en mémoire par joueur.
-------------------------------------------------------------------------------
type Session = {
	data: any,
	field: any,
	userId: number,
	slot: number,
	passes: { [string]: boolean },
	lastTrain: number,
	lastShot: number,
	lastRoll: number,
	shootingUntil: number,      -- une seule balle en vol par joueur (verrou auto-expirant)
	repopulatePending: boolean, -- replacement des figurines reporté après le tir
	chargeStartAt: number?,     -- horodatage serveur de l'appui sur TIRER
	autoAngle: number?,         -- angle courant du balayage du tir automatique
	lastGift: number,           -- horodatage du dernier don (anti-spam)
	eraseArmedUntil: number,    -- droit à l'oubli : fenêtre de confirmation
	spawnPos: Vector3?,
	props: { Instance }?,      -- décor du plot (entrée, gym) à détruire au départ
	board: SurfaceGui?,        -- panneau de classement du parvis
	-- DÉFI DU LOIN : meilleure distance de la manche en cours (studs).
	challengeBest: number,
	-- Rythme de gain de la session, qui alimente les gains hors ligne.
	sessionStart: number,
	sessionEarned: number,
}

local sessions: { [Player]: Session } = {}
local nextSlot = 0
local freeSlots: { number } = {}   -- plots rendus par les joueurs partis
-- Distance entre deux plots. Doit rester assez grande pour que le terrain le
-- plus agrandi possible par les renaissances (Config.Rebirth.maxFieldGrowth)
-- ne chevauche jamais celui du voisin.
local SLOT_SPACING = 600

-- Tous les panneaux de classement (stade + un parvis par plot) : le compte à
-- rebours du coup de sifflet est écrit sur chacun.
local boards: { SurfaceGui } = {}

-------------------------------------------------------------------------------
-- DÉFI DU LOIN : état partagé par tout le serveur.
--
-- Pendant la fenêtre, TOUS les joueurs tirent sur un terrain vide et le seul
-- score est la distance. L'état vit ici, jamais côté client : un client modifié
-- ne doit pas pouvoir s'ouvrir un défi permanent (ni annoncer une distance).
-------------------------------------------------------------------------------
local challengeActive = false
local challengeEndsAt = 0
local nextChallengeAt = os.clock() + Config.Challenge.interval
local challengeAnnounced = false

-------------------------------------------------------------------------------
-- Game passes.
-------------------------------------------------------------------------------
local function ownsPass(player: Player, passKey: string): boolean
	local pass = Config.Passes[passKey]
	if not pass or pass.id == 0 then return false end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
	end)
	return ok and owns or false
end

local function refreshPasses(session: Session, player: Player)
	for key in Config.Passes do
		session.passes[key] = ownsPass(player, key)
	end
end

-- Coup de sifflet : fenêtre de bonus commune à tout le serveur (affichée sur le
-- grand écran). Gérée ici, jamais côté client.
local boostUntil = 0
local nextWhistle = os.clock() + Config.Match.cycle

local function boostActive(): boolean
	return os.clock() < boostUntil
end

-------------------------------------------------------------------------------
-- EFFETS DE POTION.
--
-- Un effet est une simple date d'expiration en temps réel (os.time) : il
-- continue donc de s'écouler pendant que le joueur est déconnecté. C'est
-- volontaire — une potion de 30 minutes doit durer 30 minutes, pas être mise en
-- pause et reprise trois jours plus tard.
-------------------------------------------------------------------------------
local function effectMult(session: Session, kind: string): number
	local eff = session.data.effects and session.data.effects[kind]
	if typeof(eff) ~= "table" then return 1 end
	local expires = tonumber(eff.expires) or 0
	if os.time() >= expires then return 1 end
	return math.max(1, tonumber(eff.mult) or 1)
end

-- Temps restant d'un effet, pour l'affichage client (0 = pas d'effet).
local function effectRemaining(session: Session, kind: string): number
	local eff = session.data.effects and session.data.effects[kind]
	if typeof(eff) ~= "table" then return 0 end
	return math.max(0, (tonumber(eff.expires) or 0) - os.time())
end

local function moneyMultiplier(session: Session): number
	local rb = Config.rebirthMultiplier(session.data.rebirths, session.passes.RebirthX2 == true)
	local m = rb
	if session.passes.VIP then m *= 2 end
	if session.passes.MoneyX2 then m *= 2 end
	if boostActive() then m *= Config.Match.boostMult end
	-- Monde débloqué : x2 en Galactique, x4 en Radioactif (permanent).
	m *= Config.worldMultiplier(session.data.world)
	-- Potion d'Or.
	m *= effectMult(session, "money")
	return m
end

-- Emplacements de joueurs bonus gagnés par les renaissances (voir
-- Config.extraSlotsFromRebirths) : plus de renaissances, plus de joueurs sur
-- le terrain, donc plus d'argent par tir.
local function extraSlotsFor(session: Session): number
	return Config.extraSlotsFromRebirths(session.data.rebirths)
end

-- Plafond réel d'emplacements : les 11 de base + le bonus de renaissance.
local function maxSlotsFor(session: Session): number
	local extra = extraSlotsFor(session)
	return math.min(Config.MaxSquad + extra, Config.totalSlots(extra))
end

-- Coût des améliorations (haltère, balle, dés, emplacement, valeur joueur) :
-- grimpe fortement avec les renaissances (voir Config.upgradeCostMultiplier).
local function upgradeCostMult(session: Session): number
	return Config.upgradeCostMultiplier(session.data.rebirths)
end

-- Emplacements réellement disponibles : ce que le joueur a débloqué, borné par
-- le plafond du terrain (aucun pass ne le dépasse).
local function unlockedSlots(session: Session): number
	return math.clamp(session.data.slots, 0, maxSlotsFor(session))
end

-- L'équipe posée sur les bases : les meilleures cartes de la collection, dans la
-- limite des emplacements débloqués. Trié par multiplicateur décroissant.
local function squadOf(session: Session)
	local cards = table.clone(session.data.cards)
	table.sort(cards, function(a, b)
		local ma = Config.rarity(a.rarity).mult
		local mb = Config.rarity(b.rarity).mult
		if ma == mb then
			return (a.name or "") < (b.name or "")
		end
		return ma > mb
	end)
	local squad = {}
	for i = 1, math.min(#cards, unlockedSlots(session)) do
		squad[i] = cards[i]
	end
	return squad
end

-------------------------------------------------------------------------------
-- Synchronisation client.
-------------------------------------------------------------------------------
local function buildStats(session: Session)
	local d = session.data
	local dumb = Config.Dumbbells[d.dumbbell]
	local ball = Config.Balls[d.ball]
	local nextDumb = Config.Dumbbells[d.dumbbell + 1]
	local nextBall = Config.Balls[d.ball + 1]
	local slots = unlockedSlots(session)
	local maxSlots = maxSlotsFor(session)
	local costMult = upgradeCostMult(session)
	return {
		money = d.money,
		power = d.power,
		rebirths = d.rebirths,
		totalEarned = d.totalEarned,
		moneyMult = moneyMultiplier(session),
		dumbbell = { name = dumb.name, powerGain = dumb.powerGain, level = d.dumbbell },
		nextDumbbell = nextDumb and { name = nextDumb.name, cost = math.floor(nextDumb.cost * costMult) } or nil,
		ball = { name = ball.name, moneyMult = ball.moneyMult, level = d.ball },
		nextBall = nextBall and { name = nextBall.name, cost = math.floor(nextBall.cost * costMult) } or nil,
		slots = slots,
		maxSlots = maxSlots,
		slotCost = math.floor(Config.slotCost(slots) * costMult),
		squadSize = math.min(#d.cards, slots),
		cardsOwned = #d.cards,
		diceCost = math.floor(Config.diceCost(d.rolls, session.passes.VIP == true) * costMult),
		playerValue = Config.playerValueAt(d.valueLevel),
		playerValueCost = math.floor(Config.playerValueCost(d.valueLevel) * costMult),
		rebirthCost = Config.rebirthCost(d.rebirths),
		nextRebirthMult = Config.rebirthMultiplier(d.rebirths + 1, session.passes.RebirthX2 == true),
		passes = session.passes,
		autoShootUnlocked = Config.autoShootUnlockedBy(d.totalEarned, session.passes.AutoShoot == true),
		autoShootOn = d.autoShoot == true,
		autoRollOwned = d.autoRollOwned == true,
		autoRollOn = d.autoRoll == true,
		autoRollCost = Config.AutoRoll.unlockCost,
		-- CHANCE : niveau, effet courant et prix du niveau suivant.
		luckLevel = d.luck or 0,
		luckMax = Config.Luck.maxLevel,
		luckMult = Config.luckMultiplier(d.luck or 0, session.passes.LuckX20 == true),
		luckCost = (if (d.luck or 0) < Config.Luck.maxLevel
			then math.floor(Config.luckCost(d.luck or 0) * costMult) else nil),
		-- MONDE courant et suivant à débloquer.
		world = { name = Config.world(d.world).name, mult = Config.worldMultiplier(d.world), index = d.world or 1 },
		nextWorld = (function()
			local nw = Config.nextWorld(d.world)
			return nw and { name = nw.name, cost = nw.cost, mult = nw.moneyMult } or nil
		end)(),
		-- SAC À DOS + effets en cours.
		potions = d.potions or {},
		effects = {
			money = { mult = effectMult(session, "money"), left = effectRemaining(session, "money") },
			power = { mult = effectMult(session, "power"), left = effectRemaining(session, "power") },
		},
		tutorialDone = d.tutorialDone == true,
		-- NOUVEAUTÉS : le client compare cette version à celle qu'il a déjà vue et
		-- n'ouvre le pop-up qu'une fois par mise à jour.
		releaseVersion = Config.Release.version,
		releaseSeen = d.releaseSeen or "",
		-- Contrôlé aussi à chaque commande côté serveur : ce champ ne sert qu'à
		-- afficher ou non le panneau, il n'autorise rien par lui-même.
		isAdmin = Config.isAdmin(session.userId),
	}
end

local function pushStats(player: Player)
	local session = sessions[player]
	if not session then return end
	rStats:FireClient(player, buildStats(session))
end

local function updateLeaderstats(session: Session, player: Player)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then return end
	;(ls:FindFirstChild("Argent") :: IntValue).Value = math.clamp(math.floor(session.data.money), 0, 2 ^ 31 - 1)
	;(ls:FindFirstChild("Renaissances") :: IntValue).Value = session.data.rebirths
	;(ls:FindFirstChild("Puissance") :: IntValue).Value = math.clamp(math.floor(session.data.power), 0, 2 ^ 31 - 1)
end

-------------------------------------------------------------------------------
-- Terrain : repose l'équipe sur les bases (11 emplacements de base, plus au
-- fil des renaissances).
-------------------------------------------------------------------------------
-- Repose les figurines. Jamais pendant qu'une balle est en vol : placeSquad fait
-- un ClearAllChildren puis recrée les figurines, ce qui rearmait des cibles
-- neuves sous une balle déjà partie (un lancer de dés en plein tir suffisait à
-- doubler les touches). Dans ce cas on reporte à la fin du tir.
local function repopulate(session: Session)
	if os.clock() < session.shootingUntil then
		session.repopulatePending = true
		return
	end
	session.repopulatePending = false
	FieldBuilder.placeSquad(session.field, squadOf(session), unlockedSlots(session))
	-- Pendant le défi, le terrain doit rester vide : un lancer de dés ou un don
	-- reçu au milieu de la manche ne doit pas faire réapparaître les figurines.
	if challengeActive then
		FieldBuilder.setChallengeMode(session.field, true)
	end
end

-- INDEX : pour chaque nom déjà recruté, la MEILLEURE rareté possédée. Le client
-- connaît le catalogue complet (Config.catalogue(), partagé) — on ne lui envoie
-- donc que ce qu'il possède, pas les 256 entrées à chaque rafraîchissement.
local function indexOf(session: Session): { [string]: string }
	local best: { [string]: string } = {}
	local rank: { [string]: number } = {}
	for i, r in Config.Rarities do
		rank[r.key] = i
	end
	for _, card in session.data.cards do
		local cur = best[card.name]
		if cur == nil or (rank[card.rarity] or 0) > (rank[cur] or 0) then
			best[card.name] = card.rarity
		end
	end
	return best
end

local function pushCollection(player: Player)
	local session = sessions[player]
	if not session then return end
	rCollection:FireClient(player, {
		cards = session.data.cards,
		squad = squadOf(session),
		unlockedSlots = unlockedSlots(session),
		maxSlots = maxSlotsFor(session),
		index = indexOf(session),
	})
end

-------------------------------------------------------------------------------
-- ENTRAÎNEMENT : chaque rep ajoute de la puissance (validé serveur).
-------------------------------------------------------------------------------
rTrain.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then return end
	local now = os.clock()
	if now - session.lastTrain < Config.Train.repCooldown then return end
	session.lastTrain = now
	local gain = Config.Dumbbells[session.data.dumbbell].powerGain
	session.data.power += gain
	updateLeaderstats(session, player)
	pushStats(player)
end)

-------------------------------------------------------------------------------
-- TIR : simulation serveur-autoritaire de la balle sur le baby-foot.
-------------------------------------------------------------------------------
local function nameTagBadge(player: Player)
	-- Étiquette "VIP" au-dessus du nom (pass VIP).
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end
	if head:FindFirstChild("VIPTag") then return end
	local bb = Instance.new("BillboardGui")
	bb.Name = "VIPTag"
	bb.Size = UDim2.fromScale(4, 1)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Parent = head
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = "⭐ VIP"
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255, 215, 40)
	lbl.TextStrokeTransparency = 0
	lbl.Parent = bb
end

-------------------------------------------------------------------------------
-- LIMITEUR DE DÉBIT DES REMOTES.
--
-- Un RemoteEvent sans limite est le vecteur classique de saturation d'un serveur
-- Roblox : un client modifié peut en émettre des milliers par seconde, et chaque
-- appel ici reconstruit une table de stats renvoyée au client. Le tricheur n'y
-- gagne rien, mais il fait ramer le serveur POUR TOUT LE MONDE. Les remotes déjà
-- protégés par leur propre cooldown métier (Train, Shoot, RollDice) ne repassent
-- pas par ici.
-------------------------------------------------------------------------------
local rateBuckets: { [Player]: { [string]: number } } = {}

local function allow(player: Player, key: string, minInterval: number): boolean
	local bucket = rateBuckets[player]
	if not bucket then
		bucket = {}
		rateBuckets[player] = bucket
	end
	local now = os.clock()
	if now - (bucket[key] or -math.huge) < minInterval then
		return false
	end
	bucket[key] = now
	return true
end

-- Début d'appui sur TIRER : le serveur horodate lui-même, c'est ce qui rend la
-- jauge de charge vérifiable (cf. rShoot).
rChargeStart.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then return end
	-- L'horodatage est posé AVANT le limiteur : un appui non enregistré laissait
	-- l'horodatage du précédent en place, et le tir suivant se voyait comparé à
	-- une durée d'appui qui n'avait rien à voir — un tir honnête pouvait alors
	-- perdre son palier. L'affectation ne coûte rien, seul le flux est limité.
	session.chargeStartAt = os.clock()
	if not allow(player, "chargeStart", 0.05) then return end
end)


-- Corps du tir, partagé par le tir manuel et le tir automatique. `auto` = tir
-- généré par le serveur : la charge n'est alors pas à vérifier, elle vient du
-- serveur lui-même (Config.AutoShoot.charge) et non d'un client.
local function performShot(player: Player, angleDeg: number, chargePct: number, auto: boolean)
	local session = sessions[player]
	if not session then return end
	if typeof(angleDeg) ~= "number" or typeof(chargePct) ~= "number" then return end
	-- NaN passe au travers de math.clamp : on l'élimine avant tout calcul.
	if angleDeg ~= angleDeg or chargePct ~= chargePct then return end
	local now = os.clock()
	if now - session.lastShot < Config.Shot.cooldown then return end
	-- Une seule balle en vol par joueur. Sans ce verrou, le cooldown (0,3 s)
	-- étant bien plus court que la durée de vie d'une balle (6 s), un joueur
	-- pouvait avoir ~20 simulations en parallèle : elles se partageaient les
	-- mêmes figurines et comptaient plusieurs fois les mêmes touches.
	-- Verrou horodate plutot que booleen : si la simulation s'interrompt sur une
	-- erreur, le verrou expire tout seul au lieu d'empecher le joueur de tirer
	-- pour le reste de la partie.
	if now < session.shootingUntil then return end
	-- Le défi est une manche à part : terrain vide, pas d'argent, un seul score
	-- (la distance). On fige l'état au départ du tir, pour qu'une balle partie
	-- pendant le défi finisse en balle de défi même si la fenêtre se ferme.
	local challenge = challengeActive
	session.lastShot = now
	session.shootingUntil = now + (if challenge then Config.Challenge.maxFlight else Config.Shot.ballLifetime) + 1

	local field = session.field
	local S = Config.Shot
	-- L'angle vient de l'orientation caméra du client ; le serveur reste maître
	-- des bornes (un client modifié ne peut pas tirer à 180°).
	angleDeg = math.clamp(angleDeg, -S.maxAngle, S.maxAngle)
	chargePct = math.clamp(chargePct, 0, 1)

	-- La jauge de charge est un mini-jeu d'adresse : sans contrôle, un client
	-- modifié annonce 1.0 à chaque tir et décroche le palier maximal en
	-- permanence. Le serveur recalcule la charge attendue depuis la durée
	-- d'appui qu'il a lui-même horodatée, et refuse un écart trop grand.
	if auto then
		-- Rien à vérifier : la charge vient du serveur. On purge quand même un
		-- éventuel appui en cours, sinon le tir manuel suivant serait comparé à
		-- un horodatage périmé et verrait sa charge écrasée.
		session.chargeStartAt = nil
	elseif session.chargeStartAt then
		local expected = Config.chargeAt(now - session.chargeStartAt)
		if math.abs(chargePct - expected) > Config.ChargeTolerance then
			chargePct = expected
		end
		session.chargeStartAt = nil
	else
		-- Tir sans appui préalable : client non conforme, palier haut refusé.
		chargePct = math.min(chargePct, Config.ChargeNoPressCap)
	end

	-- Vitesse = base + puissance, modulée par le palier de charge, x2 si pass vitesse.
	local tier = Config.chargeTier(chargePct)
	local speed = (S.baseSpeed + session.data.power * S.powerToSpeed) * tier.speedMult
	if session.passes.BallSpeedX2 then speed *= 2 end
	speed *= effectMult(session, "power")   -- potion de puissance
	-- Pendant le défi, pas de plafond de vitesse : c'est une épreuve de distance,
	-- un plafond ferait terminer tous les gros joueurs à égalité. Le vol reste
	-- borné dans le temps par la décélération calculée plus bas.
	if not challenge then
		speed = math.min(speed, S.maxSpeed)
	end

	local rad = math.rad(angleDeg)
	local dirX, dirZ = math.sin(rad), math.cos(rad)

	-- Balle visible.
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(3, 3, 3)
	ball.Color = Color3.fromRGB(255, 255, 255)
	ball.Material = Enum.Material.Neon
	ball.Anchored = true
	ball.CanCollide = false
	ball.CastShadow = false
	ball.Position = field.shootPos
	ball.Parent = field.root

	-----------------------------------------------------------------------------
	-- TIR DE DÉFI : baby-foot infini. Pas de figurines à toucher, pas de but, pas
	-- de rebond sur les murs — la balle part tout droit et on mesure jusqu'où
	-- elle roule. Aucun argent : le défi rapporte des potions, pas des revenus.
	--
	-- La décélération est relevée pour que même un tir énorme s'arrête dans la
	-- fenêtre de vol (sinon la distance serait tronquée par le temps, et deux
	-- puissances différentes donneraient le même score). Elle reste la même pour
	-- toute la trajectoire, donc la distance croît strictement avec la puissance.
	-----------------------------------------------------------------------------
	if challenge then
		local startPos = field.shootPos
		local p = startPos
		local decel = math.max(S.decel, speed / Config.Challenge.maxFlight)
		local flightTime = 0
		while flightTime < Config.Challenge.maxFlight and speed > 1 do
			local dt = RunService.Heartbeat:Wait()
			flightTime += dt
			speed = math.max(0, speed - decel * dt)
			p += Vector3.new(dirX * speed * dt, 0, dirZ * speed * dt)
			ball.Position = Vector3.new(p.X, startPos.Y, p.Z)
		end
		local distance = (p - startPos).Magnitude
		task.delay(0.15, function() ball:Destroy() end)
		session.shootingUntil = 0   -- rien à relever : le terrain est déjà vide
		if sessions[player] ~= session then return end
		local record = distance > session.challengeBest
		if record then session.challengeBest = distance end
		rShotResult:FireClient(player, {
			challenge = true,
			distance = math.floor(distance),
			bestDistance = math.floor(session.challengeBest),
			record = record,
			tier = tier.label,
			hits = 0, money = 0, scored = false,
		})
		return
	end

	-- Le but est atteint au fond ET entre les poteaux. Le pass Grand Terrain
	-- élargit le but (voir FieldBuilder.build), il ne rapproche plus le seuil.
	local scoreZ = field.goalZ - Config.Field.goalDepth / 2

	local pos = field.shootPos
	local halfW = field.width / 2 - 2
	-- Liste figée au départ du tir. GetChildren() alloue un tableau neuf à chaque
	-- appel : le faire à chaque Heartbeat, pour chaque balle en vol, remplissait
	-- le GC pour rien. Les figurines ne bougent pas pendant le vol — repopulate
	-- est reporté tant que le verrou de tir tient.
	local targets: { BasePart } = {}
	for _, fig in field.figuresFolder:GetChildren() do
		if fig:IsA("BasePart") and fig.Name == "Figure" and not fig:GetAttribute("Down") then
			table.insert(targets, fig)
		end
	end

	local radiusSq = S.hitRadius * S.hitRadius
	local hitSet: { [Instance]: boolean } = {}
	local hits = 0
	local hitValue = 0   -- somme des multiplicateurs de rareté touchés
	local best = nil     -- meilleure rareté touchée, pour le retour client
	local scored = false
	local elapsed = 0

	-- PAS DE SIMULATION SOUS-DÉCOUPÉ.
	--
	-- Une balle rapide avance de bien plus que son rayon de collision en une
	-- frame : à 1400 studs/s et 60 fps, c'est 23 studs par pas pour une fenêtre
	-- de contact de 12 — la balle traversait les figurines sans les voir, et
	-- MONTER EN PUISSANCE FAISAIT BAISSER LES GAINS. Pire sur téléphone (30 fps),
	-- où le seuil tombe à moitié moins de vitesse.
	--
	-- On découpe donc chaque frame en pas d'au plus un rayon de collision. Le
	-- coût est proportionnel à la vitesse, pas au nombre de figurines : c'est le
	-- test de distance qui est refait, pas la liste des cibles.
	local finished = false
	while elapsed < S.ballLifetime and speed > 1 and not finished do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt

		local sub = math.clamp(math.ceil(speed * dt / S.hitRadius), 1, 64)
		local sdt = dt / sub

		for _ = 1, sub do
			speed = math.max(0, speed - S.decel * sdt)
			pos = pos + Vector3.new(dirX * speed * sdt, 0, dirZ * speed * sdt)

			-- Rebond sur les murs latéraux.
			local dx = pos.X - field.origin.X
			if math.abs(dx) > halfW then
				dirX = -dirX
				pos = Vector3.new(field.origin.X + math.sign(dx) * halfW, pos.Y, pos.Z)
			end

			-- Collisions joueurs. `targets` ne contient que les "Figure" debout :
			-- les socles d'emplacement vide ne comptent pas, sinon un terrain à
			-- moitié vide rapporterait autant qu'une équipe complète.
			local bx, bz = pos.X, pos.Z
			for _, fig in targets do
				if not hitSet[fig] and fig.Parent then
					local fp = fig.Position
					-- Distance au carré dans le plan : évite une racine carrée par
					-- figurine et par pas.
					local dxf, dzf = fp.X - bx, fp.Z - bz
					if dxf * dxf + dzf * dzf < radiusSq then
						hitSet[fig] = true
						hits += 1
						local mult = tonumber(fig:GetAttribute("Mult")) or 1
						hitValue += mult
						local rarete = fig:GetAttribute("Rarete")
						if typeof(rarete) == "string" and (best == nil or mult > best.mult) then
							best = { mult = mult, name = rarete }
						end
						-- Masquée immédiatement : un task.delay la laissait une
						-- frame de plus dans la liste, le temps qu'une autre balle
						-- la compte elle aussi.
						FieldBuilder.knockDown(fig)
					end
				end
			end

			-- But atteint ? Il faut arriver au fond ET entre les poteaux.
			if pos.Z >= scoreZ then
				if math.abs(pos.X - field.origin.X) <= field.goalHalfWidth then
					scored = true
				end
				-- Dans les deux cas la balle est arrivée au fond : elle s'arrête.
				finished = true
				break
			end

			if speed <= 1 then break end
		end

		-- Une seule écriture de position par frame : les pas intermédiaires ne
		-- servent qu'à la détection, les répliquer n'apporterait rien à l'image.
		ball.Position = Vector3.new(pos.X, field.shootPos.Y, pos.Z)
	end

	-- Effet de but : le fond s'allume et le public bondit en ola.
	if scored then
		field.goalPart.Color = Color3.fromRGB(120, 255, 140)
		task.delay(0.4, function()
			field.goalPart.Color = Color3.fromRGB(80, 220, 255)
		end)
		FieldBuilder.cheer(field)
	end

	task.delay(0.15, function() ball:Destroy() end)

	-- Le joueur peut être parti pendant les 6 s de vol : sa session est alors
	-- déjà sauvegardée et son terrain détruit. On ne crédite pas un fantôme.
	if sessions[player] ~= session then
		session.shootingUntil = 0
		return
	end

	-- Calcul du gain : chaque joueur touché rapporte selon SA rareté, d'où
	-- hitValue (somme des multiplicateurs) plutôt qu'un simple nombre de touches.
	local perHit = Config.playerValueAt(session.data.valueLevel)
		* Config.Balls[session.data.ball].moneyMult
	-- Un but qui ne touche personne vaut au moins une figurine commune, sinon le
	-- tir le plus precis du jeu rapporte 0.
	local value = scored and math.max(hitValue, S.goalBaseValue) or hitValue
	local money = value * perHit * moneyMultiplier(session)
	if scored then
		money *= S.scoreMultiplier  -- x3 si la balle atteint le fond
	end
	money = math.floor(money)

	session.data.money += money
	session.data.totalEarned += money
	-- Alimente le rythme de gain de la session, d'où sortent les gains hors ligne.
	session.sessionEarned += money
	updateLeaderstats(session, player)
	pushStats(player)

	rShotResult:FireClient(player, {
		hits = hits,
		money = money,
		scored = scored,
		tier = tier.label,
		best = best and best.name or nil,
	})

	-- Respawn des cibles après le tir. Le verrou n'est relâché qu'une fois les
	-- figurines reposées : sinon le tir suivant partait sur un terrain vide.
	task.delay(Config.Shot.respawnDelay, function()
		session.shootingUntil = 0
		if sessions[player] ~= session then return end
		if session.repopulatePending then
			-- L'équipe a changé pendant le vol (dés, renaissance, emplacement
			-- acheté) : il faut vraiment reconstruire. Le drapeau était posé mais
			-- jamais relu, la reconstruction différée était donc perdue.
			repopulate(session)
		else
			-- Composition inchangée : on relève les figurines couchées au lieu de
			-- détruire et recréer tout le plateau.
			FieldBuilder.standUp(session.field)
		end
	end)

	-- Soumet au classement (throttlé côté Leaderboard : ~1 écriture/min/joueur).
	Leaderboard.submit(player.UserId, session.data.totalEarned)
end

rShoot.OnServerEvent:Connect(function(player, angleDeg, chargePct)
	performShot(player, angleDeg, chargePct, false)
end)

-------------------------------------------------------------------------------
-- TIR AUTOMATIQUE.
--
-- Le client n'envoie qu'un interrupteur : c'est le serveur qui tire, par le même
-- chemin que le tir manuel (performShot), donc avec les mêmes verrous — une
-- seule balle en vol, cooldown, relevage des figurines. Aucun raccourci : le tir
-- auto ne va pas plus vite que ce que le jeu autorise à la main.
-------------------------------------------------------------------------------
local function autoShootUnlocked(session: Session): boolean
	return Config.autoShootUnlockedBy(session.data.totalEarned, session.passes.AutoShoot == true)
end

rAutoShoot.OnServerEvent:Connect(function(player, on)
	local session = sessions[player]
	if not session then return end
	if typeof(on) ~= "boolean" then return end
	-- Interrupteur : chaque appel reconstruit et renvoie la table de stats, il ne
	-- doit donc pas pouvoir être appelé en boucle par un client modifié.
	if not allow(player, "autoShoot", 0.25) then return end
	if on and not autoShootUnlocked(session) then
		rToast:FireClient(player, "Tir automatique verrouillé (passe Robux, ou "
			.. Config.abbreviate(Config.AutoShoot.freeUnlockEarned) .. " $ gagnés)")
		return
	end
	session.data.autoShoot = on
	pushStats(player)
end)

task.spawn(function()
	local A = Config.AutoShoot
	local due: { Player } = {}
	while true do
		task.wait(A.interval)
		-- Instantané de la liste avant d'agir : performShot suit la balle pendant
		-- plusieurs secondes, et un joueur qui se déconnecte pendant ce temps
		-- retire son entrée de `sessions` — modifier la table qu'on parcourt
		-- casse l'itération.
		table.clear(due)
		for player, session in sessions do
			if session.data.autoShoot and session.field and autoShootUnlocked(session) then
				table.insert(due, player)
			end
		end
		for _, player in due do
			local session = sessions[player]
			if session then
				-- Balayage : l'angle avance d'un pas à chaque tir et repart de
				-- l'autre bord, pour couvrir toute la largeur du terrain plutôt
				-- que de retaper la même colonne de figurines.
				local maxA = Config.Shot.maxAngle
				local a = (session.autoAngle or -maxA) + A.sweepStep
				if a > maxA then a = -maxA end
				session.autoAngle = a
				-- En coroutine : performShot suit la balle jusqu'à l'impact, un
				-- appel direct ferait tirer les joueurs chacun leur tour.
				task.spawn(performShot, player, a, A.charge, true)
			end
		end
	end
end)

-------------------------------------------------------------------------------
-- DONS ENTRE JOUEURS.
--
-- Transfert strict : ce qui est retiré à l'un est ajouté à l'autre, dans la même
-- opération. Rien n'est créé. Le client n'envoie qu'une intention — le serveur
-- relit tout depuis SA copie des données (montant disponible, carte réellement
-- possédée), sinon un client modifié offrirait un argent qu'il n'a pas.
-------------------------------------------------------------------------------
local function giftTarget(player: Player, payload): (Player?, Session?)
	if typeof(payload.to) ~= "number" then return nil, nil end
	local target = Players:GetPlayerByUserId(payload.to)
	if not target or target == player then return nil, nil end
	return target, sessions[target]
end

rGift.OnServerEvent:Connect(function(player, payload)
	local session = sessions[player]
	if not session then return end
	if typeof(payload) ~= "table" then return end
	-- Le cooldown métier (Config.Gift.cooldown) n'est posé qu'après un don RÉUSSI :
	-- sans ce limiteur, un client modifié spammait des dons invalides et chaque
	-- appel renvoyait un message à deux joueurs.
	if not allow(player, "gift", 0.5) then return end

	local now = os.clock()
	if now - session.lastGift < Config.Gift.cooldown then
		rToast:FireClient(player, "Un don toutes les " .. Config.Gift.cooldown .. " s")
		return
	end

	local target, tSession = giftTarget(player, payload)
	if not target or not tSession then
		rToast:FireClient(player, "Ce joueur n'est plus sur le serveur")
		return
	end

	if payload.kind == "money" then
		local amount = payload.amount
		if typeof(amount) ~= "number" or amount ~= amount or amount == math.huge then return end
		amount = math.floor(amount)
		local G = Config.Gift
		local maxGift = math.floor(session.data.money * G.maxShare)
		if amount < G.minMoney or maxGift < G.minMoney then
			rToast:FireClient(player, "Montant trop faible")
			return
		end
		if amount > maxGift then
			-- Plafond à une fraction de sa fortune : on n'annule pas le don, on
			-- le rabote, sinon un doigt qui glisse sur le clavier ne donne rien.
			amount = maxGift
		end
		session.data.money -= amount
		tSession.data.money += amount
		session.lastGift = now

		updateLeaderstats(session, player)
		updateLeaderstats(tSession, target)
		pushStats(player)
		pushStats(target)
		rToast:FireClient(player, "Offert à " .. target.DisplayName .. " : " .. Config.abbreviate(amount) .. " $")
		rToast:FireClient(target, player.DisplayName .. " t'offre " .. Config.abbreviate(amount) .. " $ !")

	elseif payload.kind == "card" then
		local i = payload.cardIndex
		if typeof(i) ~= "number" then return end
		i = math.floor(i)
		local card = session.data.cards[i]
		if not card then
			rToast:FireClient(player, "Ce joueur n'est plus dans ta collection")
			return
		end
		-- Une carte, pas une copie : elle quitte vraiment la collection du
		-- donneur. Un don qui laisserait l'original en place serait une machine à
		-- dupliquer les Divins.
		table.remove(session.data.cards, i)
		table.insert(tSession.data.cards, { name = card.name, rarity = card.rarity })
		session.lastGift = now

		local r = Config.rarity(card.rarity)
		repopulate(session)
		repopulate(tSession)
		pushCollection(player)
		pushCollection(target)
		pushStats(player)
		pushStats(target)
		rToast:FireClient(player, "Offert à " .. target.DisplayName .. " : " .. card.name .. " (" .. r.name .. ")")
		rToast:FireClient(target, player.DisplayName .. " t'offre " .. card.name .. " (" .. r.name .. ") !")
	end
end)

-- Liste des joueurs connectés, pour choisir un destinataire. Rediffusée à chaque
-- arrivée et chaque départ : une liste périmée ferait échouer le don au moment
-- où le joueur clique.
local function pushRoster()
	local list = {}
	for _, p in Players:GetPlayers() do
		table.insert(list, { userId = p.UserId, name = p.DisplayName })
	end
	rRoster:FireAllClients(list)
end

-------------------------------------------------------------------------------
-- COMMANDES ADMIN.
--
-- Réservées aux UserId de Config.Admins, contrôlés ICI : le champ `isAdmin`
-- envoyé au client ne sert qu'à afficher le panneau, il n'autorise rien.
-------------------------------------------------------------------------------
rAdmin.OnServerEvent:Connect(function(player, payload)
	if not Config.isAdmin(player.UserId) then return end
	local session = sessions[player]
	if not session then return end
	if typeof(payload) ~= "table" then return end

	if payload.kind == "money" then
		local amount = payload.amount
		if typeof(amount) ~= "number" or amount ~= amount or amount == math.huge then return end
		session.data.money += math.floor(amount)
		session.data.totalEarned += math.max(0, math.floor(amount))
		updateLeaderstats(session, player)
		pushStats(player)
		rToast:FireClient(player, "[admin] +" .. Config.abbreviate(amount) .. " $")

	elseif payload.kind == "power" then
		local amount = payload.amount
		if typeof(amount) ~= "number" or amount ~= amount or amount == math.huge then return end
		session.data.power += math.floor(amount)
		updateLeaderstats(session, player)
		pushStats(player)
		rToast:FireClient(player, "[admin] +" .. Config.abbreviate(amount) .. " puissance")

	elseif payload.kind == "card" then
		local rarity = payload.rarity
		if typeof(rarity) ~= "string" or Config.rarity(rarity).key ~= rarity then return end
		local count = math.clamp(math.floor(tonumber(payload.count) or 1), 1, 50)
		local name = if typeof(payload.name) == "string" and payload.name ~= "" then payload.name else nil
		for _ = 1, count do
			table.insert(session.data.cards, {
				name = name or Config.cardNameFor(rarity, rng),
				rarity = rarity,
			})
		end
		repopulate(session)
		pushCollection(player)
		pushStats(player)
		rToast:FireClient(player, "[admin] +" .. count .. " " .. Config.rarity(rarity).name)
	end
end)

-------------------------------------------------------------------------------
-- UPGRADES.
-------------------------------------------------------------------------------
rBuy.OnServerEvent:Connect(function(player, kind)
	local session = sessions[player]
	if not session then return end
	if typeof(kind) ~= "string" then return end
	if not allow(player, "buy", 0.15) then return end
	local d = session.data
	-- Grimpe fortement à chaque renaissance : le terrain et l'équipe s'agrandissent,
	-- mais tout coûte bien plus cher (voir Config.upgradeCostMultiplier).
	local costMult = upgradeCostMult(session)

	if kind == "dumbbell" then
		local nxt = Config.Dumbbells[d.dumbbell + 1]
		if nxt then
			local cost = math.floor(nxt.cost * costMult)
			if d.money >= cost then
				d.money -= cost
				d.dumbbell += 1
			end
		end
	elseif kind == "ball" then
		local nxt = Config.Balls[d.ball + 1]
		if nxt then
			local cost = math.floor(nxt.cost * costMult)
			if d.money >= cost then
				d.money -= cost
				d.ball += 1
			end
		end
	elseif kind == "slot" then
		local slots = unlockedSlots(session)
		local maxSlots = maxSlotsFor(session)
		if slots >= maxSlots then
			rToast:FireClient(player, string.format("Équipe au complet : %d joueurs, c'est le maximum !", maxSlots))
		else
			local cost = math.floor(Config.slotCost(slots) * costMult)
			if d.money >= cost then
				d.money -= cost
				d.slots = slots + 1
				repopulate(session)
				pushCollection(player)
			end
		end
	elseif kind == "value" then
		local cost = math.floor(Config.playerValueCost(d.valueLevel) * costMult)
		if d.money >= cost then
			d.money -= cost
			d.valueLevel += 1
		end
	elseif kind == "luck" then
		-- CHANCE : plafonnée à Config.Luck.maxLevel (x5). Le x20 ne s'obtient que
		-- par la passe Robux, jamais par accumulation de niveaux.
		local level = d.luck or 0
		if level >= Config.Luck.maxLevel then
			rToast:FireClient(player, string.format("Chance au maximum (x%s) — le x20 est une passe Robux.",
				Config.luckFromLevel(Config.Luck.maxLevel)))
		else
			local cost = math.floor(Config.luckCost(level) * costMult)
			if d.money >= cost then
				d.money -= cost
				d.luck = level + 1
				rToast:FireClient(player, string.format("🍀 Chance x%s !", Config.luckFromLevel(d.luck)))
			end
		end
	elseif kind == "world" then
		-- MONDE SUIVANT : achat définitif, gardé à la renaissance. Le terrain est
		-- reconstruit tout de suite — un monde qu'on ne verrait qu'à la prochaine
		-- connexion ne ressemblerait pas à un achat.
		local nw = Config.nextWorld(d.world)
		if not nw then
			rToast:FireClient(player, "Tu as déjà débloqué tous les mondes.")
		elseif d.money < nw.cost then
			rToast:FireClient(player, "Monde " .. nw.name .. " : il faut " .. Config.abbreviate(nw.cost) .. " $")
		else
			d.money -= nw.cost
			d.world = (d.world or 1) + 1
			if session.field and session.field.root then
				session.field.root:Destroy()
			end
			local origin = Config.Field.origin + Vector3.new(session.slot * SLOT_SPACING, 0, 0)
			session.field = FieldBuilder.build(session.passes.BigField == true, origin,
				Config.fieldSizeMultiplier(d.rebirths), extraSlotsFor(session), d.world)
			-- La reconstruction repart d'un terrain nu : on repose l'équipe tout de
			-- suite, sans attendre le prochain tir.
			session.repopulatePending = false
			repopulate(session)
			if challengeActive then FieldBuilder.setChallengeMode(session.field, true) end
			rToast:FireClient(player, "🌍 Monde " .. nw.name .. " débloqué — argent x"
				.. nw.moneyMult .. " en permanence !")
		end
	end

	updateLeaderstats(session, player)
	pushStats(player)
end)

-------------------------------------------------------------------------------
-- DÉS : on paie, le serveur tire la rareté, la carte entre dans la collection.
-- Le client n'envoie rien d'autre que « je lance » : ni le résultat, ni le coût.
-------------------------------------------------------------------------------
local MAX_CARDS = 200  -- garde-fou : une collection illimitée ferait grossir la
                       -- sauvegarde sans fin (limite DataStore par clé).

-- Corps du tirage, partagé par le bouton RECRUTER et par le roulement
-- automatique. `silent` = tirage auto : on ne prévient pas d'un manque d'argent
-- à chaque tentative, sinon l'écran serait noyé de messages.
-- Retourne true si un lancer a bien été payé et effectué.
local function performRoll(player: Player, silent: boolean): boolean
	local session = sessions[player]
	if not session then return false end
	local now = os.clock()
	if now - session.lastRoll < Config.Dice.cooldown then return false end
	session.lastRoll = now

	local d = session.data
	local cost = math.floor(Config.diceCost(d.rolls, session.passes.VIP == true) * upgradeCostMult(session))
	if d.money < cost then
		if not silent then
			rToast:FireClient(player, "Pas assez d'argent pour lancer les dés ("
				.. Config.abbreviate(cost) .. " $)")
		end
		return false
	end
	d.money -= cost
	d.rolls += 1

	-- Chance = amélioration en jeu (x5 max) x passe Chance x20, plafonnée.
	local luck = Config.luckMultiplier(d.luck or 0, session.passes.LuckX20 == true)
	local key = Config.rollRarity(rng, session.passes.LuckyDice == true, luck)
	local card = { name = Config.cardNameFor(key, rng), rarity = key }
	table.insert(d.cards, card)

	-- Collection pleine : on jette la carte la plus faible, jamais la nouvelle.
	if #d.cards > MAX_CARDS then
		local worstIdx, worstMult = 1, math.huge
		for i, c in d.cards do
			local m = Config.rarity(c.rarity).mult
			if m < worstMult then
				worstIdx, worstMult = i, m
			end
		end
		table.remove(d.cards, worstIdx)
	end

	repopulate(session)
	updateLeaderstats(session, player)
	pushStats(player)
	pushCollection(player)
	rDiceResult:FireClient(player, { card = card, cost = cost })
	return true
end

rRoll.OnServerEvent:Connect(function(player)
	performRoll(player, false)
end)

-------------------------------------------------------------------------------
-- ROULEMENT AUTOMATIQUE : le bouton RECRUTER relance tout seul.
--
-- Déblocage payant une fois pour toutes (Config.AutoRoll.unlockCost), puis
-- simple interrupteur. Comme pour le tir automatique, c'est le serveur qui
-- lance, par le même chemin que le bouton — même cooldown, même prix, même
-- tirage. Aucun raccourci : ça évite d'appuyer, pas de payer.
-------------------------------------------------------------------------------
rAutoRoll.OnServerEvent:Connect(function(player, on)
	local session = sessions[player]
	if not session then return end
	if typeof(on) ~= "boolean" then return end
	if not allow(player, "autoRoll", 0.25) then return end
	local d = session.data

	if on and not d.autoRollOwned then
		-- Premier allumage : c'est l'achat. Le client ne dit jamais « j'ai payé »,
		-- c'est le serveur qui débite depuis sa propre copie de l'argent.
		local cost = Config.AutoRoll.unlockCost
		if d.money < cost then
			rToast:FireClient(player, "Roulement auto : il manque de l'argent ("
				.. Config.abbreviate(cost) .. " $)")
			return
		end
		d.money -= cost
		d.autoRollOwned = true
		updateLeaderstats(session, player)
		rToast:FireClient(player, "🔁 Roulement automatique débloqué !")
	end

	d.autoRoll = on
	pushStats(player)
end)

task.spawn(function()
	local due: { Player } = {}
	while true do
		task.wait(Config.AutoRoll.interval)
		-- Instantané avant d'agir : performRoll republie l'état et un joueur peut
		-- se déconnecter entre-temps, ce qui retire son entrée de `sessions`.
		table.clear(due)
		for player, session in sessions do
			if session.data.autoRoll and session.data.autoRollOwned then
				table.insert(due, player)
			end
		end
		for _, player in due do
			if sessions[player] then performRoll(player, true) end
		end
	end
end)

-------------------------------------------------------------------------------
-- SAC À DOS : les potions gagnées au défi du loin.
--
-- Une potion ne s'applique jamais toute seule : elle attend dans le sac que le
-- joueur choisisse son moment. C'est tout l'intérêt d'un x3 argent de 30 min —
-- le boire juste avant une grosse séance, pas au milieu d'un défi.
-------------------------------------------------------------------------------
local function grantPotion(session: Session, key: string, count: number?)
	if not Config.potion(key) then return end
	local d = session.data
	d.potions = d.potions or {}
	d.potions[key] = (tonumber(d.potions[key]) or 0) + (count or 1)
end

rUsePotion.OnServerEvent:Connect(function(player, key)
	local session = sessions[player]
	if not session then return end
	if typeof(key) ~= "string" then return end
	if not allow(player, "potion", 0.3) then return end

	local potion = Config.potion(key)
	if not potion then return end

	local d = session.data
	d.potions = d.potions or {}
	local have = tonumber(d.potions[key]) or 0
	if have < 1 then
		rToast:FireClient(player, "Tu n'as pas cette potion.")
		return
	end
	d.potions[key] = if have - 1 > 0 then have - 1 else nil

	-- Deux potions du même type n'empilent PAS leurs multiplicateurs (deux x3
	-- feraient un x9) : on garde le meilleur des deux et on additionne la durée.
	d.effects = d.effects or {}
	local cur = d.effects[potion.kind]
	local now = os.time()
	local left = if typeof(cur) == "table" then math.max(0, (tonumber(cur.expires) or 0) - now) else 0
	local curMult = if left > 0 and typeof(cur) == "table" then (tonumber(cur.mult) or 1) else 1
	d.effects[potion.kind] = {
		mult = math.max(curMult, potion.mult),
		expires = now + left + potion.duration,
	}

	pushStats(player)
	rToast:FireClient(player, "🧪 " .. potion.name .. " — " .. potion.desc)
end)

-------------------------------------------------------------------------------
-- TUTORIEL : le client signale qu'il a été lu jusqu'au bout. Rien d'autre n'en
-- dépend, mais il est stocké côté serveur pour ne pas revenir à chaque appareil.
-------------------------------------------------------------------------------
rTutorial.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then return end
	if not allow(player, "tutorial", 1) then return end
	session.data.tutorialDone = true
	pushStats(player)
end)

-------------------------------------------------------------------------------
-- NOUVEAUTÉS LUES : on enregistre la version annoncée par le SERVEUR, jamais
-- celle envoyée par le client — sinon un client modifié pourrait marquer comme
-- lue une version qui n'existe pas et ne plus jamais voir d'annonce.
-------------------------------------------------------------------------------
rReleaseSeen.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then return end
	if not allow(player, "release", 1) then return end
	session.data.releaseSeen = Config.Release.version
	pushStats(player)
end)

-------------------------------------------------------------------------------
-- RENAISSANCE : reset argent + upgrades, +1 renaissance (mult permanent).
-------------------------------------------------------------------------------
rRebirth.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then return end
	if not allow(player, "rebirth", 0.5) then return end
	local d = session.data
	local cost = Config.rebirthCost(d.rebirths)
	if d.money < cost then
		rToast:FireClient(player, "Pas assez d'argent pour renaître (" .. Config.abbreviate(cost) .. " $)")
		return
	end
	d.rebirths += 1
	d.money = 0
	d.power = 0
	d.dumbbell = 1
	d.ball = 1
	d.valueLevel = 0

	-- Le terrain grandit et l'équipe s'agrandit à chaque renaissance : plus de
	-- joueurs à toucher (donc plus d'argent par tir), mais un but plus loin (il
	-- faut plus de puissance) et des coûts d'amélioration bien plus élevés (voir
	-- Config.upgradeCostMultiplier, appliqué partout ailleurs dans ce fichier).
	-- L'équipe reste complète : les nouveaux emplacements sont comblés par des
	-- Communs, comme au tout premier chargement (cf. onPlayerAdded).
	local newMaxSlots = maxSlotsFor(session)
	d.slots = newMaxSlots
	while #d.cards < newMaxSlots do
		table.insert(d.cards, { name = Config.randomPlayerName(rng), rarity = Config.StarterRarity })
	end

	if session.field and session.field.root then
		session.field.root:Destroy()
	end
	local origin = Config.Field.origin + Vector3.new(session.slot * SLOT_SPACING, 0, 0)
	-- La chance (d.luck) et le monde (d.world) ne sont PAS repris par la
	-- renaissance : la chance sert la collection, qui survit elle aussi, et un
	-- monde a été payé une fois pour toutes.
	session.field = FieldBuilder.build(session.passes.BigField == true, origin,
		Config.fieldSizeMultiplier(d.rebirths), extraSlotsFor(session), d.world)

	repopulate(session)
	if challengeActive then FieldBuilder.setChallengeMode(session.field, true) end
	updateLeaderstats(session, player)
	pushStats(player)
	pushCollection(player)
	rToast:FireClient(player, "🔄 Renaissance ! Multiplicateur permanent x"
		.. Config.rebirthMultiplier(d.rebirths, session.passes.RebirthX2 == true)
		.. " — terrain agrandi, équipe élargie à " .. newMaxSlots
		.. " joueurs, ta collection est gardée. Tout coûte plus cher maintenant !")
end)

-------------------------------------------------------------------------------
-- GAME PASSES : ouvre la boutique Robux.
-------------------------------------------------------------------------------
rBuyPass.OnServerEvent:Connect(function(player, passKey)
	if typeof(passKey) ~= "string" then return end
	-- PromptGamePassPurchase ouvre une fenêtre Robux : sans limite, un client
	-- modifié pourrait la rouvrir en boucle chez lui.
	if not allow(player, "buyPass", 1) then return end
	local pass = Config.Passes[passKey]
	if not pass then return end
	if pass.id == 0 then
		rToast:FireClient(player, "Ce pass n'est pas encore configuré (ID Robux manquant).")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.id)
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
	if not wasPurchased then return end
	local session = sessions[player]
	if not session then return end
	local rebuildField = false
	for key, pass in Config.Passes do
		if pass.id == passId then
			session.passes[key] = true
			if key == "VIP" then nameTagBadge(player) end
			-- Le but n'est élargi qu'à la construction du terrain : sans
			-- reconstruction, « Grand Terrain » ne faisait rien jusqu'à la
			-- prochaine renaissance ou reconnexion — un achat Robux sans effet
			-- visible.
			if key == "BigField" then rebuildField = true end
		end
	end
	if rebuildField and session.field then
		if session.field.root then session.field.root:Destroy() end
		local origin = Config.Field.origin + Vector3.new(session.slot * SLOT_SPACING, 0, 0)
		session.field = FieldBuilder.build(true, origin,
			Config.fieldSizeMultiplier(session.data.rebirths), extraSlotsFor(session), session.data.world)
		session.repopulatePending = false
	end
	repopulate(session)
	-- Le terrain reconstruit repart avec ses figurines : si un défi est en cours,
	-- il faut le revider tout de suite (repopulate les rend visibles).
	if rebuildField and challengeActive and session.field then
		FieldBuilder.setChallengeMode(session.field, true)
	end
	updateLeaderstats(session, player)
	pushStats(player)
	rToast:FireClient(player, "✅ Pass activé, merci !")
end)

-------------------------------------------------------------------------------
-- DROIT À L'OUBLI : le joueur supprime lui-même ses données.
-- Deux clics : le premier prévient de ce qui va disparaître, le second confirme
-- dans la fenêtre impartie. C'est définitif, ça ne doit pas partir sur un clic.
-------------------------------------------------------------------------------
rErase.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then return end
	if not allow(player, "erase", 1) then return end

	local now = os.clock()
	if now >= session.eraseArmedUntil then
		session.eraseArmedUntil = now + Config.ErasureConfirmWindow
		rToast:FireClient(player, string.format(
			"⚠️ Supprimer TOUTES tes donnees : argent, puissance, renaissances et"
			.. " ta collection de %d joueurs. C'est definitif.\n"
			.. "Reclique dans les %d s pour confirmer.",
			#session.data.cards, Config.ErasureConfirmWindow))
		return
	end

	session.eraseArmedUntil = 0
	rToast:FireClient(player, "Suppression en cours...")
	task.spawn(function()
		Erasure.eraseAndKick(player)
	end)
end)

-------------------------------------------------------------------------------
-- Cycle de vie joueur.
-------------------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	local data = DataStore.load(player.UserId)

	-- L'équipe est toujours au complet : on complète la collection avec des
	-- Communs jusqu'au plafond du joueur. Vaut pour la première partie comme
	-- pour une sauvegarde d'avant (où seuls 4 emplacements étaient ouverts, ou
	-- où les renaissances n'agrandissaient pas encore l'équipe) — un terrain à
	-- trous donnait l'impression qu'il manquait des joueurs.
	local extraFromRebirths = Config.extraSlotsFromRebirths(data.rebirths)
	local starterTarget = Config.StartingSlots + extraFromRebirths
	while #data.cards < starterTarget do
		table.insert(data.cards, {
			name = Config.randomPlayerName(rng),
			rarity = Config.StarterRarity,
		})
	end
	data.slots = math.max(data.slots or 0, starterTarget)

	-- Sauvegardes d'avant l'ajout de `rolls` : le compteur y vaut 0, ce qui
	-- ferait retomber le prix des dés au tarif de départ pour un joueur qui a
	-- déjà des centaines de lancers derrière lui. On l'amorce sur la taille de
	-- la collection, exactement ce qui servait de base au calcul avant.
	data.rolls = math.max(data.rolls or 0, #data.cards)

	-- GAINS HORS LIGNE : rien n'est simulé, on reverse une fraction du rythme de
	-- gain observé lors des sessions précédentes (cf. Config.offlineEarnings).
	-- Calculé avant toute autre chose pour que l'argent soit déjà là quand le
	-- premier pushStats part.
	local offlineGain = 0
	if (data.lastSeen or 0) > 0 then
		offlineGain = Config.offlineEarnings(data.earnPerSec or 0, os.time() - (data.lastSeen or 0))
		if offlineGain > 0 then
			data.money += offlineGain
			data.totalEarned += offlineGain
		end
	end

	-- leaderstats
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local argent = Instance.new("IntValue"); argent.Name = "Argent"; argent.Parent = ls
	local reb = Instance.new("IntValue"); reb.Name = "Renaissances"; reb.Parent = ls
	local pow = Instance.new("IntValue"); pow.Name = "Puissance"; pow.Parent = ls
	ls.Parent = player

	-- Plot dédié. Les emplacements libérés sont réutilisés : sinon les plots
	-- s'éloignent indéfiniment au fil des allées et venues.
	local slot = table.remove(freeSlots) or nextSlot
	if slot == nextSlot then
		nextSlot += 1
	end
	local origin = Config.Field.origin + Vector3.new(slot * SLOT_SPACING, 0, 0)

	local session: Session = {
		data = data,
		field = nil,
		userId = player.UserId,
		slot = slot,
		passes = {},
		lastTrain = 0,
		lastShot = 0,
		lastRoll = 0,
		shootingUntil = 0,
		repopulatePending = false,
		chargeStartAt = nil,
		autoAngle = nil,
		lastGift = 0,
		eraseArmedUntil = 0,
		spawnPos = nil,
		props = nil,
		board = nil,
		challengeBest = 0,
		sessionStart = os.clock(),
		sessionEarned = 0,
	}
	sessions[player] = session

	refreshPasses(session, player)

	session.field = FieldBuilder.build(session.passes.BigField == true, origin,
		Config.fieldSizeMultiplier(data.rebirths), extraFromRebirths, data.world)
	local training = FieldBuilder.buildTrainingArea(origin)
	local entrance = FieldBuilder.buildEntrance(origin)
	session.spawnPos = entrance.spawnPos
	session.props = { training.model, entrance.model }
	session.board = entrance.board

	-- Panneau de classement du parvis : visible dès l'arrivée, alimenté par le
	-- même rafraîchissement que celui du stade.
	if entrance.board then
		Leaderboard.attach(entrance.board)
		table.insert(boards, entrance.board)
		task.spawn(Leaderboard.refresh)
	end

	repopulate(session)
	updateLeaderstats(session, player)

	player.CharacterAdded:Connect(function(char)
		local hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
		-- Apparition sur le parvis de SON plot : les SpawnLocation sont désactivés,
		-- sinon Roblox en choisirait un au hasard et on arriverait chez le voisin.
		task.wait(0.2)
		hrp.CFrame = CFrame.new(session.spawnPos)
		if session.passes.VIP then
			task.delay(0.5, function() nameTagBadge(player) end)
		end
	end)

	-- Arrivée en plein défi : le terrain doit être vide pour lui aussi, sinon il
	-- tirerait dans des figurines pendant que les autres visent la distance.
	if challengeActive then
		FieldBuilder.setChallengeMode(session.field, true)
	end

	pushStats(player)
	pushCollection(player)

	if offlineGain > 0 then
		local mins = math.floor(math.min(os.time() - (data.lastSeen or 0), Config.Offline.maxSeconds) / 60)
		rToast:FireClient(player, string.format("💤 Absent %d min — tes joueurs ont continué : +%s $",
			mins, Config.abbreviate(offlineGain)))
	end
end

-- Horodate la sauvegarde et met à jour le rythme de gain : c'est ce couple
-- (lastSeen + earnPerSec) qui produit les gains hors ligne à la reconnexion.
-- Moyenne glissante plutôt que remplacement : une session de deux minutes ne
-- doit pas effacer le rythme mesuré sur une heure de jeu.
local function stampSession(session: Session)
	local d = session.data
	local elapsed = math.max(60, os.clock() - session.sessionStart)
	local rate = session.sessionEarned / elapsed
	if rate ~= rate then rate = 0 end
	local prev = tonumber(d.earnPerSec) or 0
	d.earnPerSec = if prev > 0 then prev * 0.5 + rate * 0.5 else rate
	d.lastSeen = os.time()
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then return end
	Leaderboard.submit(player.UserId, session.data.totalEarned, true)  -- départ : on force
	stampSession(session)
	DataStore.save(player.UserId, session.data, true)
	DataStore.forget(player.UserId)
	Leaderboard.forget(player.UserId)
	if session.field and session.field.root then
		session.field.root:Destroy()
	end

	-- Décor du plot : sans ça, chaque passage laissait un stade fantôme (entrée,
	-- arbres, gym) dans le monde.
	for _, prop in session.props or {} do
		if prop then prop:Destroy() end
	end
	if session.board then
		Leaderboard.detach(session.board)
		for i, b in boards do
			if b == session.board then
				table.remove(boards, i)
				break
			end
		end
	end
	table.insert(freeSlots, session.slot)

	sessions[player] = nil
	-- La table est indexée par l'instance Player : sans ce nettoyage, chaque
	-- joueur parti reste référencé pour la durée de vie du serveur.
	rateBuckets[player] = nil
end

-- Point d'apparition par défaut de Roblox, hors plot : un plot est détruit quand
-- son joueur part, et un SpawnLocation qui disparaît fait apparaître les
-- suivants à l'origine du monde, au milieu d'un terrain.
do
	local lobby = Instance.new("SpawnLocation")
	lobby.Name = "SpawnMonde"
	lobby.Anchored = true
	lobby.Neutral = true
	lobby.Size = Vector3.new(16, 1, 16)
	lobby.Color = Color3.fromRGB(255, 210, 60)
	lobby.Material = Enum.Material.Neon
	lobby.CFrame = CFrame.new(Config.Field.origin
		+ Vector3.new(0, 1, Config.Field.shootLine - Config.Entrance.plazaOffset))
	lobby.Parent = workspace
end

-- Demandes de suppression transmises par Roblox pour des joueurs absents
-- (cf. Config.ErasureRequests). Traitées en tâche de fond, espacées.
Erasure.processPendingRequests()

Players.PlayerAdded:Connect(function(p)
	onPlayerAdded(p)
	pushRoster()
end)
Players.PlayerRemoving:Connect(function(p)
	onPlayerRemoving(p)
	-- Après le retrait : PlayerRemoving tire avant que le joueur ne quitte la
	-- liste, un pushRoster immédiat le renverrait comme destinataire possible.
	task.defer(pushRoster)
end)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end
pushRoster()

game:BindToClose(function()
	for player, session in sessions do
		stampSession(session)
		DataStore.save(player.UserId, session.data, true)  -- arrêt serveur : on force
	end
	task.wait(1)
end)

-------------------------------------------------------------------------------
-- Panneau + boucle de classement mondial.
-------------------------------------------------------------------------------
-- Le grand panneau est calé derrière le terrain LE PLUS GRAND possible : calculé
-- sur la longueur de base, il se retrouvait planté au milieu du terrain du
-- joueur du premier plot dès que ses renaissances l'avaient agrandi.
local maxLength = Config.Field.length * (1 + Config.Rebirth.maxFieldGrowth)
local gui = FieldBuilder.buildLeaderboardBoard({
	origin = Config.Field.origin,
	goalZ = Config.Field.origin.Z + maxLength / 2 + Config.Field.goalDepth,
})
Leaderboard.attach(gui)
table.insert(boards, gui)

task.spawn(function()
	while true do
		Leaderboard.refresh()
		task.wait(30)
	end
end)

-------------------------------------------------------------------------------
-- COUP DE SIFFLET : cycle de 30 s affiché sur le grand écran, puis fenêtre de
-- bonus où tous les gains sont multipliés (voir moneyMultiplier).
-------------------------------------------------------------------------------
task.spawn(function()
	local M = Config.Match
	while true do
		local now = os.clock()

		if now >= nextWhistle then
			boostUntil = now + M.boostTime
			-- Le cycle suivant repart APRÈS le bonus, sinon deux fenêtres se
			-- chevaucheraient et le bonus ne s'arrêterait jamais.
			nextWhistle = now + M.boostTime + M.cycle
			for player in sessions do
				rToast:FireClient(player, string.format(
					"📣 COUP DE SIFFLET — argent ×%d pendant %d s !", M.boostMult, M.boostTime))
			end
		end

		local text, color
		if boostActive() then
			text = string.format("🔥 ARGENT ×%d — encore %d s",
				M.boostMult, math.ceil(boostUntil - now))
			color = Color3.fromRGB(120, 255, 140)
		else
			text = string.format("⏱ Prochain bonus ×%d dans %d s",
				M.boostMult, math.max(0, math.ceil(nextWhistle - now)))
			color = Color3.fromRGB(255, 210, 60)
		end
		for _, board in boards do
			local timer = board:FindFirstChild("Timer") :: TextLabel?
			if timer then
				timer.Text = text
				timer.TextColor3 = color
			end
		end

		task.wait(0.25)
	end
end)

-------------------------------------------------------------------------------
-- DÉFI DU LOIN : toutes les 10 minutes, une manche d'une minute.
--
-- Le terrain de chacun se vide (plus de figurines, plus de but) et le seul score
-- est la distance du meilleur tir. À la fin, les trois premiers reçoivent une
-- potion dans leur sac à dos. Aucun argent n'est distribué : le défi récompense
-- l'adresse, il ne remplace pas le jeu.
-------------------------------------------------------------------------------
local function challengeScoreboard()
	local scores = {}
	for player, session in sessions do
		if session.challengeBest > 0 then
			table.insert(scores, { name = player.DisplayName, distance = math.floor(session.challengeBest) })
		end
	end
	table.sort(scores, function(a, b) return a.distance > b.distance end)
	-- Panneau de 5 lignes : au-delà, personne ne lit pendant qu'il vise.
	while #scores > 5 do table.remove(scores) end
	return scores
end

local function pushChallenge()
	local target = if challengeActive then challengeEndsAt else nextChallengeAt
	rChallenge:FireAllClients({
		active = challengeActive,
		left = math.max(0, math.ceil(target - os.clock())),
		scores = challengeScoreboard(),
	})
end

local function startChallenge()
	challengeActive = true
	challengeAnnounced = false
	challengeEndsAt = os.clock() + Config.Challenge.duration
	for player, session in sessions do
		session.challengeBest = 0
		FieldBuilder.setChallengeMode(session.field, true)
		rToast:FireClient(player, string.format(
			"🏹 DÉFI DU LOIN — %d s pour envoyer la balle le plus loin possible !", Config.Challenge.duration))
	end
	pushChallenge()
end

local function endChallenge()
	challengeActive = false
	nextChallengeAt = os.clock() + Config.Challenge.interval

	local ranking = {}
	for player, session in sessions do
		if session.challengeBest > 0 then
			table.insert(ranking, { player = player, session = session, dist = session.challengeBest })
		end
	end
	table.sort(ranking, function(a, b) return a.dist > b.dist end)

	local places = { "1er", "2e", "3e" }
	for rank, entry in ranking do
		local key = Config.Challenge.rewards[rank]
		if not key then break end
		local potion = Config.potion(key)
		if potion then
			grantPotion(entry.session, key, 1)
			rToast:FireClient(entry.player, string.format("🏅 %s du défi (%d studs) — %s dans le sac à dos !",
				places[rank] or (rank .. "e"), math.floor(entry.dist), potion.name))
		end
	end

	for player, session in sessions do
		FieldBuilder.setChallengeMode(session.field, false)
		session.challengeBest = 0
		-- Reconstruction directe et non `repopulate` : une balle de défi peut
		-- encore être en vol, et repopulate reporterait le replacement à plus tard
		-- (l'équipe resterait invisible). Une balle de défi ne lit aucune figurine,
		-- reposer l'équipe sous elle ne fausse rien.
		session.repopulatePending = false
		FieldBuilder.placeSquad(session.field, squadOf(session), unlockedSlots(session))
		pushStats(player)
	end
	pushChallenge()
end

task.spawn(function()
	local C = Config.Challenge
	while true do
		local now = os.clock()
		if challengeActive then
			if now >= challengeEndsAt then
				endChallenge()
			end
		elseif now >= nextChallengeAt then
			startChallenge()
		elseif not challengeAnnounced and now >= nextChallengeAt - C.warmup then
			challengeAnnounced = true
			for player in sessions do
				rToast:FireClient(player, string.format(
					"🏹 Défi du loin dans %d s — terrain vide, tir le plus long !", C.warmup))
			end
		end
		pushChallenge()
		task.wait(1)
	end
end)

-- Sauvegarde périodique.
task.spawn(function()
	while true do
		task.wait(120)
		for player, session in sessions do
			stampSession(session)
			DataStore.save(player.UserId, session.data)
		end
	end
end)

-- Avertissement explicite : une passe sans ID n'est ni vendue ni accordée, et
-- l'oubli ne se voit sinon qu'au moment où un joueur clique dessus.
do
	local missing = Config.unconfiguredPasses()
	if #missing > 0 then
		warn(string.format(
			"[BabyFoot] %d game pass sans ID (non vendus) : %s — renseigne Config.PassIds, cf. PASSES.md",
			#missing, table.concat(missing, ", ")))
	else
		-- Compté, pas écrit en dur : le nombre de passes a déjà changé une fois.
		local total = 0
		for _ in Config.Passes do total += 1 end
		print(string.format("[BabyFoot] Les %d game passes sont configurés.", total))
	end
end

print("[BabyFoot] Serveur prêt.")
