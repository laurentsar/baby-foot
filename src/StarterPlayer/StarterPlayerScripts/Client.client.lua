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
local rAutoShoot = Remotes.get("AutoShoot")
local rAutoRoll = Remotes.get("AutoRoll")
local rGift = Remotes.get("Gift")
local rAdmin = Remotes.get("Admin")
local rRoster = Remotes.get("Roster")

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
-- Panneau de stats (argent, puissance, renaissances) : collé au bord gauche de
-- la boutique, qu'elle soit repliée ou ouverte (la boutique ouverte fait 320 de
-- large, pas seulement son bouton de 150 — l'ancrage tient compte des deux).
-------------------------------------------------------------------------------
local statsPanel = make("Frame", {
	Size = UDim2.fromOffset(260, 130),
	Position = UDim2.new(1, -612, 0, 16),
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

-- L'angle se recalcule à chaque frame (c'est lui qu'on tire), mais l'étiquette
-- ne se réécrit que si son texte change vraiment : un TextLabel en TextScaled
-- relance une passe de mise en page à chaque affectation, et 60 par seconde
-- pour afficher le même degré, c'est de la batterie brûlée pour rien.
local lastAimText = ""

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
	local text = string.format("VISÉE %s %d°%s", arrow, math.floor(aimAngle + 0.5), capped)
	if text ~= lastAimText then
		lastAimText = text
		aimLabel.Text = text
		aimLabel.TextColor3 = if capped == "" then ACCENT else Color3.fromRGB(255, 150, 90)
	end
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
local lastTier = nil  -- palier affiché, pour ne repeindre la jauge qu'au changement

shootBtn.MouseButton1Down:Connect(function()
	charging = true
	charge = 0
	chargeUp = true
	lastTier = nil
	-- Le serveur horodate l'appui : c'est ce qui lui permet de vérifier que la
	-- charge annoncée au moment du tir correspond bien à la durée de maintien.
	rChargeStart:FireServer()
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
		-- Même vitesse que Config.chargeAt côté serveur : les deux jauges doivent
		-- rester identiques, sinon le contrôle anti-triche rejetterait des tirs
		-- honnêtes.
		if chargeUp then
			charge += dt * Config.ChargeRate
			if charge >= 1 then charge = 1; chargeUp = false end
		else
			charge -= dt * Config.ChargeRate
			if charge <= 0 then charge = 0; chargeUp = true end
		end
		-- La barre suit la charge à chaque frame (c'est le geste du joueur), mais
		-- couleur et libellé ne changent qu'aux frontières de palier : les
		-- réécrire 60 fois par seconde ne changeait rien à l'écran.
		local tier = Config.chargeTier(charge)
		chargeFill.Size = UDim2.new(charge, 0, 1, 0)
		if tier ~= lastTier then
			lastTier = tier
			chargeFill.BackgroundColor3 = tier.color
			chargeLabel.Text = tier.label
			chargeLabel.TextColor3 = tier.color
		end
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
-- Plus de bouton « emplacement » : l'équipe est complète dès le départ, on
-- améliore la valeur des joueurs et on remplace les Communs aux dés.
shopHeader("⚽ ÉQUIPE", 4, GOLD)
upgradeButton("value", 6)
shopHeader("🔄 RENAISSANCE", 7, Color3.fromRGB(255, 120, 200))
local rebirthBtn = button("…", Color3.fromRGB(255, 120, 200), shopScroll)
rebirthBtn.Size = UDim2.new(1, 0, 0, 54); rebirthBtn.TextSize = 16; rebirthBtn.LayoutOrder = 8
rebirthBtn.MouseButton1Click:Connect(function() rRebirth:FireServer() end)

shopHeader("💎 GAME PASSES (Robux)", 9, Color3.fromRGB(180, 130, 255))
local passOrder = 10
for key, pass in Config.Passes do
	-- Une passe sans ID ne peut pas être achetée : on l'affiche grisée plutôt
	-- que de laisser cliquer sur un achat qui échoue.
	local ready = pass.id ~= 0
	local b = button(pass.label .. (if ready then "  🟣" else "  ⚙️ à configurer"),
		if ready then Color3.fromRGB(150, 110, 235) else Color3.fromRGB(95, 95, 115), shopScroll)
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
-- MUSIQUE D'AMBIANCE : en boucle, côté client, avec bouton muet.
-- Dans SoundService et non dans le monde : une musique de fond ne doit pas
-- s'atténuer quand on s'éloigne du terrain.
-------------------------------------------------------------------------------
local musicOn = true
local music: Sound? = nil
if Config.Music.soundId ~= "" then
	music = Instance.new("Sound")
	;(music :: Sound).Name = "MusiqueAmbiance"
	;(music :: Sound).SoundId = Config.Music.soundId
	;(music :: Sound).Looped = true
	;(music :: Sound).Volume = Config.Music.volume
	;(music :: Sound).Parent = game:GetService("SoundService")
	;(music :: Sound):Play()
end

local musicBtn = button(if music then "🎵 MUSIQUE" else "🎵 à configurer",
	if music then Color3.fromRGB(120, 200, 200) else Color3.fromRGB(95, 95, 115), gui)
-- Coin haut-gauche : le panneau de stats (argent) a été déplacé contre la
-- boutique, à droite, ce qui libère ce coin pour la musique.
musicBtn.Size = UDim2.fromOffset(150, 32)
musicBtn.Position = UDim2.fromOffset(16, 16)
musicBtn.TextSize = 14
musicBtn.MouseButton1Click:Connect(function()
	if not music then return end
	musicOn = not musicOn
	;(music :: Sound).Volume = if musicOn then Config.Music.volume else 0
	musicBtn.Text = if musicOn then "🎵 MUSIQUE" else "🔇 COUPÉE"
end)

-------------------------------------------------------------------------------
-- DÉS + COLLECTION (colonne de gauche, sous les stats).
-- Les joueurs de foot s'obtiennent en lançant les dés ; les meilleurs sont
-- automatiquement placés sur les bases, dans la limite des emplacements.
-------------------------------------------------------------------------------
-- RECRUTER rétréci pour loger l'interrupteur du roulement auto à sa droite :
-- l'ensemble occupe la même largeur qu'avant (16 -> 216).
local diceBtn = button("🎲 RECRUTER", Color3.fromRGB(235, 170, 60), gui)
diceBtn.Size = UDim2.fromOffset(148, 62)
diceBtn.Position = UDim2.fromOffset(16, 156)
diceBtn.TextSize = 18
diceBtn.MouseButton1Click:Connect(function() rRoll:FireServer() end)

-- Roulement automatique : payant une fois, puis simple marche/arrêt. L'état
-- vient toujours du serveur — le clic ne fait qu'envoyer une intention.
local autoRollBtn = button("🔁", Color3.fromRGB(120, 130, 150), gui)
autoRollBtn.Size = UDim2.fromOffset(46, 62)
autoRollBtn.Position = UDim2.fromOffset(170, 156)
autoRollBtn.TextSize = 13
local autoRollOn = false
local autoRollOwned = false
autoRollBtn.MouseButton1Click:Connect(function()
	rAutoRoll:FireServer(not autoRollOn)
end)

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

-- Les panneaux de la colonne de gauche occupent tous le même rectangle : un seul
-- peut être ouvert à la fois, sinon ils se recouvrent.
local PANEL_RECT = { x = 16, y = 344, w = 320, h = 380 }
local panels: { Frame } = {}

local function sidePanel(stroke: Color3): Frame
	local p = make("Frame", {
		Size = UDim2.fromOffset(PANEL_RECT.w, PANEL_RECT.h),
		Position = UDim2.fromOffset(PANEL_RECT.x, PANEL_RECT.y),
		BackgroundColor3 = BG, BackgroundTransparency = 0.05,
		BorderSizePixel = 0, Visible = false,
	}, gui)
	corner(p, 14)
	make("UIStroke", { Color = stroke, Thickness = 1.5, Transparency = 0.4 }, p)
	table.insert(panels, p)
	return p
end

local function togglePanel(p: Frame)
	local show = not p.Visible
	for _, other in panels do
		other.Visible = false
	end
	p.Visible = show
end

local function panelScroll(parent: Frame): ScrollingFrame
	local s = make("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, parent)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, s)
	return s
end

local collecPanel = sidePanel(Color3.fromRGB(150, 110, 235))

local collecScroll = panelScroll(collecPanel)

collecToggle.MouseButton1Click:Connect(function() togglePanel(collecPanel) end)

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
-- INDEX / DONS / ADMIN : deuxième rangée de boutons, sous COLLECTION.
-------------------------------------------------------------------------------
local function rowButton(text: string, color: Color3, x: number, w: number): TextButton
	local b = button(text, color, gui)
	b.Size = UDim2.fromOffset(w, 36)
	b.Position = UDim2.fromOffset(x, 300)
	b.TextSize = 14
	return b
end

local indexToggle = rowButton("📕 INDEX", Color3.fromRGB(90, 180, 235), 16, 98)
local giftToggle = rowButton("🎁 DONS", Color3.fromRGB(235, 130, 170), 122, 98)
local adminToggle = rowButton("🛠 ADMIN", Color3.fromRGB(200, 200, 210), 228, 98)
adminToggle.Visible = false   -- réaffiché seulement pour un UserId de Config.Admins

-------------------------------------------------------------------------------
-- INDEX : le catalogue complet des joueurs recrutables, et ce qu'on en a.
--
-- Les 256 lignes sont créées une seule fois, à la première ouverture, puis
-- seulement mises à jour : les recréer à chaque recrutement ferait repasser une
-- mise en page complète du ScrollingFrame pour une ligne qui change.
-------------------------------------------------------------------------------
local indexPanel = sidePanel(Color3.fromRGB(90, 180, 235))
local indexScroll = panelScroll(indexPanel)
local indexRows: { [string]: TextLabel } = {}
local indexHeader: TextLabel? = nil
local lastIndex: { [string]: string } = {}

local function buildIndexRows()
	if indexHeader then return end
	indexHeader = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
		Text = "INDEX", Font = Enum.Font.GothamBlack, TextScaled = true,
		TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	}, indexScroll)
	for i, name in Config.catalogue() do
		indexRows[name] = make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
			Text = name, Font = Enum.Font.GothamBold, TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(90, 92, 105),
			LayoutOrder = i,
		}, indexScroll)
	end
end

local function refreshIndex()
	if not indexHeader then return end
	local owned = 0
	for name, row in indexRows do
		local rarityKey = lastIndex[name]
		if rarityKey then
			owned += 1
			local r = Config.rarity(rarityKey)
			row.Text = name .. "  —  " .. r.name
			row.TextColor3 = r.color
		else
			-- Jamais recruté : le nom reste caché, c'est ce qui donne envie de
			-- relancer les dés.
			row.Text = "???"
			row.TextColor3 = Color3.fromRGB(90, 92, 105)
		end
	end
	local total = Config.catalogueSize()
	;(indexHeader :: TextLabel).Text = string.format("INDEX  —  %d/%d (%d%%)",
		owned, total, math.floor(owned / total * 100))
end

indexToggle.MouseButton1Click:Connect(function()
	-- 258 lignes : refermer puis rouvrir en repartant du haut donne l'impression
	-- que l'index s'est remis a zero. On garde la position de defilement.
	local keep = indexScroll.CanvasPosition
	buildIndexRows()
	refreshIndex()
	togglePanel(indexPanel)
	if indexPanel.Visible then
		indexScroll.CanvasPosition = keep
	end
end)

-------------------------------------------------------------------------------
-- DONS : offrir de l'argent ou un joueur à quelqu'un du serveur.
-------------------------------------------------------------------------------
local giftPanel = sidePanel(Color3.fromRGB(235, 130, 170))
local giftScroll = panelScroll(giftPanel)
local giftTarget: number? = nil
local giftTargetName = ""
local roster: { any } = {}
local lastCards: { any } = {}

local function giftLine(text: string, color: Color3, order: number, height: number)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1,
		Text = text, Font = Enum.Font.GothamBold, TextScaled = true,
		TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	}, giftScroll)
