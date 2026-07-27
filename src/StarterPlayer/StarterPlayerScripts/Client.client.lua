--!strict
-- Client Baby-Foot Power : interface d'entraînement, visée, tir chargé, boutique, passes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local rTrain = Remotes.get("Train")
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

local ACCENT = Color3.fromRGB(80, 220, 255)
local GOLD = Color3.fromRGB(255, 200, 50)
local BG = Color3.fromRGB(18, 20, 28)
local PANEL = Color3.fromRGB(28, 31, 42)

-------------------------------------------------------------------------------
-- Helpers UI.
-------------------------------------------------------------------------------
local function corner(inst: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	if parent then i.Parent = parent end
	return i
end

local function button(text: string, color: Color3, parent: Instance): TextButton
	local b = make("TextButton", {
		Text = text,
		BackgroundColor3 = color,
		TextColor3 = Color3.fromRGB(15, 15, 20),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}, parent)
	corner(b, 10)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
	}, b)
	return b
end

-------------------------------------------------------------------------------
-- ScreenGui racine.
-------------------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "BabyFootUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-------------------------------------------------------------------------------
-- Panneau de stats (haut-gauche).
-------------------------------------------------------------------------------
local statsPanel = make("Frame", {
	Size = UDim2.fromOffset(260, 130),
	Position = UDim2.fromOffset(16, 16),
	BackgroundColor3 = BG,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
}, gui)
corner(statsPanel, 12)
make("UIStroke", { Color = ACCENT, Thickness = 1.5, Transparency = 0.4 }, statsPanel)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Left }, statsPanel)
make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 8) }, statsPanel)

local function statLine(order: number): TextLabel
	return make("TextLabel", {
		Size = UDim2.new(1, -12, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(235, 235, 245),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		LayoutOrder = order,
		Text = "",
	}, statsPanel)
end

local lblMoney = statLine(1)
local lblPower = statLine(2)
local lblRebirth = statLine(3)
local lblMult = statLine(4)

-------------------------------------------------------------------------------
-- Contrôles bas : visée + charge + tir + entraînement.
-------------------------------------------------------------------------------
local bottom = make("Frame", {
	Size = UDim2.new(1, 0, 0, 170),
	Position = UDim2.new(0, 0, 1, -170),
	BackgroundTransparency = 1,
}, gui)

-- Bouton ENTRAÎNEMENT (gauche)
local trainBtn = button("🏋️ S'ENTRAÎNER", GOLD, bottom)
trainBtn.Size = UDim2.fromOffset(200, 90)
trainBtn.Position = UDim2.new(0, 24, 0, 40)
trainBtn.TextSize = 28

-- VISÉE = ORIENTATION DE LA CAMÉRA. Plus de slider : on tire là où on regarde.
-- L'axe du terrain est +Z, donc angle = atan2(look.X, look.Z), borné comme côté
-- serveur (Config.Shot.maxAngle).
local aimAngle = 0

local aimFrame = make("Frame", {
	Size = UDim2.fromOffset(300, 34),
	Position = UDim2.new(0.5, -150, 0, 0),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
}, bottom)
corner(aimFrame, 10)
local aimLabel = make("TextLabel", {
	Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0),
	BackgroundTransparency = 1, Text = "VISÉE : regarde où tu veux tirer",
	Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = ACCENT,
}, aimFrame)

local function updateAim()
	-- Relu à chaque frame : la caméra est remplacée au respawn.
	local camera = workspace.CurrentCamera
	if not camera then return end
	local look = camera.CFrame.LookVector
	local raw = math.deg(math.atan2(look.X, look.Z))
	local maxA = Config.Shot.maxAngle
	aimAngle = math.clamp(raw, -maxA, maxA)
	local arrow = if aimAngle < -2 then "◄" elseif aimAngle > 2 then "►" else "▲"
	local capped = if math.abs(raw) > maxA then "  (max)" else ""
	aimLabel.Text = string.format("VISÉE %s %d°%s", arrow, math.floor(aimAngle + 0.5), capped)
	aimLabel.TextColor3 = if capped == "" then ACCENT else Color3.fromRGB(255, 150, 90)
