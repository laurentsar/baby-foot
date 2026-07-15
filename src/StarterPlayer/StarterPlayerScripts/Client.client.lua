--!strict
-- Client Baby-Foot Power : interface d'entraînement, visée, tir chargé, boutique, passes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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
local rStats = Remotes.get("StatsUpdate")
local rShotResult = Remotes.get("ShotResult")
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

-- Zone de visée (centre)
local aimFrame = make("Frame", {
	Size = UDim2.fromOffset(360, 60),
	Position = UDim2.new(0.5, -180, 0, 8),
	BackgroundColor3 = PANEL,
	BorderSizePixel = 0,
}, bottom)
corner(aimFrame, 10)
make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
	Text = "VISÉE  ◄ ►", Font = Enum.Font.GothamBold, TextScaled = true,
	TextColor3 = ACCENT,
}, aimFrame)

-- Slider de visée
local sliderTrack = make("Frame", {
	Size = UDim2.new(1, -24, 0, 10), Position = UDim2.new(0, 12, 0, 34),
	BackgroundColor3 = Color3.fromRGB(60, 64, 80), BorderSizePixel = 0,
}, aimFrame)
corner(sliderTrack, 5)
local sliderKnob = make("Frame", {
	Size = UDim2.fromOffset(22, 22), Position = UDim2.new(0.5, -11, 0.5, -6),
	BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 2,
}, sliderTrack)
corner(sliderKnob, 11)

local aimAngle = 0 -- -55..55
local draggingSlider = false

local function setAimFromX(px: number)
	local abs = sliderTrack.AbsolutePosition.X
	local w = sliderTrack.AbsoluteSize.X
	local t = math.clamp((px - abs) / w, 0, 1)
	aimAngle = (t - 0.5) * 110 -- -55..55
	sliderKnob.Position = UDim2.new(t, -11, 0.5, -6)
end

sliderTrack.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		draggingSlider = true
		setAimFromX(input.Position.X)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		setAimFromX(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		draggingSlider = false
	end
end)

-- Bouton TIR + jauge de charge (droite)
local shootBtn = button("⚽ TIRER", ACCENT, bottom)
shootBtn.Size = UDim2.fromOffset(200, 90)
shootBtn.Position = UDim2.new(1, -224, 0, 40)
shootBtn.TextSize = 30

local chargeTrack = make("Frame", {
	Size = UDim2.fromOffset(200, 14), Position = UDim2.new(1, -224, 0, 135),
	BackgroundColor3 = PANEL, BorderSizePixel = 0,
}, bottom)
corner(chargeTrack, 7)
local chargeFill = make("Frame", {
	Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = GOLD, BorderSizePixel = 0,
}, chargeTrack)
corner(chargeFill, 7)

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
	rShoot:FireServer(aimAngle, charge)
	charge = 0
	chargeFill.Size = UDim2.new(0, 0, 1, 0)
end
shootBtn.MouseButton1Up:Connect(fireShot)
shootBtn.MouseLeave:Connect(function()
	if charging then fireShot() end
end)

RunService.RenderStepped:Connect(function(dt)
	if charging then
		-- va-et-vient de la jauge : relâche au bon moment pour un tir max.
		if chargeUp then
			charge += dt * 1.4
			if charge >= 1 then charge = 1; chargeUp = false end
		else
			charge -= dt * 1.4
			if charge <= 0 then charge = 0; chargeUp = true end
		end
		chargeFill.Size = UDim2.new(charge, 0, 1, 0)
		chargeFill.BackgroundColor3 = charge > 0.8 and Color3.fromRGB(120, 255, 120) or GOLD
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
shopHeader("⚽ FIGURINES", 4, GOLD)
upgradeButton("count", 5)
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

rShotResult.OnClientEvent:Connect(function(res)
	if res.scored then
		toast(string.format("🎯 BUT ! %d touchés  •  +%s $ (x%d)",
			res.hits, Config.abbreviate(res.money), Config.Shot.scoreMultiplier),
			Color3.fromRGB(60, 160, 90))
	elseif res.hits > 0 then
		toast(string.format("%d touchés  •  +%s $", res.hits, Config.abbreviate(res.money)),
			Color3.fromRGB(60, 90, 140))
	else
		toast("Raté… vise mieux et charge plus fort !", Color3.fromRGB(120, 60, 60))
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

	local capTxt = s.playerCountCap == -1 and "∞" or tostring(s.playerCountCap)
	upgradeButtons.count.Text = string.format("+1 Figurine (%d, max %s)\n%s $",
		s.playerCount, capTxt, Config.abbreviate(s.playerCountCost))
	upgradeButtons.count.BackgroundColor3 = s.money >= s.playerCountCost and Color3.fromRGB(70, 160, 90) or Color3.fromRGB(200, 150, 60)

	upgradeButtons.value.Text = string.format("Valeur figurine (+, act. %s $)\n%s $",
		Config.abbreviate(s.playerValue), Config.abbreviate(s.playerValueCost))
	upgradeButtons.value.BackgroundColor3 = s.money >= s.playerValueCost and Color3.fromRGB(70, 160, 90) or Color3.fromRGB(200, 150, 60)

	rebirthBtn.Text = string.format("🔄 Renaître → x%s\nCoût : %s $",
		Config.abbreviate(s.nextRebirthMult), Config.abbreviate(s.rebirthCost))
	rebirthBtn.BackgroundColor3 = s.money >= s.rebirthCost and Color3.fromRGB(255, 120, 200) or Color3.fromRGB(120, 80, 110)
end)

toast("⚽ Entraîne-toi aux haltères, puis charge ton tir et marque au fond pour le x3 !", Color3.fromRGB(50, 80, 120))
print("[BabyFoot] Client prêt.")