end

local refreshGift  -- déclaré avant, les callbacks des boutons le rappellent

refreshGift = function()
	giftScroll:ClearAllChildren()
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, giftScroll)
	local order = 1

	giftLine("À QUI ?", GOLD, order, 22); order += 1
	local others = 0
	for _, entry in roster do
		if entry.userId ~= player.UserId then
			others += 1
			local selected = giftTarget == entry.userId
			local b = button(if selected then "✓ " .. entry.name else entry.name,
				if selected then Color3.fromRGB(120, 220, 140) else Color3.fromRGB(70, 74, 92), giftScroll)
			b.Size = UDim2.new(1, 0, 0, 32)
			b.TextSize = 14
			b.LayoutOrder = order
			b.TextColor3 = if selected then Color3.fromRGB(15, 15, 20) else Color3.fromRGB(235, 235, 245)
			b.MouseButton1Click:Connect(function()
				giftTarget = entry.userId
				giftTargetName = entry.name
				refreshGift()
			end)
			order += 1
		end
	end
	if others == 0 then
		giftLine("Personne d'autre sur le serveur.", Color3.fromRGB(180, 180, 200), order, 20)
		order += 1
		return
	end
	if not giftTarget then
		giftLine("Choisis un destinataire ci-dessus.", Color3.fromRGB(180, 180, 200), order, 20)
		return
	end

	giftLine("💰 ARGENT (max " .. math.floor(Config.Gift.maxShare * 100) .. "% du tien)",
		GOLD, order, 22)
	order += 1
	local amountBox = make("TextBox", {
		Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = PANEL,
		TextColor3 = Color3.fromRGB(240, 240, 250), Font = Enum.Font.GothamBold,
		TextScaled = true, PlaceholderText = "Montant…", Text = "",
		ClearTextOnFocus = false, BorderSizePixel = 0, LayoutOrder = order,
	}, giftScroll)
	corner(amountBox, 8)
	order += 1

	local sendMoney = button("OFFRIR À " .. string.upper(giftTargetName), Color3.fromRGB(235, 170, 60), giftScroll)
	sendMoney.Size = UDim2.new(1, 0, 0, 34)
	sendMoney.TextSize = 14
	sendMoney.LayoutOrder = order
	sendMoney.MouseButton1Click:Connect(function()
		local amount = tonumber(amountBox.Text)
		if not amount then return end
		rGift:FireServer({ to = giftTarget, kind = "money", amount = amount })
		amountBox.Text = ""
	end)
	order += 1

	giftLine("👤 UN JOUEUR DE TA COLLECTION", GOLD, order, 22); order += 1
	if #lastCards == 0 then
		giftLine("Collection vide.", Color3.fromRGB(180, 180, 200), order, 20)
		return
	end
	for i, card in lastCards do
		local r = Config.rarity(card.rarity)
		local b = button(card.name .. " — " .. r.name, Color3.fromRGB(70, 74, 92), giftScroll)
		b.Size = UDim2.new(1, 0, 0, 30)
		b.TextSize = 13
		b.TextColor3 = r.color
		b.LayoutOrder = order
		b.MouseButton1Click:Connect(function()
			-- L'index vaut pour la collection telle que le serveur l'a envoyée ;
			-- lui-même revérifie que la carte est bien là avant de la transférer.
			rGift:FireServer({ to = giftTarget, kind = "card", cardIndex = i })
		end)
		order += 1
	end
