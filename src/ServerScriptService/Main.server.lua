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

-- Tirage des dés : un seul générateur serveur, jamais le client.
local rng = Random.new()

-------------------------------------------------------------------------------
-- État en mémoire par joueur.
-------------------------------------------------------------------------------
type Session = {
	data: any,
	field: any,
	slot: number,
	passes: { [string]: boolean },
	lastTrain: number,
	lastShot: number,
	lastRoll: number,
	shootingUntil: number,      -- une seule balle en vol par joueur (verrou auto-expirant)
	repopulatePending: boolean, -- replacement des figurines reporté après le tir
	chargeStartAt: number?,     -- horodatage serveur de l'appui sur TIRER
	eraseArmedUntil: number,    -- droit à l'oubli : fenêtre de confirmation
	spawnPos: Vector3?,
	props: { Instance }?,      -- décor du plot (entrée, gym) à détruire au départ
	board: SurfaceGui?,        -- panneau de classement du parvis
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

local function moneyMultiplier(session: Session): number
	local rb = Config.rebirthMultiplier(session.data.rebirths, session.passes.RebirthX2 == true)
	local m = rb
	if session.passes.VIP then m *= 2 end
	if session.passes.MoneyX2 then m *= 2 end
	if boostActive() then m *= Config.Match.boostMult end
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
		diceCost = math.floor(Config.diceCost(#d.cards, session.passes.VIP == true) * costMult),
		playerValue = Config.playerValueAt(d.valueLevel),
		playerValueCost = math.floor(Config.playerValueCost(d.valueLevel) * costMult),
		rebirthCost = Config.rebirthCost(d.rebirths),
		nextRebirthMult = Config.rebirthMultiplier(d.rebirths + 1, session.passes.RebirthX2 == true),
		passes = session.passes,
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
end

local function pushCollection(player: Player)
	local session = sessions[player]
	if not session then return end
	rCollection:FireClient(player, {
		cards = session.data.cards,
		squad = squadOf(session),
		unlockedSlots = unlockedSlots(session),
		maxSlots = maxSlotsFor(session),
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
	if not allow(player, "chargeStart", 0.10) then return end
	session.chargeStartAt = os.clock()
end)

rShoot.OnServerEvent:Connect(function(player, angleDeg, chargePct)
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
	session.lastShot = now
	session.shootingUntil = now + Config.Shot.ballLifetime + 1

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
	if session.chargeStartAt then
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
	speed = math.min(speed, S.maxSpeed)

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

	while elapsed < S.ballLifetime and speed > 1 do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		speed = math.max(0, speed - S.decel * dt)
		pos = pos + Vector3.new(dirX * speed * dt, 0, dirZ * speed * dt)

		-- Rebond sur les murs latéraux.
		local dx = pos.X - field.origin.X
		if math.abs(dx) > halfW then
			dirX = -dirX
			pos = Vector3.new(field.origin.X + math.sign(dx) * halfW, pos.Y, pos.Z)
		end

		ball.Position = Vector3.new(pos.X, field.shootPos.Y, pos.Z)

		-- Collisions joueurs. `targets` ne contient que les "Figure" debout : les
		-- socles d'emplacement vide ne comptent pas, sinon un terrain à moitié
		-- vide rapporterait autant qu'une équipe complète.
		local bx, bz = pos.X, pos.Z
		for _, fig in targets do
			if not hitSet[fig] and fig.Parent then
				local fp = fig.Position
				-- Distance au carré dans le plan : évite une racine carrée par
				-- figurine et par frame (41 x 60/s et par balle en vol).
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
					-- Masquée immédiatement : un task.delay la laissait une frame
					-- de plus dans la liste, le temps qu'une autre balle la
					-- compte elle aussi.
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
			break
		end
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

rRoll.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then return end
	local now = os.clock()
	if now - session.lastRoll < Config.Dice.cooldown then return end
	session.lastRoll = now

	local d = session.data
	local cost = math.floor(Config.diceCost(#d.cards, session.passes.VIP == true) * upgradeCostMult(session))
	if d.money < cost then
		rToast:FireClient(player, "Pas assez d'argent pour lancer les dés ("
			.. Config.abbreviate(cost) .. " $)")
		return
	end
	d.money -= cost

	local key = Config.rollRarity(rng, session.passes.LuckyDice == true)
	local card = { name = Config.randomPlayerName(rng), rarity = key }
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
	session.field = FieldBuilder.build(session.passes.BigField == true, origin,
		Config.fieldSizeMultiplier(d.rebirths), extraSlotsFor(session))

	repopulate(session)
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
	for key, pass in Config.Passes do
		if pass.id == passId then
			session.passes[key] = true
			if key == "VIP" then nameTagBadge(player) end
		end
	end
	repopulate(session)
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
		slot = slot,
		passes = {},
		lastTrain = 0,
		lastShot = 0,
		lastRoll = 0,
		shootingUntil = 0,
		repopulatePending = false,
		chargeStartAt = nil,
		eraseArmedUntil = 0,
		spawnPos = nil,
		props = nil,
		board = nil,
	}
	sessions[player] = session

	refreshPasses(session, player)

	session.field = FieldBuilder.build(session.passes.BigField == true, origin,
		Config.fieldSizeMultiplier(data.rebirths), extraFromRebirths)
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

	pushStats(player)
	pushCollection(player)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then return end
	Leaderboard.submit(player.UserId, session.data.totalEarned, true)  -- départ : on force
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

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

game:BindToClose(function()
	for player, session in sessions do
		DataStore.save(player.UserId, session.data, true)  -- arrêt serveur : on force
	end
	task.wait(1)
end)

-------------------------------------------------------------------------------
-- Panneau + boucle de classement mondial.
-------------------------------------------------------------------------------
local gui = FieldBuilder.buildLeaderboardBoard({
	origin = Config.Field.origin,
	goalZ = Config.Field.origin.Z + Config.Field.length / 2 + Config.Field.goalDepth,
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

-- Sauvegarde périodique.
task.spawn(function()
	while true do
		task.wait(120)
		for player, session in sessions do
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
		print("[BabyFoot] Les 6 game passes sont configurés.")
	end
end

print("[BabyFoot] Serveur prêt.")