end

-- Bouton TIR + jauge de charge (droite)
local shootBtn = button("⚽ TIRER", ACCENT, bottom)
shootBtn.Size = UDim2.fromOffset(200, 90)
shootBtn.Position = UDim2.new(1, -224, 0, 40)
shootBtn.TextSize = 30

-- JAUGE DE TIR : 4 paliers de qualité (rouge nul → vert foncé très bien).
-- Les seuils et couleurs viennent de Config.ChargeTiers, partagé avec le serveur
-- qui applique le multiplicateur correspondant : ce qu'on voit est ce qu'on tire.
local chargeTrack = make("Frame", {
	Size = UDim2.fromOffset(440, 26), Position = UDim2.new(0.5, -220, 0, 96),
	BackgroundColor3 = PANEL, BorderSizePixel = 0,
}, bottom)
corner(chargeTrack, 13)
make("UIStroke", { Color = Color3.fromRGB(70, 74, 92), Thickness = 1.5 }, chargeTrack)

local chargeFill = make("Frame", {
	Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Config.ChargeTiers[1].color,
	BorderSizePixel = 0,
}, chargeTrack)
corner(chargeFill, 13)

-- Repères aux frontières de paliers, pour viser le vert foncé au relâcher.
for i = 1, #Config.ChargeTiers - 1 do
	make("Frame", {
		Size = UDim2.new(0, 2, 1, 0),
		Position = UDim2.new(Config.ChargeTiers[i].upTo, -1, 0, 0),
		BackgroundColor3 = Color3.fromRGB(15, 16, 22),
		BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 3,
	}, chargeTrack)
end

local chargeLabel = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 70),
	BackgroundTransparency = 1, Text = "MAINTIENS ⚽ TIRER POUR CHARGER",
	Font = Enum.Font.GothamBlack, TextScaled = true,
	TextColor3 = Color3.fromRGB(210, 214, 230), ZIndex = 2,
}, bottom)

-- Logique de charge : maintenir TIR = charger, relâcher = tirer.
local charging = false
local charge = 0
local chargeUp = true

shootBtn.MouseButton1Down:Connect(function()
	charging = true
	charge = 0
	chargeUp = true
end)

local function fireShot()
	if not charging then return end
	charging = false
	local tier = Config.chargeTier(charge)
	rShoot:FireServer(aimAngle, charge)
	chargeLabel.Text = "TIR : " .. tier.label
	chargeLabel.TextColor3 = tier.color
	charge = 0
	chargeFill.Size = UDim2.new(0, 0, 1, 0)
end
shootBtn.MouseButton1Up:Connect(fireShot)
shootBtn.MouseLeave:Connect(function()
	if charging then fireShot() end
end)

RunService.RenderStepped:Connect(function(dt)
	updateAim()
	if charging then
		-- va-et-vient de la jauge : relâche au bon moment pour un tir max.
		if chargeUp then
			charge += dt * 1.4
			if charge >= 1 then charge = 1; chargeUp = false end
		else
			charge -= dt * 1.4
			if charge <= 0 then charge = 0; chargeUp = true end
		end
		local tier = Config.chargeTier(charge)
		chargeFill.Size = UDim2.new(charge, 0, 1, 0)
		chargeFill.BackgroundColor3 = tier.color
		chargeLabel.Text = tier.label
		chargeLabel.TextColor3 = tier.color
	end
end)

-- Entraînement : clic = 1 rep, maintien = reps auto.
local training = false
trainBtn.MouseButton1Down:Connect(function() training = true; rTrain:FireServer() end)
trainBtn.MouseButton1Up:Connect(function() training = false end)
trainBtn.MouseLeave:Connect(function() training = false end)
task.spawn(function()
	while true do
		if training then rTrain:FireServer() end
		task.wait(Config.Train.repCooldown)
	end
end)

-------------------------------------------------------------------------------
-- Boutique (droite, repliable).
-------------------------------------------------------------------------------
local shopOpen = false
local shopToggle = button("🛒 BOUTIQUE", Color3.fromRGB(120, 200, 120), gui)
shopToggle.Size = UDim2.fromOffset(150, 44)
shopToggle.Position = UDim2.new(1, -166, 0, 16)
shopToggle.TextSize = 20