end

giftToggle.MouseButton1Click:Connect(function()
	refreshGift()
	togglePanel(giftPanel)
end)

rRoster.OnClientEvent:Connect(function(list)
	roster = list
	-- Le destinataire choisi vient peut-être de partir.
	local stillHere = false
	for _, e in roster do
		if e.userId == giftTarget then stillHere = true end
	end
	if not stillHere then giftTarget = nil end
	if giftPanel.Visible then refreshGift() end
end)

-------------------------------------------------------------------------------
-- ADMIN : s'attribuer argent, puissance et cartes. Le bouton n'apparaît que
-- pour les UserId de Config.Admins, et le serveur revérifie chaque commande.
-------------------------------------------------------------------------------
local adminPanel = sidePanel(Color3.fromRGB(200, 200, 210))
local adminScroll = panelScroll(adminPanel)

local function adminHeader(text: string, order: number)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
		Text = text, Font = Enum.Font.GothamBlack, TextScaled = true,
		TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	}, adminScroll)
end

local function adminBox(placeholder: string, order: number): TextBox
	local b = make("TextBox", {
		Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = PANEL,
		TextColor3 = Color3.fromRGB(240, 240, 250), Font = Enum.Font.GothamBold,
		TextScaled = true, PlaceholderText = placeholder, Text = "",
		ClearTextOnFocus = false, BorderSizePixel = 0, LayoutOrder = order,
	}, adminScroll)
	corner(b, 8)
	return b
