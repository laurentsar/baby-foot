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

-- Remotes
local rTrain = Remotes.get("Train")
local rShoot = Remotes.get("Shoot")
local rBuy = Remotes.get("BuyUpgrade")
local rRebirth = Remotes.get("Rebirth")
local rBuyPass = Remotes.get("BuyPass")
local rStats = Remotes.get("StatsUpdate")
local rShotResult = Remotes.get("ShotResult")
local rToast = Remotes.get("Toast")

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
}

local sessions: { [Player]: Session } = {}
local nextSlot = 0
local SLOT_SPACING = 320  -- distance entre deux plots

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

local function moneyMultiplier(session: Session): number
	local rb = Config.rebirthMultiplier(session.data.rebirths, session.passes.RebirthX2 == true)
	local m = rb
	if session.passes.VIP then m *= 2 end
	if session.passes.MoneyX2 then m *= 2 end
	return m
end

-- Plafond de figurines : base config + renaissances + VIP + (infini si pass).
local function figureCap(session: Session): number
	if session.passes.InfPlayers then return math.huge end
	local cap = Config.PlayerCount.maxLevel
	cap += session.data.rebirths * Config.Rebirth.capacityBonus
	if session.passes.VIP then cap += Config.VIPCapacityBonus end
	return cap
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
	local capLevel = figureCap(session)
	return {
		money = d.money,
		power = d.power,
		rebirths = d.rebirths,
		totalEarned = d.totalEarned,
		moneyMult = moneyMultiplier(session),
		dumbbell = { name = dumb.name, powerGain = dumb.powerGain, level = d.dumbbell },
		nextDumbbell = nextDumb and { name = nextDumb.name, cost = nextDumb.cost } or nil,
		ball = { name = ball.name, moneyMult = ball.moneyMult, level = d.ball },
		nextBall = nextBall and { name = nextBall.name, cost = nextBall.cost } or nil,
		playerCount = Config.playerCountAt(d.countLevel),
		playerCountCap = (capLevel == math.huge) and -1 or capLevel, -- -1 = infini

		playerCountCost = Config.playerCountCost(d.countLevel),
		playerValue = Config.playerValueAt(d.valueLevel),
		playerValueCost = Config.playerValueCost(d.valueLevel),
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
-- Figurines : (re)peuple le terrain selon le nb voulu et le plafond.
-------------------------------------------------------------------------------
local function desiredFigures(session: Session): number
	local want = Config.playerCountAt(session.data.countLevel)
	local cap = figureCap(session)
	if cap == math.huge then return want end
	return math.min(want, cap)
end

local function repopulate(session: Session)
	FieldBuilder.populateFigures(session.field, desiredFigures(session))
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

rShoot.OnServerEvent:Connect(function(player, angleDeg, chargePct)
	local session = sessions[player]
	if not session then return end
	if typeof(angleDeg) ~= "number" or typeof(chargePct) ~= "number" then return end
	local now = os.clock()
	if now - session.lastShot < Config.Shot.cooldown then return end
	session.lastShot = now

	local field = session.field
	local S = Config.Shot
	-- L'angle vient de l'orientation caméra du client ; le serveur reste maître
	-- des bornes (un client modifié ne peut pas tirer à 180°).
	angleDeg = math.clamp(angleDeg, -S.maxAngle, S.maxAngle)
	chargePct = math.clamp(chargePct, 0, 1)

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
	ball.Position = field.shootPos
	ball.Parent = field.root

	-- Seuil de but (plus proche avec le pass Grand Terrain).
	local scoreZ = field.goalZ
	if session.passes.BigField then
		scoreZ = field.origin.Z + (field.goalZ - field.origin.Z) * S.bigFieldScoreFactor
	end

	local pos = field.shootPos
	local halfW = field.width / 2 - 2
	local hitSet: { [Instance]: boolean } = {}
	local hits = 0
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

		-- Collisions figurines.
		for _, fig in field.figuresFolder:GetChildren() do
			if fig:IsA("BasePart") and not hitSet[fig] then
				local fp = fig.Position
				if (Vector3.new(fp.X, ball.Position.Y, fp.Z) - ball.Position).Magnitude < S.hitRadius then
					hitSet[fig] = true
					hits += 1
					fig.Color = Color3.fromRGB(255, 220, 60)
					task.delay(0, function() fig:Destroy() end)
				end
			end
		end

		-- But atteint ?
		if pos.Z >= scoreZ then
			scored = true
			break
		end
		-- Sortie par le fond
		if pos.Z >= field.goalZ + 20 then break end
	end

	-- Effet de but.
	if scored then
		field.goalPart.Color = Color3.fromRGB(120, 255, 140)
		task.delay(0.4, function()
			field.goalPart.Color = Color3.fromRGB(80, 220, 255)
		end)
	end

	task.delay(0.15, function() ball:Destroy() end)

	-- Calcul du gain.
	local perHit = Config.playerValueAt(session.data.valueLevel)
		* Config.Balls[session.data.ball].moneyMult
	local money = hits * perHit * moneyMultiplier(session)
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
	})

	-- Respawn des cibles après le tir.
	task.delay(0.6, function()
		if sessions[player] then repopulate(session) end
	end)

	-- Soumet au classement (throttle léger).
	Leaderboard.submit(player.UserId, session.data.totalEarned)