local shop = make("Frame", {
	Size = UDim2.fromOffset(320, 520),
	Position = UDim2.new(1, -336, 0, 70),
	BackgroundColor3 = BG,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
corner(shop, 14)
make("UIStroke", { Color = Color3.fromRGB(120, 200, 120), Thickness = 1.5, Transparency = 0.4 }, shop)

local shopScroll = make("ScrollingFrame", {
	Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8),
	BackgroundTransparency = 1, BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, shop)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, shopScroll)

shopToggle.MouseButton1Click:Connect(function()
	shopOpen = not shopOpen
	shop.Visible = shopOpen
end)

local function shopHeader(text: string, order: number, color: Color3)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
		Text = text, Font = Enum.Font.GothamBlack, TextScaled = true,
		TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	}, shopScroll)
end

-- Fabrique un bouton d'achat + garde une réf pour MAJ des libellés.
local upgradeButtons: { [string]: TextButton } = {}
local function upgradeButton(kind: string, order: number)
	local b = button("…", Color3.fromRGB(70, 130, 200), shopScroll)
	b.Size = UDim2.new(1, 0, 0, 54)
	b.TextSize = 16
	b.LayoutOrder = order
	b.MouseButton1Click:Connect(function() rBuy:FireServer(kind) end)
	upgradeButtons[kind] = b
end

shopHeader("💪 ENTRAÎNEMENT & BALLE", 1, ACCENT)
upgradeButton("dumbbell", 2)
upgradeButton("ball", 3)
shopHeader("⚽ ÉQUIPE", 4, GOLD)
upgradeButton("slot", 5)
upgradeButton("value", 6)
shopHeader("🔄 RENAISSANCE", 7, Color3.fromRGB(255, 120, 200))
local rebirthBtn = button("…", Color3.fromRGB(255, 120, 200), shopScroll)
rebirthBtn.Size = UDim2.new(1, 0, 0, 54); rebirthBtn.TextSize = 16; rebirthBtn.LayoutOrder = 8
rebirthBtn.MouseButton1Click:Connect(function() rRebirth:FireServer() end)

shopHeader("💎 GAME PASSES (Robux)", 9, Color3.fromRGB(180, 130, 255))
local passOrder = 10
for key, pass in Config.Passes do
	local b = button(pass.label .. "  🟣", Color3.fromRGB(150, 110, 235), shopScroll)
	b.Size = UDim2.new(1, 0, 0, 58); b.TextSize = 14; b.LayoutOrder = passOrder
	b.MouseButton1Click:Connect(function() rBuyPass:FireServer(key) end)
	passOrder += 1
	-- description sous le bouton
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
		Text = pass.desc, Font = Enum.Font.Gotham, TextWrapped = true,
		TextSize = 12, TextColor3 = Color3.fromRGB(180, 180, 200),
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = passOrder,
	}, shopScroll)
	passOrder += 1
end

-------------------------------------------------------------------------------
-- DÉS + COLLECTION (colonne de gauche, sous les stats).
-- Les joueurs de foot s'obtiennent en lançant les dés ; les meilleurs sont
-- automatiquement placés sur les bases, dans la limite des emplacements.
-------------------------------------------------------------------------------
local diceBtn = button("🎲 RECRUTER", Color3.fromRGB(235, 170, 60), gui)
diceBtn.Size = UDim2.fromOffset(200, 62)
diceBtn.Position = UDim2.fromOffset(16, 156)
diceBtn.TextSize = 20
diceBtn.MouseButton1Click:Connect(function() rRoll:FireServer() end)

local squadLabel = make("TextLabel", {
	Size = UDim2.fromOffset(230, 22), Position = UDim2.fromOffset(16, 226),
	BackgroundTransparency = 1, Text = "👥 Équipe 0/11",
	Font = Enum.Font.GothamBold, TextScaled = true,
	TextColor3 = Color3.fromRGB(220, 224, 240),
	TextXAlignment = Enum.TextXAlignment.Left,
}, gui)