end

adminHeader("💰 ARGENT / PUISSANCE", 1)
local adminAmount = adminBox("Montant (ex. 1e18)", 2)
local adminMoneyBtn = button("+ ARGENT", Color3.fromRGB(235, 170, 60), adminScroll)
adminMoneyBtn.Size = UDim2.new(1, 0, 0, 32); adminMoneyBtn.TextSize = 14; adminMoneyBtn.LayoutOrder = 3
adminMoneyBtn.MouseButton1Click:Connect(function()
	local a = tonumber(adminAmount.Text)
	if a then rAdmin:FireServer({ kind = "money", amount = a }) end
end)
local adminPowerBtn = button("+ PUISSANCE", Color3.fromRGB(120, 200, 120), adminScroll)
adminPowerBtn.Size = UDim2.new(1, 0, 0, 32); adminPowerBtn.TextSize = 14; adminPowerBtn.LayoutOrder = 4
adminPowerBtn.MouseButton1Click:Connect(function()
	local a = tonumber(adminAmount.Text)
	if a then rAdmin:FireServer({ kind = "power", amount = a }) end
end)

adminHeader("👤 CARTES", 5)
local adminCount = adminBox("Combien ? (1-50)", 6)
local adminName = adminBox("Nom précis (vide = au hasard)", 7)
local adminOrder = 8
for _, r in Config.Rarities do
	local b = button("+ " .. string.upper(r.name), r.color, adminScroll)
	b.Size = UDim2.new(1, 0, 0, 30); b.TextSize = 13; b.LayoutOrder = adminOrder
	b.MouseButton1Click:Connect(function()
		rAdmin:FireServer({
			kind = "card",
			rarity = r.key,
			count = tonumber(adminCount.Text) or 1,
			name = adminName.Text,
		})
	end)
	adminOrder += 1