end)

-------------------------------------------------------------------------------
-- UPGRADES.
-------------------------------------------------------------------------------
rBuy.OnServerEvent:Connect(function(player, kind)
	local session = sessions[player]
	if not session then return end
	local d = session.data

	if kind == "dumbbell" then
		local nxt = Config.Dumbbells[d.dumbbell + 1]
		if nxt and d.money >= nxt.cost then
			d.money -= nxt.cost
			d.dumbbell += 1
		end
	elseif kind == "ball" then
		local nxt = Config.Balls[d.ball + 1]
		if nxt and d.money >= nxt.cost then
			d.money -= nxt.cost
			d.ball += 1
		end
	elseif kind == "count" then
		local cap = figureCap(session)
		if Config.playerCountAt(d.countLevel + 1) <= cap then
			local cost = Config.playerCountCost(d.countLevel)
			if d.money >= cost then
				d.money -= cost
				d.countLevel += 1
				repopulate(session)
			end
		else
			rToast:FireClient(player, "Plafond de figurines atteint — fais une Renaissance ou prends un pass !")
		end
	elseif kind == "value" then
		local cost = Config.playerValueCost(d.valueLevel)
		if d.money >= cost then
			d.money -= cost
			d.valueLevel += 1
		end
	end

	updateLeaderstats(session, player)
	pushStats(player)
end)

-------------------------------------------------------------------------------
-- RENAISSANCE : reset argent + upgrades, +1 renaissance (mult permanent).
-------------------------------------------------------------------------------
rRebirth.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then return end
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
	d.countLevel = 0
	d.valueLevel = 0
	repopulate(session)
	updateLeaderstats(session, player)
	pushStats(player)
	rToast:FireClient(player, "🔄 Renaissance ! Multiplicateur permanent x"
		.. Config.rebirthMultiplier(d.rebirths, session.passes.RebirthX2 == true))
end)

-------------------------------------------------------------------------------
-- GAME PASSES : ouvre la boutique Robux.
-------------------------------------------------------------------------------
rBuyPass.OnServerEvent:Connect(function(player, passKey)
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
-- Cycle de vie joueur.
-------------------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	local data = DataStore.load(player.UserId)

	-- leaderstats
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local argent = Instance.new("IntValue"); argent.Name = "Argent"; argent.Parent = ls
	local reb = Instance.new("IntValue"); reb.Name = "Renaissances"; reb.Parent = ls
	local pow = Instance.new("IntValue"); pow.Name = "Puissance"; pow.Parent = ls
	ls.Parent = player

	-- Plot dédié
	local slot = nextSlot
	nextSlot += 1
	local origin = Config.Field.origin + Vector3.new(slot * SLOT_SPACING, 0, 0)

	local session: Session = {
		data = data,
		field = nil,
		slot = slot,
		passes = {},
		lastTrain = 0,
		lastShot = 0,
	}
	sessions[player] = session

	refreshPasses(session, player)

	local fieldMult = session.passes.BigField and Config.BigFieldMultiplier or 1
	session.field = FieldBuilder.build(fieldMult, origin)
	local training = FieldBuilder.buildTrainingArea(origin)
	local _ = training

	repopulate(session)
	updateLeaderstats(session, player)

	player.CharacterAdded:Connect(function(char)
		local hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
		-- Téléporte le joueur à sa zone d'entraînement.
		task.wait(0.2)
		hrp.CFrame = CFrame.new(origin + Vector3.new(-Config.Field.width, 5, Config.Field.shootLine + 14))
		if session.passes.VIP then
			task.delay(0.5, function() nameTagBadge(player) end)
		end
	end)

	pushStats(player)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then return end
	Leaderboard.submit(player.UserId, session.data.totalEarned)
	DataStore.save(player.UserId, session.data, true)  -- départ : on force
	DataStore.forget(player.UserId)
	if session.field and session.field.root then
		session.field.root:Destroy()
	end
	sessions[player] = nil
end

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

task.spawn(function()
	while true do
		Leaderboard.refresh()
		task.wait(30)
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

print("[BabyFoot] Serveur prêt.")