local collecToggle = button("👥 COLLECTION", Color3.fromRGB(150, 110, 235), gui)
collecToggle.Size = UDim2.fromOffset(200, 40)
collecToggle.Position = UDim2.fromOffset(16, 254)
collecToggle.TextSize = 16

local collecPanel = make("Frame", {
	Size = UDim2.fromOffset(320, 420), Position = UDim2.fromOffset(16, 302),
	BackgroundColor3 = BG, BackgroundTransparency = 0.05,
	BorderSizePixel = 0, Visible = false,
}, gui)
corner(collecPanel, 14)
make("UIStroke", { Color = Color3.fromRGB(150, 110, 235), Thickness = 1.5, Transparency = 0.4 }, collecPanel)

local collecScroll = make("ScrollingFrame", {
	Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8),
	BackgroundTransparency = 1, BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, collecPanel)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, collecScroll)

collecToggle.MouseButton1Click:Connect(function()
	collecPanel.Visible = not collecPanel.Visible
end)

local function collecLine(text: string, color: Color3, order: number, height: number)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1,
		Text = text, Font = Enum.Font.GothamBold, TextScaled = true,
		TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	}, collecScroll)
end

rCollection.OnClientEvent:Connect(function(c)
	collecScroll:ClearAllChildren()
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, collecScroll)

	local order = 1
	collecLine(string.format("SUR LE TERRAIN (%d/%d)", #c.squad, c.maxSlots), GOLD, order, 24)
	order += 1
	for i, card in c.squad do
		local r = Config.rarity(card.rarity)
		collecLine(string.format("%d. %s — %s ×%s", i, card.name, r.name, Config.abbreviate(r.mult)),
			r.color, order, 20)
		order += 1
	end
	if #c.squad == 0 then
		collecLine("Aucun joueur — lance les dés !", Color3.fromRGB(180, 180, 200), order, 20)
		order += 1
	end

	-- Reste de la collection, résumé par rareté : au-delà de 11 joueurs, seul le
	-- compte importe (le terrain ne prend que les meilleurs).
	local counts: { [string]: number } = {}
	for _, card in c.cards do
		counts[card.rarity] = (counts[card.rarity] or 0) + 1
	end
	collecLine(string.format("COLLECTION (%d)", #c.cards), ACCENT, order, 24)
	order += 1
	for _, r in Config.Rarities do
		collecLine(string.format("%s : %d", r.name, counts[r.key] or 0), r.color, order, 20)
		order += 1
	end
	if c.unlockedSlots < c.maxSlots then
		collecLine(string.format("Emplacements débloqués : %d/%d (boutique)",
			c.unlockedSlots, c.maxSlots), Color3.fromRGB(200, 200, 215), order, 20)
	end
end)

-------------------------------------------------------------------------------
-- Toasts + feedback de tir.
-------------------------------------------------------------------------------
local function toast(text: string, color: Color3?)
	local t = make("TextLabel", {
		Size = UDim2.fromOffset(460, 46),
		Position = UDim2.new(0.5, -230, 0, 90),
		BackgroundColor3 = color or Color3.fromRGB(40, 44, 60),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold, TextScaled = true,
		Text = text, BackgroundTransparency = 0.1,
	}, gui)
	corner(t, 10)
	make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, t)
	task.delay(2.4, function()
		local tw = TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
		tw:Play()
		tw.Completed:Wait()
		t:Destroy()
	end)
end

rToast.OnClientEvent:Connect(function(msg) toast(msg) end)

-- Résultat des dés : la carte tirée, colorée par sa rareté.
rDiceResult.OnClientEvent:Connect(function(res)
	local r = Config.rarity(res.card.rarity)
	toast(string.format("🎲 %s — %s (×%s)", res.card.name, r.name, Config.abbreviate(r.mult)),
		r.color)
end)

rShotResult.OnClientEvent:Connect(function(res)
	local tier = res.tier and ("  •  " .. res.tier) or ""
	if res.best then tier ..= "  •  " .. res.best end
	if res.scored then
		toast(string.format("🎯 BUT ! %d touchés  •  +%s $ (x%d)%s",
			res.hits, Config.abbreviate(res.money), Config.Shot.scoreMultiplier, tier),
			Color3.fromRGB(60, 160, 90))
	elseif res.hits > 0 then
		toast(string.format("%d touchés  •  +%s $%s", res.hits, Config.abbreviate(res.money), tier),
			Color3.fromRGB(60, 90, 140))
	else
		toast("Raté… tourne-toi vers les figurines et relâche dans le vert !",
			Color3.fromRGB(120, 60, 60))
	end
end)

-------------------------------------------------------------------------------
-- MAJ des stats + libellés de la boutique.
-------------------------------------------------------------------------------
rStats.OnClientEvent:Connect(function(s)
	lblMoney.Text = "💰 " .. Config.abbreviate(s.money) .. " $"
	lblPower.Text = "💪 Puissance : " .. Config.abbreviate(s.power)
	lblRebirth.Text = "🔄 Renaissances : " .. s.rebirths
	lblMult.Text = "✖ Multiplicateur : x" .. Config.abbreviate(s.moneyMult)

	local db = upgradeButtons.dumbbell
	if s.nextDumbbell then
		db.Text = "Haltère → " .. s.nextDumbbell.name .. "\n" .. Config.abbreviate(s.nextDumbbell.cost) .. " $"
		db.BackgroundColor3 = s.money >= s.nextDumbbell.cost and Color3.fromRGB(70, 160, 90) or Color3.fromRGB(70, 130, 200)
	else
		db.Text = "Haltère MAX\n(" .. s.dumbbell.name .. ")"
		db.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
	end

	local bb = upgradeButtons.ball
	if s.nextBall then
		bb.Text = "Balle → " .. s.nextBall.name .. "\n" .. Config.abbreviate(s.nextBall.cost) .. " $"
		bb.BackgroundColor3 = s.money >= s.nextBall.cost and Color3.fromRGB(70, 160, 90) or Color3.fromRGB(70, 130, 200)
	else
		bb.Text = "Balle MAX\n(" .. s.ball.name .. ")"
		bb.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
	end

	local slotBtn = upgradeButtons.slot
	if s.slots >= s.maxSlots then
		slotBtn.Text = string.format("Emplacements MAX (%d/%d)", s.slots, s.maxSlots)
		slotBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
	else
		slotBtn.Text = string.format("+1 Emplacement (%d/%d)\n%s $",
			s.slots, s.maxSlots, Config.abbreviate(s.slotCost))
		slotBtn.BackgroundColor3 = s.money >= s.slotCost and Color3.fromRGB(70, 160, 90) or Color3.fromRGB(200, 150, 60)
	end

	diceBtn.Text = string.format("🎲 RECRUTER\n%s $", Config.abbreviate(s.diceCost))
	diceBtn.BackgroundColor3 = s.money >= s.diceCost and Color3.fromRGB(235, 170, 60) or Color3.fromRGB(120, 95, 55)
	squadLabel.Text = string.format("👥 Équipe %d/%d  •  Collection : %d",
		s.squadSize, s.maxSlots, s.cardsOwned)

	upgradeButtons.value.Text = string.format("Valeur joueur (+, act. %s $)\n%s $",
		Config.abbreviate(s.playerValue), Config.abbreviate(s.playerValueCost))
	upgradeButtons.value.BackgroundColor3 = s.money >= s.playerValueCost and Color3.fromRGB(70, 160, 90) or Color3.fromRGB(200, 150, 60)

	rebirthBtn.Text = string.format("🔄 Renaître → x%s\nCoût : %s $",
		Config.abbreviate(s.nextRebirthMult), Config.abbreviate(s.rebirthCost))
	rebirthBtn.BackgroundColor3 = s.money >= s.rebirthCost and Color3.fromRGB(255, 120, 200) or Color3.fromRGB(120, 80, 110)
end)

toast("⚽ Lance les 🎲 pour recruter tes joueurs, place-les sur les 4 bases (11 max), "
	.. "puis vise à la caméra et relâche la jauge dans le vert foncé !",
	Color3.fromRGB(50, 80, 120))
print("[BabyFoot] Client prêt.")