end

adminToggle.MouseButton1Click:Connect(function() togglePanel(adminPanel) end)

-------------------------------------------------------------------------------
-- TIR AUTOMATIQUE : interrupteur au-dessus du bouton TIRER.
-------------------------------------------------------------------------------
local autoBtn = button("🤖 AUTO", Color3.fromRGB(120, 130, 150), bottom)
autoBtn.Size = UDim2.fromOffset(200, 32)
autoBtn.Position = UDim2.new(1, -224, 0, 4)
autoBtn.TextSize = 15
autoBtn.Visible = false
local autoOn = false
autoBtn.MouseButton1Click:Connect(function()
	rAutoShoot:FireServer(not autoOn)
end)

-- Deuxième abonnement à Collection : le premier (plus haut) remplit le panneau
-- COLLECTION, celui-ci alimente l'index et la liste de cartes offrables. Les
-- séparer évite de mélanger deux affichages sans rapport dans un seul callback.
rCollection.OnClientEvent:Connect(function(c)
	lastIndex = c.index or {}
	lastCards = c.cards or {}
	if indexPanel.Visible then refreshIndex() end
	if giftPanel.Visible then refreshGift() end
end)

-------------------------------------------------------------------------------
-- Toasts + feedback de tir.
-------------------------------------------------------------------------------
local function toast(text: string, color: Color3?)
	local t = make("TextLabel", {
		Size = UDim2.fromOffset(460, 46),
		-- Sous le panneau de stats (16 + 130), qu'il recouvrait sur les écrans
		-- étroits : le bandeau masquait renaissances et multiplicateur.
		Position = UDim2.new(0.5, -230, 0, 160),
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

	diceBtn.Text = string.format("🎲 RECRUTER\n%s $", Config.abbreviate(s.diceCost))
	diceBtn.BackgroundColor3 = s.money >= s.diceCost and Color3.fromRGB(235, 170, 60) or Color3.fromRGB(120, 95, 55)

	-- Tant qu'il n'est pas acheté, le bouton affiche son PRIX : c'est ce qui dit
	-- au joueur que le premier clic est un achat et pas un simple interrupteur.
	autoRollOn = s.autoRollOn == true
	autoRollOwned = s.autoRollOwned == true
	if not autoRollOwned then
		autoRollBtn.Text = "🔁\n" .. Config.abbreviate(s.autoRollCost or 0) .. " $"
		autoRollBtn.BackgroundColor3 = s.money >= (s.autoRollCost or 0)
			and Color3.fromRGB(200, 160, 90) or Color3.fromRGB(110, 100, 85)
	else
		autoRollBtn.Text = if autoRollOn then "🔁\nON" else "🔁\nOFF"
		autoRollBtn.BackgroundColor3 = if autoRollOn
			then Color3.fromRGB(90, 220, 140) else Color3.fromRGB(120, 130, 150)
	end
	squadLabel.Text = string.format("👥 Équipe %d/%d  •  Collection : %d",
		s.squadSize, s.maxSlots, s.cardsOwned)

	upgradeButtons.value.Text = string.format("Valeur joueur (+, act. %s $)\n%s $",
		Config.abbreviate(s.playerValue), Config.abbreviate(s.playerValueCost))
	upgradeButtons.value.BackgroundColor3 = s.money >= s.playerValueCost and Color3.fromRGB(70, 160, 90) or Color3.fromRGB(200, 150, 60)

	rebirthBtn.Text = string.format("🔄 Renaître → x%s\nCoût : %s $",
		Config.abbreviate(s.nextRebirthMult), Config.abbreviate(s.rebirthCost))
	rebirthBtn.BackgroundColor3 = s.money >= s.rebirthCost and Color3.fromRGB(255, 120, 200) or Color3.fromRGB(120, 80, 110)

	-- Tir automatique : le bouton n'apparaît qu'une fois débloqué (passe Robux ou
	-- seuil d'argent cumulé), et son état vient du serveur, jamais du clic local.
	autoOn = s.autoShootOn == true
	autoBtn.Visible = s.autoShootUnlocked == true
	autoBtn.Text = if autoOn then "🤖 AUTO : ON" else "🤖 AUTO : OFF"
	autoBtn.BackgroundColor3 = if autoOn then Color3.fromRGB(90, 220, 140) else Color3.fromRGB(120, 130, 150)

	adminToggle.Visible = s.isAdmin == true
end)

toast("⚽ Lance les 🎲 pour recruter tes joueurs, place-les sur les 4 bases (11 max), "
	.. "puis vise à la caméra et relâche la jauge dans le vert foncé !",
	Color3.fromRGB(50, 80, 120))
print("[BabyFoot] Client prêt.")
