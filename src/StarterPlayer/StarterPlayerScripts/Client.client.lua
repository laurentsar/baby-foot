--!strict
-- Client Baby-Foot Power : interface d'entraînement, visée, tir chargé, boutique, passes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HapticService = game:GetService("HapticService")

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
local rErase = Remotes.get("EraseData")
local rUsePotion = Remotes.get("UsePotion")
local rTutorial = Remotes.get("Tutorial")
local rChallenge = Remotes.get("Challenge")
local rReleaseSeen = Remotes.get("ReleaseSeen")
local rWorld = Remotes.get("World")
local rPet = Remotes.get("Pet")
local rEgg = Remotes.get("Egg")
local rPetResult = Remotes.get("PetResult")
local rLineup = Remotes.get("Lineup")
local rSpectate = Remotes.get("Spectate")
local rAfk = Remotes.get("Afk")

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

-- Multiplicateurs : Config.abbreviate arrondit à l'entier en dessous de 1000
-- (« x1.5 » devenait « x1 »), ce qui est juste pour de l'argent et faux pour une
-- chance. On garde donc une décimale tant que le nombre est petit.
local function fmtMult(n: number): string
	if n ~= n then return "?" end
	if n < 1000 then
		return if n % 1 == 0 then tostring(math.floor(n)) else string.format("%.1f", n)
	end
	return Config.abbreviate(n)
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
-- MAINTIEN D'UN BOUTON, TACTILE COMPRIS.
--
-- MouseButton1Down/Up/MouseLeave sont pensés pour une souris et se comportent
-- mal au doigt : MouseLeave se déclenche dès que le doigt glisse un peu, ce qui
-- lâchait le tir tout seul, et deux doigts sur l'écran laissaient l'état de
-- charge incohérent.
--
-- On suit donc l'InputObject lui-même : seul le doigt (ou le clic) qui a
-- COMMENCÉ le maintien peut y mettre fin. La fin est écoutée deux fois — sur le
-- bouton et globalement — parce qu'un doigt relâché en dehors du bouton ne
-- déclenche pas toujours InputEnded sur celui-ci.
-------------------------------------------------------------------------------
local function onHold(btn: GuiObject, began: () -> (), ended: () -> ())
	local active: InputObject? = nil

	local function stop(input: InputObject)
		if active ~= input then return end
		active = nil
		ended()
	end

	btn.InputBegan:Connect(function(input)
		if active then return end   -- un seul doigt à la fois sur ce bouton
		local t = input.UserInputType
		if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
		active = input
		began()
	end)

	btn.InputEnded:Connect(stop)
	UserInputService.InputEnded:Connect(stop)
end

-------------------------------------------------------------------------------
-- RETOUR HAPTIQUE.
--
-- ATTENTION : Roblox n'expose AUCUNE API de vibration pour les écrans tactiles.
-- HapticService ne pilote que les manettes. Sur téléphone sans manette, ces
-- appels ne font donc rien — c'est une limite de la plateforme, pas un oubli.
-- Le code est écrit pour ne jamais coûter cher quand rien ne répond.
-------------------------------------------------------------------------------
local hapticPad = Enum.UserInputType.Gamepad1

-- Reponse mise en cache : le palier de charge peut vibrer plusieurs fois par
-- seconde, on ne va pas reinterroger le service a chaque impulsion. Le cache est
-- invalide au branchement ou au debranchement d'une manette.
local vibrateOk: boolean? = nil

local function canVibrate(): boolean
	if vibrateOk == nil then
		local ok, supported = pcall(function()
			return HapticService:IsVibrationSupported(hapticPad)
				and HapticService:IsMotorSupported(hapticPad, Enum.VibrationMotor.Large)
		end)
		vibrateOk = ok and supported == true
	end
	return vibrateOk == true
end

UserInputService.GamepadConnected:Connect(function() vibrateOk = nil end)
UserInputService.GamepadDisconnected:Connect(function() vibrateOk = nil end)

local function buzz(strength: number, duration: number)
	if not canVibrate() then return end
	pcall(function()
		HapticService:SetMotor(hapticPad, Enum.VibrationMotor.Large, math.clamp(strength, 0, 1))
	end)
	task.delay(duration, function()
		pcall(function()
			HapticService:SetMotor(hapticPad, Enum.VibrationMotor.Large, 0)
		end)
	end)
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
-- MISE À L'ÉCHELLE MOBILE.
--
-- Toute l'interface est dessinée en pixels fixes, calée sur un écran de 720 de
-- haut. Sur un téléphone le viewport fait bien moins, et les blocs se
-- chevauchaient : les panneaux mordaient sur les boutons du bas, le bandeau de
-- stats passait sous la barre Roblox.
--
-- Plutôt que de replacer chaque élément, on dessine TOUT dans un conteneur en
-- « unités de dessin » et on le réduit d'un coup. Le conteneur est
-- volontairement dimensionné à l'inverse de l'échelle : une fois le UIScale
-- appliqué, il recouvre exactement l'écran, donc les ancrages à droite et en
-- bas (UDim2.new(1, -224, …)) restent justes.
-------------------------------------------------------------------------------
local DESIGN_H = 720

local ui = make("Frame", {
	Name = "Root",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, gui)
local uiScale = make("UIScale", { Scale = 1 }, ui)

local function fitToScreen()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local v = cam.ViewportSize
	if v.Y <= 0 then return end
	-- Jamais d'agrandissement au-delà de 1 : sur grand écran, le dessin d'origine
	-- est déjà à la bonne taille, l'étirer ne ferait que le rendre grossier.
	local s = math.clamp(v.Y / DESIGN_H, 0.45, 1)
	uiScale.Scale = s
	ui.Size = UDim2.fromOffset(v.X / s, v.Y / s)
end

fitToScreen()
do
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)
	end
	-- La caméra est remplacée au respawn : on se rebranche sur la nouvelle.
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local c = workspace.CurrentCamera
		if c then c:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen) end
		fitToScreen()
	end)
end

-------------------------------------------------------------------------------
-- Panneau de stats (argent, puissance, renaissances) : collé au bord gauche de
-- la boutique, qu'elle soit repliée ou ouverte (la boutique ouverte fait 320 de
-- large, pas seulement son bouton de 150 — l'ancrage tient compte des deux).
-------------------------------------------------------------------------------
local statsPanel = make("Frame", {
	Size = UDim2.fromOffset(260, 130),
	Position = UDim2.new(1, -612, 0, 52),
	BackgroundColor3 = BG,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
}, ui)
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
}, ui)

-- Bouton ENTRAÎNEMENT (gauche)
local trainBtn = button("🏋️ S'ENTRAÎNER", GOLD, bottom)
trainBtn.Size = UDim2.fromOffset(200, 90)
trainBtn.Position = UDim2.new(0, 24, 0, 40)
trainBtn.TextSize = 28

-- MODE AFK : la puissance monte toute seule, un peu moins vite qu'à la main.
-- Sous le bouton d'entraînement, parce que c'est le même geste qu'on remplace.
local afkBtn = button("💤 AFK : OFF", Color3.fromRGB(120, 130, 150), bottom)
afkBtn.Size = UDim2.fromOffset(200, 32)
afkBtn.Position = UDim2.new(0, 24, 0, 4)
afkBtn.TextSize = 14
local afkOn = false
afkBtn.MouseButton1Click:Connect(function()
	rAfk:FireServer(not afkOn)
end)

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

local function startCharge()
	charging = true
	charge = 0
	chargeUp = true
	lastTier = nil
	-- Le serveur horodate l'appui : c'est ce qui lui permet de vérifier que la
	-- charge annoncée au moment du tir correspond bien à la durée de maintien.
	rChargeStart:FireServer()
end

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
onHold(shootBtn, startCharge, fireShot)

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
			-- Vibration seulement en MONTANT : la jauge fait des allers-retours,
			-- buzzer aussi à la descente donnerait un signal ininterrompu.
			local montait = lastTier ~= nil and chargeUp
			lastTier = tier
			chargeFill.BackgroundColor3 = tier.color
			chargeLabel.Text = tier.label
			chargeLabel.TextColor3 = tier.color
			if montait then buzz(0.35, 0.06) end
		end
	end
end)

-- Entraînement : clic = 1 rep, maintien = reps auto.
local training = false
onHold(trainBtn,
	function() training = true; rTrain:FireServer() end,
	function() training = false end)
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
local shopToggle = button("🛒 BOUTIQUE", Color3.fromRGB(120, 200, 120), ui)
shopToggle.Size = UDim2.fromOffset(150, 44)
shopToggle.Position = UDim2.new(1, -166, 0, 52)
shopToggle.TextSize = 20

local shop = make("Frame", {
	Size = UDim2.fromOffset(320, 520),
	Position = UDim2.new(1, -336, 0, 106),
	BackgroundColor3 = BG,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	Visible = false,
}, ui)
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
upgradeButton("value", 5)
-- CHANCE : améliore ce que les dés sortent. Plafonnée à x5 côté serveur, le x20
-- est une passe Robux à part (Config.LuckPassMultiplier).
upgradeButton("luck", 6)
-- MONDES : un bouton par monde. Le même bouton sert à débloquer (tant qu'on ne
-- l'a pas) puis à s'y téléporter — c'est le libellé qui change, pas la place,
-- sinon les boutons dansent d'une mise à jour de stats à l'autre.
shopHeader("🌍 MONDES", 7, Color3.fromRGB(150, 220, 150))
local worldButtons: { TextButton } = {}
for i in Config.Worlds do
	local b = button("…", Color3.fromRGB(80, 130, 90), shopScroll)
	b.Size = UDim2.new(1, 0, 0, 50)
	b.TextSize = 14
	b.LayoutOrder = 7 + i
	b.MouseButton1Click:Connect(function()
		-- Le serveur tranche : si le monde n'est pas débloqué, « go » est refusé
		-- et c'est « buy » qu'il faut envoyer. Le client sait lequel grâce aux
		-- stats, mais ne décide de rien.
		if worldButtons[i]:GetAttribute("Unlocked") then
			rWorld:FireServer({ kind = "go", index = i })
		else
			rWorld:FireServer({ kind = "buy" })
		end
	end)
	worldButtons[i] = b
end

-- ŒUFS : les trois œufs du monde où l'on se trouve. La plateforme in-game fait
-- la même chose (on clique l'œuf), c'est le même chemin serveur — ce raccourci
-- évite de traverser le stade quand on enchaîne les ouvertures.
shopHeader("🥚 ŒUFS À PETS", 11, Color3.fromRGB(255, 190, 120))
local eggButtons: { TextButton } = {}
for i = 1, 3 do
	local b = button("…", Color3.fromRGB(200, 150, 90), shopScroll)
	b.Size = UDim2.new(1, 0, 0, 50)
	b.TextSize = 14
	b.LayoutOrder = 11 + i
	b.MouseButton1Click:Connect(function()
		local key = b:GetAttribute("EggKey")
		if typeof(key) == "string" and key ~= "" then rEgg:FireServer(key) end
	end)
	eggButtons[i] = b
end

shopHeader("🔄 RENAISSANCE", 15, Color3.fromRGB(255, 120, 200))
local rebirthBtn = button("…", Color3.fromRGB(255, 120, 200), shopScroll)
rebirthBtn.Size = UDim2.new(1, 0, 0, 54); rebirthBtn.TextSize = 16; rebirthBtn.LayoutOrder = 16
rebirthBtn.MouseButton1Click:Connect(function() rRebirth:FireServer() end)

shopHeader("💎 GAME PASSES (Robux)", 17, Color3.fromRGB(180, 130, 255))
local passOrder = 18
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
-- DROIT À L'OUBLI (RGPD) : le serveur savait le faire depuis toujours, mais plus
-- aucun bouton ne l'appelait — la fonctionnalité était devenue inatteignable.
-- Deux clics : le premier prévient, le second (dans les 30 s) supprime.
-------------------------------------------------------------------------------
-- Le bouton n'efface RIEN : il ouvre une fenêtre. Un bouton de suppression
-- directement cliquable au milieu de la boutique, ça finit par partir tout seul —
-- et ici « partir » veut dire être éjecté du jeu, données perdues.
local eraseDim = make("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.5, BorderSizePixel = 0, Visible = false, ZIndex = 70,
}, ui)

local eraseCard = make("Frame", {
	Size = UDim2.fromOffset(430, 200), Position = UDim2.new(0.5, -215, 0.5, -100),
	BackgroundColor3 = BG, BorderSizePixel = 0, ZIndex = 71,
}, eraseDim)
corner(eraseCard, 16)
make("UIStroke", { Color = Color3.fromRGB(220, 90, 90), Thickness = 2, Transparency = 0.2 }, eraseCard)

local eraseText = make("TextLabel", {
	Size = UDim2.new(1, -32, 0, 110), Position = UDim2.fromOffset(16, 14),
	BackgroundTransparency = 1, Text = "", Font = Enum.Font.Gotham,
	TextSize = 15, TextWrapped = true, TextColor3 = Color3.fromRGB(240, 232, 232),
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 72,
}, eraseCard)

local eraseCancel = button("ANNULER", Color3.fromRGB(90, 94, 112), eraseCard)
eraseCancel.Size = UDim2.fromOffset(150, 36)
eraseCancel.Position = UDim2.fromOffset(16, 146)
eraseCancel.TextSize = 14
eraseCancel.TextColor3 = Color3.fromRGB(240, 240, 250)
eraseCancel.ZIndex = 72

local eraseGo = button("", Color3.fromRGB(200, 70, 70), eraseCard)
eraseGo.Size = UDim2.fromOffset(230, 36)
eraseGo.Position = UDim2.fromOffset(184, 146)
eraseGo.TextSize = 13
eraseGo.TextColor3 = Color3.fromRGB(255, 240, 240)
eraseGo.ZIndex = 72

-- Deux étapes, calquées sur le serveur (qui exige lui aussi deux appels dans sa
-- fenêtre de confirmation) : rien n'est supprimé au premier clic.
local eraseStep = 1

local function showErase(step: number)
	eraseStep = step
	if step == 1 then
		eraseText.Text = "🗑 Supprimer TOUTES tes données de jeu : argent, puissance,"
			.. " renaissances, collection, pets et potions.\n\nC'est définitif, et tu seras"
			.. " déconnecté juste après. Tu pourras revenir, mais tout repartira de zéro."
		eraseGo.Text = "CONTINUER…"
	else
		eraseText.Text = "⚠️ DERNIÈRE CHANCE.\n\nAu prochain clic, tes données sont effacées"
			.. " et tu quittes la partie. Il n'y a pas de retour en arrière."
		eraseGo.Text = "OUI, TOUT SUPPRIMER"
	end
end

eraseCancel.MouseButton1Click:Connect(function()
	eraseDim.Visible = false
	showErase(1)
end)

eraseGo.MouseButton1Click:Connect(function()
	-- Chaque clic envoie l'intention au serveur : le premier l'arme, le second
	-- exécute. La fenêtre de 30 s côté serveur reste le garde-fou final.
	rErase:FireServer()
	if eraseStep == 1 then
		showErase(2)
	else
		eraseDim.Visible = false
		showErase(1)
	end
end)

local eraseBtn = button("🗑 Supprimer mes données (RGPD)", Color3.fromRGB(120, 70, 70), shopScroll)
eraseBtn.Size = UDim2.new(1, 0, 0, 36)
eraseBtn.TextSize = 12
eraseBtn.TextColor3 = Color3.fromRGB(255, 235, 235)
eraseBtn.LayoutOrder = passOrder + 10
eraseBtn.MouseButton1Click:Connect(function()
	showErase(1)
	eraseDim.Visible = true
end)

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
	if music then Color3.fromRGB(120, 200, 200) else Color3.fromRGB(95, 95, 115), ui)
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
local diceBtn = button("🎲 RECRUTER", Color3.fromRGB(235, 170, 60), ui)
diceBtn.Size = UDim2.fromOffset(148, 62)
diceBtn.Position = UDim2.fromOffset(16, 52)
diceBtn.TextSize = 18
diceBtn.MouseButton1Click:Connect(function() rRoll:FireServer() end)

-- Roulement automatique : payant une fois, puis simple marche/arrêt. L'état
-- vient toujours du serveur — le clic ne fait qu'envoyer une intention.
local autoRollBtn = button("🔁", Color3.fromRGB(120, 130, 150), ui)
autoRollBtn.Size = UDim2.fromOffset(46, 62)
autoRollBtn.Position = UDim2.fromOffset(170, 52)
autoRollBtn.TextSize = 13
local autoRollOn = false
local autoRollOwned = false
autoRollBtn.MouseButton1Click:Connect(function()
	rAutoRoll:FireServer(not autoRollOn)
end)

local squadLabel = make("TextLabel", {
	Size = UDim2.fromOffset(230, 22), Position = UDim2.fromOffset(16, 118),
	BackgroundTransparency = 1, Text = "👥 Équipe 0/11",
	Font = Enum.Font.GothamBold, TextScaled = true,
	TextColor3 = Color3.fromRGB(220, 224, 240),
	TextXAlignment = Enum.TextXAlignment.Left,
}, ui)

local collecToggle = button("👥 COLLECTION", Color3.fromRGB(150, 110, 235), ui)
collecToggle.Size = UDim2.fromOffset(200, 40)
collecToggle.Position = UDim2.fromOffset(16, 144)
collecToggle.TextSize = 16

-- Les panneaux de la colonne de gauche occupent tous le même rectangle : un seul
-- peut être ouvert à la fois, sinon ils se recouvrent.
-- Bornes calculees pour que les panneaux ne mordent JAMAIS sur les commandes
-- du bas : celles-ci occupent les 170 dernieres unites de dessin (720 - 170 =
-- 550), et le panneau s'arrete a 546.
local PANEL_RECT = { x = 16, y = 232, w = 320, h = 314 }
local panels: { Frame } = {}

local function sidePanel(stroke: Color3): Frame
	local p = make("Frame", {
		Size = UDim2.fromOffset(PANEL_RECT.w, PANEL_RECT.h),
		Position = UDim2.fromOffset(PANEL_RECT.x, PANEL_RECT.y),
		BackgroundColor3 = BG, BackgroundTransparency = 0.05,
		BorderSizePixel = 0, Visible = false,
	}, ui)
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

-- COMPOSITION D'ÉQUIPE.
--
-- Le panneau COLLECTION a deux modes : la liste (ce qu'on a) et la composition
-- (où on le met). Deux modes dans un panneau plutôt qu'un sixième bouton dans la
-- rangée, qui aurait rendu tous les libellés illisibles.
--
-- L'ordre des emplacements vient de Config.slotOrder, EXACTEMENT la même liste
-- que celle dont le serveur se sert pour poser les figurines : « mettre le
-- Mythique au gardien » met bien le Mythique au gardien.
local composeMode = false
local pickingSlot: number? = nil
local lastCollection: any = nil

local function refreshCollection()
	local c = lastCollection
	if not c then return end
	collecScroll:ClearAllChildren()
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, collecScroll)

	local order = 1

	local modeBtn = button(if composeMode then "◀ RETOUR À LA COLLECTION" else "✏️ COMPOSER L'ÉQUIPE",
		if composeMode then Color3.fromRGB(120, 130, 160) else Color3.fromRGB(120, 200, 140), collecScroll)
	modeBtn.Size = UDim2.new(1, 0, 0, 30)
	modeBtn.TextSize = 14
	modeBtn.LayoutOrder = order
	modeBtn.MouseButton1Click:Connect(function()
		composeMode = not composeMode
		pickingSlot = nil
		refreshCollection()
	end)
	order += 1

	if composeMode then
		local slots = Config.slotOrder(c.extraSlots or 0)

		if pickingSlot then
			local entry = slots[pickingSlot]
			collecLine(string.format("QUI JOUE À L'EMPLACEMENT %d (%s) ?", pickingSlot,
				entry and entry.base or "?"), GOLD, order, 24)
			order += 1

			local libre = button("— Laisser le placement automatique —", Color3.fromRGB(90, 94, 112), collecScroll)
			libre.Size = UDim2.new(1, 0, 0, 28)
			libre.TextSize = 13
			libre.TextColor3 = Color3.fromRGB(235, 235, 245)
			libre.LayoutOrder = order
			libre.MouseButton1Click:Connect(function()
				rLineup:FireServer({ slot = pickingSlot })
				pickingSlot = nil
			end)
			order += 1

			-- Les meilleures cartes d'abord : c'est celles qu'on veut poser.
			local cards = table.clone(c.cards or {})
			table.sort(cards, function(a, b)
				local ma, mb = Config.rarity(a.rarity).mult, Config.rarity(b.rarity).mult
				if ma == mb then return (a.name or "") < (b.name or "") end
				return ma > mb
			end)
			for _, card in cards do
				local r = Config.rarity(card.rarity)
				local b = button(string.format("%s — %s ×%s", card.name, r.name, Config.abbreviate(r.mult)),
					Color3.fromRGB(70, 74, 92), collecScroll)
				b.Size = UDim2.new(1, 0, 0, 28)
				b.TextSize = 13
				b.TextColor3 = r.color
				b.LayoutOrder = order
				b.MouseButton1Click:Connect(function()
					rLineup:FireServer({ slot = pickingSlot, cardId = card.id })
					pickingSlot = nil
				end)
				order += 1
			end
			return
		end

		collecLine(string.format("COMPOSITION (%d emplacements)", #slots), GOLD, order, 24)
		order += 1

		local auto = button("🔁 TOUT REMETTRE EN AUTOMATIQUE", Color3.fromRGB(200, 160, 90), collecScroll)
		auto.Size = UDim2.new(1, 0, 0, 28)
		auto.TextSize = 13
		auto.LayoutOrder = order
		auto.MouseButton1Click:Connect(function() rLineup:FireServer({ kind = "auto" }) end)
		order += 1

		local lineup = c.lineup or {}
		for i, entry in slots do
			local card = (c.squad or {})[i]
			local fixed = lineup[tostring(i)] ~= nil
			local r = card and Config.rarity(card.rarity) or nil
			local text = string.format("%d. %s — %s%s", i, entry.base,
				card and card.name or "vide", if fixed then "  📌" else "")
			local b = button(text, if fixed then Color3.fromRGB(90, 120, 160) else Color3.fromRGB(60, 64, 80),
				collecScroll)
			b.Size = UDim2.new(1, 0, 0, 28)
			b.TextSize = 13
			b.TextColor3 = r and r.color or Color3.fromRGB(200, 200, 215)
			b.LayoutOrder = order
			b.MouseButton1Click:Connect(function()
				pickingSlot = i
				refreshCollection()
			end)
			order += 1
		end
		return
	end

	collecLine(string.format("SUR LE TERRAIN (%d/%d)", #c.squad, c.maxSlots), GOLD, order, 24)
	order += 1
	for i, card in c.squad do
		local r = Config.rarity(card.rarity)
		local fixed = (c.lineup or {})[tostring(i)] ~= nil
		collecLine(string.format("%d. %s — %s ×%s%s", i, card.name, r.name, Config.abbreviate(r.mult),
			if fixed then "  📌" else ""), r.color, order, 20)
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
end

rCollection.OnClientEvent:Connect(function(c)
	lastCollection = c
	-- Un panneau fermé n'a pas besoin d'être redessiné : la collection est
	-- republiée à chaque dé, chaque don et chaque changement d'équipe.
	if collecPanel.Visible then refreshCollection() end
end)

-- Deuxième abonnement au même bouton : le premier ouvre/ferme le panneau,
-- celui-ci le redessine. Redessiner à l'ouverture est indispensable — le
-- panneau n'est pas mis à jour tant qu'il est fermé.
collecToggle.MouseButton1Click:Connect(refreshCollection)

-------------------------------------------------------------------------------
-- INDEX / DONS / ADMIN : deuxième rangée de boutons, sous COLLECTION.
-------------------------------------------------------------------------------
local function rowButton(text: string, color: Color3, x: number, w: number): TextButton
	local b = button(text, color, ui)
	b.Size = UDim2.fromOffset(w, 36)
	b.Position = UDim2.fromOffset(x, 188)
	b.TextSize = 14
	return b
end

-- Cinq boutons sur la rangée : ils tiennent dans la même largeur que les
-- panneaux (320) pour ne pas déborder sur les stats. Au-delà, les libellés
-- deviennent illisibles — c'est pourquoi la composition d'équipe vit dans le
-- panneau COLLECTION plutôt que d'ajouter un sixième bouton.
local indexToggle = rowButton("📕", Color3.fromRGB(90, 180, 235), 16, 58)
local giftToggle = rowButton("🎁", Color3.fromRGB(235, 130, 170), 80, 58)
local bagToggle = rowButton("🎒", Color3.fromRGB(120, 210, 180), 144, 58)
local spectateToggle = rowButton("👁", Color3.fromRGB(150, 170, 220), 208, 58)
local adminToggle = rowButton("🛠", Color3.fromRGB(200, 200, 210), 272, 58)
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
-- Déclarés ici et pas dans la section SAC : l'index des pets, plus haut dans le
-- fichier, en a besoin lui aussi.
local lastPets: { [string]: number } = {}
local petsEquipped: { string } = {}
local petSlots = 1
local petMult = 1

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

-------------------------------------------------------------------------------
-- INDEX DES PETS : le même panneau, deuxième mode.
--
-- Les 36 pets du jeu, groupés par monde et par œuf. Ceux qu'on n'a jamais
-- obtenus restent masqués : c'est ce qui donne envie d'ouvrir l'œuf suivant, et
-- ça dit surtout OÙ chercher (quel œuf, dans quel monde).
-------------------------------------------------------------------------------
local indexMode = "joueurs"   -- "joueurs" | "pets"
local petIndexScroll = panelScroll(indexPanel)
petIndexScroll.Visible = false

local function refreshPetIndex()
	petIndexScroll:ClearAllChildren()
	make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, petIndexScroll)

	local catalogue = Config.petCatalogue()
	local owned = 0
	for _, entry in catalogue do
		if (lastPets[entry.key] or 0) > 0 then owned += 1 end
	end

	local order = 1
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
		Text = string.format("INDEX PETS — %d/%d (%d%%)", owned, #catalogue,
			math.floor(owned / math.max(1, #catalogue) * 100)),
		Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order,
	}, petIndexScroll)
	order += 1

	local currentEgg = nil
	for _, entry in catalogue do
		if entry.eggKey ~= currentEgg then
			currentEgg = entry.eggKey
			make("TextLabel", {
				Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
				Text = string.format("%s · %s", entry.worldName, entry.egg),
				Font = Enum.Font.GothamBold, TextSize = 13,
				TextColor3 = Color3.fromRGB(150, 170, 210),
				TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order,
			}, petIndexScroll)
			order += 1
		end

		local count = lastPets[entry.key] or 0
		local has = count > 0
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
			Text = if has
				then string.format("  %s  ×%s  (x%d)", entry.name, fmtMult(entry.mult), count)
				else "  ???",
			Font = Enum.Font.GothamBold, TextSize = 12,
			TextColor3 = if has then entry.color else Color3.fromRGB(90, 92, 105),
			TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order,
		}, petIndexScroll)
		order += 1
	end
end

-- Bascule joueurs / pets, en tête du panneau INDEX.
local indexModeBtn = button("🐾 VOIR L'INDEX DES PETS", Color3.fromRGB(120, 200, 170), indexPanel)
indexModeBtn.Size = UDim2.fromOffset(PANEL_RECT.w - 16, 26)
indexModeBtn.Position = UDim2.fromOffset(8, PANEL_RECT.h - 34)
indexModeBtn.TextSize = 13
indexModeBtn.ZIndex = 3

local function applyIndexMode()
	local pets = indexMode == "pets"
	indexScroll.Visible = not pets
	petIndexScroll.Visible = pets
	-- On laisse la place au bouton de bascule, sinon il recouvre la dernière ligne.
	indexScroll.Size = UDim2.new(1, -16, 1, -46)
	petIndexScroll.Size = UDim2.new(1, -16, 1, -46)
	indexModeBtn.Text = if pets then "📕 VOIR L'INDEX DES JOUEURS" else "🐾 VOIR L'INDEX DES PETS"
	if pets then refreshPetIndex() else refreshIndex() end
end

indexModeBtn.MouseButton1Click:Connect(function()
	indexMode = if indexMode == "pets" then "joueurs" else "pets"
	applyIndexMode()
end)

indexToggle.MouseButton1Click:Connect(function()
	-- 258 lignes : refermer puis rouvrir en repartant du haut donne l'impression
	-- que l'index s'est remis a zero. On garde la position de defilement.
	local keep = indexScroll.CanvasPosition
	buildIndexRows()
	applyIndexMode()
	togglePanel(indexPanel)
	if indexPanel.Visible and indexMode == "joueurs" then
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
-- Argent connu du client, pour les boutons de don en pourcentage. Le serveur
-- rabote de toute façon : ce n'est qu'un confort de saisie.
local lastMoney = 0
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

	-- MONTANTS TOUT PRÊTS.
	--
	-- Le champ de saisie ouvrait le clavier du téléphone par-dessus le jeu, et
	-- c'est en cherchant à le refermer qu'on finissait par sortir de la partie :
	-- « je veux donner de l'argent, et ça me fait quitter ». Trois boutons de
	-- pourcentage suffisent pour donner sans jamais taper une seule touche — le
	-- champ reste là pour ceux qui veulent un montant précis.
	local presets = make("Frame", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = order,
	}, giftScroll)
	order += 1
	local presetDefs = { { "10 %", 0.10 }, { "25 %", 0.25 }, { "MAX", Config.Gift.maxShare } }
	for i, def in presetDefs do
		local b = button(def[1] :: string, Color3.fromRGB(235, 170, 60), presets)
		b.Size = UDim2.new(0.32, 0, 1, 0)
		b.Position = UDim2.new((i - 1) * 0.34, 0, 0, 0)
		b.TextSize = 13
		b.MouseButton1Click:Connect(function()
			-- Le serveur rabote de toute façon à Config.Gift.maxShare : ce calcul
			-- n'est qu'un confort d'affichage, il n'autorise rien.
			local amount = math.floor((lastMoney or 0) * (def[2] :: number))
			if amount < Config.Gift.minMoney then
				toast("Pas assez d'argent pour un don.", Color3.fromRGB(120, 60, 60))
				return
			end
			rGift:FireServer({ to = giftTarget, kind = "money", amount = amount })
		end)
	end

	local sendMoney = button("OFFRIR LE MONTANT SAISI", Color3.fromRGB(235, 170, 60), giftScroll)
	sendMoney.Size = UDim2.new(1, 0, 0, 34)
	sendMoney.TextSize = 13
	sendMoney.LayoutOrder = order
	sendMoney.MouseButton1Click:Connect(function()
		local amount = tonumber(amountBox.Text)
		if not amount then
			toast("Saisis un montant, ou utilise 10 % / 25 % / MAX.", Color3.fromRGB(120, 90, 60))
			return
		end
		rGift:FireServer({ to = giftTarget, kind = "money", amount = amount })
		amountBox.Text = ""
		-- Le clavier mobile reste ouvert tant qu'on ne lui dit pas de partir, et
		-- c'est lui qui masquait le jeu après un don.
		amountBox:ReleaseFocus()
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
-- SAC À DOS : les potions gagnées au défi du loin.
--
-- Le contenu vient toujours du serveur (stats.potions) : le bouton n'envoie
-- qu'une intention de boire, c'est le serveur qui décompte et applique l'effet.
-------------------------------------------------------------------------------
local bagPanel = sidePanel(Color3.fromRGB(120, 210, 180))
local bagScroll = panelScroll(bagPanel)
local lastPotions: { [string]: number } = {}
local lastEffects: { [string]: any } = {}

local function bagLine(text: string, color: Color3, order: number, height: number)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1,
		Text = text, Font = Enum.Font.GothamBold, TextScaled = true,
		TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	}, bagScroll)
end

local function mmss(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function refreshBag()
	bagScroll:ClearAllChildren()
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, bagScroll)
	local order = 1

	bagLine("🧪 EFFETS EN COURS", GOLD, order, 22); order += 1
	local anyEffect = false
	for kind, label in { money = "x%s argent", power = "x%s puissance de tir" } do
		local e = lastEffects[kind]
		if e and (e.left or 0) > 0 then
			anyEffect = true
			bagLine(string.format(label, fmtMult(e.mult)) .. "  —  " .. mmss(e.left),
				Color3.fromRGB(120, 220, 140), order, 20)
			order += 1
		end
	end
	if not anyEffect then
		bagLine("Aucun effet actif.", Color3.fromRGB(180, 180, 200), order, 20); order += 1
	end

	bagLine("🎒 POTIONS", GOLD, order, 22); order += 1
	local any = false
	for _, potion in Config.Potions do
		local n = lastPotions[potion.key] or 0
		if n > 0 then
			any = true
			local b = button(string.format("%s x%d\n%s", potion.name, n, potion.desc),
				potion.color, bagScroll)
			b.Size = UDim2.new(1, 0, 0, 46)
			b.TextSize = 12
			b.LayoutOrder = order
			b.MouseButton1Click:Connect(function() rUsePotion:FireServer(potion.key) end)
			order += 1
		end
	end
	if not any then
		bagLine("Aucune potion — finis dans les 3 premiers du défi du loin\n(toutes les 10 min) pour en gagner.",
			Color3.fromRGB(180, 180, 200), order, 34)
		order += 1
	end

	-- PETS : plusieurs places d'équipement (Config.petSlots), le reste attend
	-- dans le sac. Un pet déjà équipé se retire du même bouton.
	bagLine(string.format("🐾 PETS — %d/%d équipés  (argent x%s)",
		#petsEquipped, petSlots, fmtMult(petMult)), GOLD, order, 22)
	order += 1

	local ownedPets = {}
	for key, count in lastPets do
		local pet = Config.pet(key)
		if pet and (tonumber(count) or 0) > 0 then
			table.insert(ownedPets, { key = key, pet = pet, count = count })
		end
	end
	table.sort(ownedPets, function(a, b)
		if a.pet.mult == b.pet.mult then return a.pet.name < b.pet.name end
		return a.pet.mult > b.pet.mult
	end)

	if #ownedPets == 0 then
		bagLine("Aucun pet — va ouvrir un œuf au parvis 🥚\n(ou depuis la boutique).",
			Color3.fromRGB(180, 180, 200), order, 34)
		return
	end

	local equippedSet: { [string]: boolean } = {}
	for _, key in petsEquipped do equippedSet[key] = true end

	local bestBtn = button("⭐ ÉQUIPER LES MEILLEURS", Color3.fromRGB(120, 200, 140), bagScroll)
	bestBtn.Size = UDim2.new(1, 0, 0, 32)
	bestBtn.TextSize = 14
	bestBtn.LayoutOrder = order
	bestBtn.MouseButton1Click:Connect(function() rPet:FireServer({ kind = "best" }) end)
	order += 1

	if #petsEquipped > 0 then
		local unequip = button("Tout ranger", Color3.fromRGB(100, 104, 124), bagScroll)
		unequip.Size = UDim2.new(1, 0, 0, 28)
		unequip.TextSize = 13
		unequip.TextColor3 = Color3.fromRGB(235, 235, 245)
		unequip.LayoutOrder = order
		unequip.MouseButton1Click:Connect(function() rPet:FireServer({ kind = "none" }) end)
		order += 1
	end

	for _, entry in ownedPets do
		local isOn = equippedSet[entry.key] == true
		local b = button(string.format("%s %s x%d — argent x%s", if isOn then "✅" else "🐾",
			entry.pet.name, entry.count, fmtMult(entry.pet.mult)),
			if isOn then Color3.fromRGB(120, 220, 150) else Color3.fromRGB(70, 74, 92), bagScroll)
		b.Size = UDim2.new(1, 0, 0, 30)
		b.TextSize = 13
		b.LayoutOrder = order
		b.TextColor3 = if isOn then Color3.fromRGB(15, 15, 20) else entry.pet.color
		b.MouseButton1Click:Connect(function()
			-- Le serveur équipe ou retire selon l'état : un seul bouton par pet.
			rPet:FireServer({ kind = "equip", key = entry.key })
		end)
		order += 1
	end
end

bagToggle.MouseButton1Click:Connect(function()
	refreshBag()
	togglePanel(bagPanel)
end)

-------------------------------------------------------------------------------
-- DÉFI DU LOIN : bandeau haut avec le compte à rebours et les meilleures
-- distances. Tout vient du serveur, le client ne fait qu'afficher.
-------------------------------------------------------------------------------
local challengeFrame = make("Frame", {
	Size = UDim2.fromOffset(380, 150),
	Position = UDim2.new(0.5, -190, 0, 8),
	BackgroundColor3 = BG, BackgroundTransparency = 0.15,
	BorderSizePixel = 0, Visible = false,
}, ui)
corner(challengeFrame, 12)
make("UIStroke", { Color = Color3.fromRGB(255, 150, 90), Thickness = 1.5, Transparency = 0.3 }, challengeFrame)

local challengeTitle = make("TextLabel", {
	Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 6),
	BackgroundTransparency = 1, Text = "🏹 DÉFI DU LOIN",
	Font = Enum.Font.GothamBlack, TextScaled = true,
	TextColor3 = Color3.fromRGB(255, 170, 90),
}, challengeFrame)

local challengeList = make("TextLabel", {
	Size = UDim2.new(1, -16, 1, -40), Position = UDim2.fromOffset(8, 34),
	BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamBold,
	TextSize = 15, TextColor3 = Color3.fromRGB(230, 232, 245),
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, challengeFrame)

local challengeOn = false
local myBestDistance = 0

rChallenge.OnClientEvent:Connect(function(state)
	local wasOn = challengeOn
	challengeOn = state.active == true
	if challengeOn and not wasOn then myBestDistance = 0 end
	-- Hors défi, le bandeau ne s'affiche que dans la dernière minute : sinon il
	-- occupe le haut de l'écran pendant neuf minutes pour ne rien dire.
	challengeFrame.Visible = challengeOn or (state.left or 0) <= 60

	if challengeOn then
		challengeTitle.Text = string.format("🏹 DÉFI DU LOIN — %s", mmss(state.left or 0))
		challengeTitle.TextColor3 = Color3.fromRGB(255, 170, 90)
	else
		challengeTitle.Text = string.format("🏹 Prochain défi dans %s", mmss(state.left or 0))
		challengeTitle.TextColor3 = Color3.fromRGB(160, 200, 240)
	end

	local rows = {}
	for i, s in state.scores or {} do
		local medal = if i == 1 then "🥇" elseif i == 2 then "🥈" elseif i == 3 then "🥉" else (i .. ".")
		table.insert(rows, string.format("%s %s — %s studs", medal, s.name, Config.abbreviate(s.distance)))
	end
	if #rows == 0 then
		challengeList.Text = if challengeOn
			then "Terrain vide : tire le plus loin possible !\nAucune distance pour l'instant."
			else "Récompenses : 1er x3 argent 30 min,\n2e x2 puissance 10 min, 3e x2 puissance 5 min."
	else
		challengeList.Text = table.concat(rows, "\n")
	end
end)

-------------------------------------------------------------------------------
-- TUTORIEL : montré une fois (l'état est gardé côté serveur), rejouable par le
-- bouton ❓. Sept écrans, un geste par écran — au-delà, plus personne ne lit.
-------------------------------------------------------------------------------
local TUTORIAL = {
	{ "⚽ Bienvenue au Baby-Foot Power",
	  "Tu tires depuis le bout d'un baby-foot géant. Chaque figurine touchée rapporte de l'argent, et la balle au fond du but multiplie le total par 3." },
	{ "🏋️ 1. S'entraîner",
	  "Maintiens S'ENTRAÎNER en bas à gauche. Chaque rep ajoute de la puissance, et la puissance, c'est la vitesse de ta balle : sans elle, tu n'atteins pas le fond." },
	{ "🎯 2. Viser et tirer",
	  "Tourne la caméra pour viser : tu tires là où tu regardes. Maintiens TIRER, la jauge fait des allers-retours — relâche dans le VERT FONCÉ pour le tir le plus fort." },
	{ "🎲 3. Recruter",
	  "RECRUTER lance les dés et ajoute un joueur à ta collection. Les meilleurs se posent tout seuls sur le terrain : plus ils sont rares, plus ils rapportent quand la balle les touche." },
	{ "🍀 4. Chance et boutique",
	  "Dans la boutique : haltères, balle, valeur des joueurs, et CHANCE, qui fait sortir mieux que du Commun aux dés (jusqu'à x5 ; la passe Robux monte à x20)." },
	{ "🌍 5. Mondes et renaissance",
	  "Renaître remet l'argent et le matériel à zéro contre un multiplicateur permanent. Les MONDES (Galactique, Radioactif), eux, s'achètent une fois et multiplient l'argent pour toujours." },
	{ "🏹 6. Le défi du loin",
	  "Toutes les 10 minutes, le terrain se vide : un seul but, envoyer la balle le plus loin possible. Les 3 premiers gagnent des potions, rangées dans ton SAC À DOS." },
	{ "💤 7. Hors ligne",
	  "Quand tu quittes le jeu, ton équipe continue de jouer : tu retrouves une partie de tes gains à la reconnexion. À toi de jouer !" },
}

local tutorialShown = false
local tutorialStep = 1

-- Déclarés ici et pas plus bas : la fermeture du tutoriel enchaîne sur le pop-up
-- des nouveautés, et une fonction ne voit pas un local déclaré après elle.
local pendingRelease = false
local openRelease

local tutorialDim = make("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.45, BorderSizePixel = 0, Visible = false, ZIndex = 50,
}, ui)

local tutorialCard = make("Frame", {
	Size = UDim2.fromOffset(460, 250), Position = UDim2.new(0.5, -230, 0.5, -125),
	BackgroundColor3 = BG, BorderSizePixel = 0, ZIndex = 51,
}, tutorialDim)
corner(tutorialCard, 16)
make("UIStroke", { Color = ACCENT, Thickness = 2, Transparency = 0.2 }, tutorialCard)

local tutoTitle = make("TextLabel", {
	Size = UDim2.new(1, -32, 0, 36), Position = UDim2.fromOffset(16, 14),
	BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamBlack,
	TextScaled = true, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 52,
}, tutorialCard)

local tutoBody = make("TextLabel", {
	Size = UDim2.new(1, -32, 0, 120), Position = UDim2.fromOffset(16, 56),
	BackgroundTransparency = 1, Text = "", Font = Enum.Font.Gotham,
	TextSize = 17, TextWrapped = true, TextColor3 = Color3.fromRGB(228, 230, 244),
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 52,
}, tutorialCard)

local tutoProgress = make("TextLabel", {
	Size = UDim2.fromOffset(120, 30), Position = UDim2.fromOffset(16, 200),
	BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamBold,
	TextSize = 14, TextColor3 = Color3.fromRGB(170, 174, 195),
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 52,
}, tutorialCard)

local tutoSkip = button("PASSER", Color3.fromRGB(90, 94, 112), tutorialCard)
tutoSkip.Size = UDim2.fromOffset(110, 34)
tutoSkip.Position = UDim2.fromOffset(200, 198)
tutoSkip.TextSize = 14
tutoSkip.TextColor3 = Color3.fromRGB(240, 240, 250)
tutoSkip.ZIndex = 52

local tutoNext = button("SUIVANT ▶", ACCENT, tutorialCard)
tutoNext.Size = UDim2.fromOffset(120, 34)
tutoNext.Position = UDim2.fromOffset(322, 198)
tutoNext.TextSize = 14
tutoNext.ZIndex = 52

local function closeTutorial()
	tutorialDim.Visible = false
	rTutorial:FireServer()
	-- Le tutoriel et les nouveautés ne s'affichent jamais l'un par-dessus l'autre :
	-- le second attend la fermeture du premier.
	if pendingRelease and openRelease then openRelease() end
end

local function showTutorialStep()
	local step = TUTORIAL[tutorialStep]
	if not step then closeTutorial() return end
	tutoTitle.Text = step[1]
	tutoBody.Text = step[2]
	tutoProgress.Text = string.format("%d / %d", tutorialStep, #TUTORIAL)
	tutoNext.Text = if tutorialStep >= #TUTORIAL then "C'EST PARTI !" else "SUIVANT ▶"
end

local function openTutorial()
	tutorialStep = 1
	showTutorialStep()
	tutorialDim.Visible = true
end

tutoNext.MouseButton1Click:Connect(function()
	tutorialStep += 1
	if tutorialStep > #TUTORIAL then
		closeTutorial()
	else
		showTutorialStep()
	end
end)
tutoSkip.MouseButton1Click:Connect(closeTutorial)

-- Bouton d'aide : rejouer le tutoriel à tout moment, à côté de la musique.
local helpBtn = button("❓ AIDE", Color3.fromRGB(120, 160, 220), ui)
helpBtn.Size = UDim2.fromOffset(80, 32)
helpBtn.Position = UDim2.fromOffset(172, 16)
helpBtn.TextSize = 14
helpBtn.MouseButton1Click:Connect(openTutorial)

-------------------------------------------------------------------------------
-- NOUVEAUTÉS DE LA VERSION.
--
-- Ouvert automatiquement à la première connexion qui suit une mise à jour, puis
-- plus jamais : le serveur retient la version lue dans la sauvegarde du joueur.
-- Le bouton 📣 permet de le relire quand on veut.
--
-- Le contenu vient de Config.Release, partagé : il n'y a qu'UN endroit à
-- modifier pour annoncer une nouvelle version (cf. Config.Release.notes).
-------------------------------------------------------------------------------
local releaseShown = false

local releaseDim = make("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.45, BorderSizePixel = 0, Visible = false, ZIndex = 60,
}, ui)

local releaseCard = make("Frame", {
	Size = UDim2.fromOffset(500, 330), Position = UDim2.new(0.5, -250, 0.5, -165),
	BackgroundColor3 = BG, BorderSizePixel = 0, ZIndex = 61,
}, releaseDim)
corner(releaseCard, 16)
make("UIStroke", { Color = GOLD, Thickness = 2, Transparency = 0.2 }, releaseCard)

make("TextLabel", {
	Size = UDim2.new(1, -32, 0, 34), Position = UDim2.fromOffset(16, 12),
	BackgroundTransparency = 1, Text = Config.Release.title,
	Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 62,
}, releaseCard)

make("TextLabel", {
	Size = UDim2.new(1, -32, 0, 18), Position = UDim2.fromOffset(16, 46),
	BackgroundTransparency = 1, Text = "version " .. Config.Release.version,
	Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(160, 164, 185),
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 62,
}, releaseCard)

local releaseScroll = make("ScrollingFrame", {
	Size = UDim2.new(1, -32, 0, 200), Position = UDim2.fromOffset(16, 68),
	BackgroundTransparency = 1, BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 62,
}, releaseCard)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, releaseScroll)

for i, note in Config.Release.notes do
	make("TextLabel", {
		Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Text = "•  " .. note,
		Font = Enum.Font.Gotham, TextSize = 15, TextWrapped = true,
		TextColor3 = Color3.fromRGB(226, 229, 244),
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, ZIndex = 62,
	}, releaseScroll)
end

local releaseOk = button("SUPER !", ACCENT, releaseCard)
releaseOk.Size = UDim2.fromOffset(160, 36)
releaseOk.Position = UDim2.fromOffset(324, 280)
releaseOk.TextSize = 15
releaseOk.ZIndex = 62

openRelease = function()
	pendingRelease = false
	releaseDim.Visible = true
end

releaseOk.MouseButton1Click:Connect(function()
	releaseDim.Visible = false
	-- On ne dit « lu » qu'ici : fermer par un autre chemin doit laisser l'annonce
	-- revenir à la prochaine connexion.
	rReleaseSeen:FireServer()
end)

local releaseBtn = button("📣", Color3.fromRGB(210, 160, 90), ui)
releaseBtn.Size = UDim2.fromOffset(44, 32)
releaseBtn.Position = UDim2.fromOffset(258, 16)
releaseBtn.TextSize = 16
releaseBtn.MouseButton1Click:Connect(openRelease)

-------------------------------------------------------------------------------
-- MODE SPECTATEUR.
--
-- Le serveur déplace vraiment le personnage jusqu'au parvis de la cible (avec
-- StreamingEnabled, un plot à 600 studs n'est même pas chargé chez nous) ; ici
-- on ne fait que braquer la caméra sur le joueur regardé.
--
-- La caméra est réappliquée en boucle tant qu'on regarde : le personnage de la
-- cible peut n'arriver qu'une seconde plus tard, le temps que la zone se charge.
-------------------------------------------------------------------------------
local spectatePanel = sidePanel(Color3.fromRGB(150, 170, 220))
local spectateScroll = panelScroll(spectatePanel)
local spectating: number? = nil

local function ownHumanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function applyCamera()
	local cam = workspace.CurrentCamera
	if not cam then return end
	if spectating then
		local target = Players:GetPlayerByUserId(spectating)
		local char = target and target.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then cam.CameraSubject = hum end
	else
		local hum = ownHumanoid()
		if hum then cam.CameraSubject = hum end
	end
end

local spectateBanner = make("TextButton", {
	Size = UDim2.fromOffset(360, 40), Position = UDim2.new(0.5, -180, 0, 164),
	BackgroundColor3 = Color3.fromRGB(40, 46, 70), BackgroundTransparency = 0.1,
	Text = "", Font = Enum.Font.GothamBold, TextScaled = true,
	TextColor3 = Color3.fromRGB(230, 235, 250), BorderSizePixel = 0,
	Visible = false, ZIndex = 8,
}, ui)
corner(spectateBanner, 10)
spectateBanner.MouseButton1Click:Connect(function()
	rSpectate:FireServer({ kind = "stop" })
end)

local function refreshSpectate()
	spectateScroll:ClearAllChildren()
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, spectateScroll)
	local order = 1

	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
		Text = "👁 REGARDER QUELQU'UN", Font = Enum.Font.GothamBlack, TextScaled = true,
		TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order,
	}, spectateScroll)
	order += 1

	if spectating then
		local stop = button("◀ ARRÊTER DE REGARDER", Color3.fromRGB(220, 120, 120), spectateScroll)
		stop.Size = UDim2.new(1, 0, 0, 32)
		stop.TextSize = 14
		stop.LayoutOrder = order
		stop.MouseButton1Click:Connect(function() rSpectate:FireServer({ kind = "stop" }) end)
		order += 1
	end

	local others = 0
	for _, entry in roster do
		if entry.userId ~= player.UserId then
			others += 1
			local watching = spectating == entry.userId
			local b = button(if watching then "👁 " .. entry.name .. " (en cours)" else entry.name,
				if watching then Color3.fromRGB(120, 200, 220) else Color3.fromRGB(70, 74, 92), spectateScroll)
			b.Size = UDim2.new(1, 0, 0, 32)
			b.TextSize = 14
			b.TextColor3 = if watching then Color3.fromRGB(15, 15, 20) else Color3.fromRGB(235, 235, 245)
			b.LayoutOrder = order
			b.MouseButton1Click:Connect(function()
				rSpectate:FireServer({ kind = "start", userId = entry.userId })
			end)
			order += 1
		end
	end
	if others == 0 then
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1,
			Text = "Personne d'autre sur le serveur pour l'instant.",
			Font = Enum.Font.GothamBold, TextSize = 13, TextWrapped = true,
			TextColor3 = Color3.fromRGB(180, 180, 200),
			TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order,
		}, spectateScroll)
	end
end

spectateToggle.MouseButton1Click:Connect(function()
	refreshSpectate()
	togglePanel(spectatePanel)
end)

-- Deuxième abonnement au roster : le premier (section DONS) met `roster` à jour,
-- celui-ci redessine la liste des joueurs à regarder. Il est ici et pas là-bas
-- parce qu'une fonction ne voit pas un local déclaré après elle.
rRoster.OnClientEvent:Connect(function()
	if spectatePanel.Visible then refreshSpectate() end
end)

-- La caméra est réappliquée tant qu'on regarde : le personnage de la cible peut
-- n'arriver qu'une seconde plus tard, le temps que sa zone se charge.
task.spawn(function()
	while true do
		if spectating then applyCamera() end
		task.wait(1)
	end
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
		Position = UDim2.new(0.5, -230, 0, 200),
		BackgroundColor3 = color or Color3.fromRGB(40, 44, 60),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold, TextScaled = true,
		Text = text, BackgroundTransparency = 0.1,
	}, ui)
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
	-- Plus la carte est rare, plus ça tape. Au-delà du Légendaire, deux
	-- pulsations : on doit sentir la différence sans regarder l'écran.
	if r.mult >= 22 then
		buzz(0.9, 0.12)
		task.delay(0.2, function() buzz(0.9, 0.18) end)
	elseif r.mult >= 8 then
		buzz(0.5, 0.10)
	end
	toast(string.format("🎲 %s — %s (×%s)", res.card.name, r.name, Config.abbreviate(r.mult)),
		r.color)
end)

-- Éclosion d'un œuf : le pet obtenu, coloré par le sien. Plus le multiplicateur
-- est gros, plus ça vibre — on doit sentir un bon tirage sans lire l'écran.
rPetResult.OnClientEvent:Connect(function(res)
	local pet = Config.pet(res.key)
	local color = pet and pet.color or GOLD
	if (res.mult or 1) >= 50 then
		buzz(0.9, 0.14)
		task.delay(0.22, function() buzz(0.9, 0.2) end)
	else
		buzz(0.45, 0.1)
	end
	toast(string.format("🥚 %s → %s  (argent x%s)%s", res.egg or "Œuf", res.name or res.key,
		fmtMult(res.mult or 1), if res.equipped then "  • équipé !" else ""), color)
	if bagPanel.Visible then refreshBag() end
end)

rShotResult.OnClientEvent:Connect(function(res)
	-- Tir de défi : un seul chiffre compte, la distance. Pas d'argent à annoncer.
	if res.challenge then
		myBestDistance = math.max(myBestDistance, res.bestDistance or 0)
		if res.record then
			buzz(0.7, 0.2)
			toast(string.format("🏹 %s studs — nouveau record de la manche !", Config.abbreviate(res.distance)),
				Color3.fromRGB(200, 120, 40))
		else
			toast(string.format("🏹 %s studs  (ton meilleur : %s)",
				Config.abbreviate(res.distance), Config.abbreviate(res.bestDistance or 0)),
				Color3.fromRGB(90, 90, 120))
		end
		return
	end

	local tier = res.tier and ("  •  " .. res.tier) or ""
	if res.best then tier ..= "  •  " .. res.best end
	if res.scored then
		buzz(1, 0.35)
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
-- AMBIANCE (ciel, brume, lumière).
--
-- Réglée CÔTÉ CLIENT et pas côté serveur : Lighting est unique pour toute la
-- partie, alors que chaque joueur est dans SON monde. Un joueur passé en
-- Radioactif doit voir sa brume verte sans la coller à ses voisins restés au
-- stade — et une modification locale de Lighting ne part jamais au serveur.
--
-- Ce sont ces quatre réglages (atmosphère, bloom, rayons du soleil, étalonnage)
-- qui font la différence entre « des blocs colorés » et un stade : ils coûtent
-- un post-process, pas des parts.
-------------------------------------------------------------------------------
local Lighting = game:GetService("Lighting")

local function lightingFx(class: string, name: string, props: { [string]: any }): any
	local inst = Lighting:FindFirstChild(name)
	if not inst then
		inst = Instance.new(class)
		;(inst :: any).Name = name
		;(inst :: any).Parent = Lighting
	end
	for k, v in props do
		(inst :: any)[k] = v
	end
	return inst
end

local AMBIANCE = {
	-- Fin d'après-midi : ombres longues, ciel chaud, c'est l'heure la plus
	-- flatteuse pour un stade.
	[1] = { clock = 16.8, brightness = 2.6, ambient = Color3.fromRGB(92, 96, 112),
		outdoor = Color3.fromRGB(122, 128, 146), fog = Color3.fromRGB(198, 212, 234),
		density = 0.32, haze = 1.6, glare = 0.25, tint = Color3.fromRGB(255, 246, 232),
		sunRays = 0.14, bloom = 0.7 },
	-- Galactique : nuit claire, brume violette, floraison marquée.
	[2] = { clock = 0.4, brightness = 1.6, ambient = Color3.fromRGB(58, 48, 96),
		outdoor = Color3.fromRGB(70, 60, 118), fog = Color3.fromRGB(56, 40, 96),
		density = 0.45, haze = 2.4, glare = 0.1, tint = Color3.fromRGB(226, 216, 255),
		sunRays = 0.05, bloom = 1.3 },
	-- Radioactif : jour laiteux, brume verte épaisse.
	[3] = { clock = 11.5, brightness = 2.2, ambient = Color3.fromRGB(84, 104, 66),
		outdoor = Color3.fromRGB(120, 148, 92), fog = Color3.fromRGB(150, 190, 110),
		density = 0.55, haze = 3.0, glare = 0.35, tint = Color3.fromRGB(240, 255, 220),
		sunRays = 0.2, bloom = 1.0 },
}

local currentAmbiance = -1

local function applyAmbiance(worldIndex: number)
	local a = AMBIANCE[worldIndex] or AMBIANCE[1]
	if currentAmbiance == worldIndex then return end
	currentAmbiance = worldIndex

	Lighting.ClockTime = a.clock
	Lighting.Brightness = a.brightness
	Lighting.Ambient = a.ambient
	Lighting.OutdoorAmbient = a.outdoor
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ExposureCompensation = 0.1

	lightingFx("Atmosphere", "AmbianceAtmosphere", {
		Density = a.density, Offset = 0.1, Color = a.fog,
		Decay = a.fog, Glare = a.glare, Haze = a.haze,
	})
	lightingFx("BloomEffect", "AmbianceBloom", {
		Intensity = a.bloom, Size = 24, Threshold = 0.9,
	})
	lightingFx("SunRaysEffect", "AmbianceSunRays", {
		Intensity = a.sunRays, Spread = 0.9,
	})
	lightingFx("ColorCorrectionEffect", "AmbianceColor", {
		Brightness = 0, Contrast = 0.12, Saturation = 0.14, TintColor = a.tint,
	})
end

applyAmbiance(1)

-------------------------------------------------------------------------------
-- MAJ des stats + libellés de la boutique.
-------------------------------------------------------------------------------
rStats.OnClientEvent:Connect(function(s)
	lastMoney = s.money or 0
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

	-- CHANCE : le multiplicateur affiché est celui réellement appliqué au tirage
	-- (amélioration x passe), pas seulement le niveau acheté.
	local luckBtn = upgradeButtons.luck
	if s.luckCost then
		luckBtn.Text = string.format("🍀 Chance (niv. %d/%d) — act. x%s\n%s $",
			s.luckLevel, s.luckMax, fmtMult(s.luckMult), Config.abbreviate(s.luckCost))
		luckBtn.BackgroundColor3 = s.money >= s.luckCost and Color3.fromRGB(70, 160, 90) or Color3.fromRGB(70, 130, 200)
	else
		luckBtn.Text = string.format("🍀 Chance MAX (niv. %d)\nact. x%s", s.luckLevel, fmtMult(s.luckMult))
		luckBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
	end

	-- MONDES : débloqué → bouton de téléportation ; pas encore → bouton d'achat
	-- (et seul le monde juste après celui qu'on a peut être acheté).
	for i, w in s.worlds or {} do
		local b = worldButtons[i]
		if b then
			b:SetAttribute("Unlocked", w.unlocked == true)
			if w.here then
				b.Text = string.format("🌍 %s (x%s)  •  TU ES ICI", w.name, fmtMult(w.mult))
				b.BackgroundColor3 = Color3.fromRGB(90, 200, 130)
			elseif w.unlocked then
				b.Text = string.format("🚀 Aller au monde %s  (x%s)", w.name, fmtMult(w.mult))
				b.BackgroundColor3 = Color3.fromRGB(80, 150, 220)
			elseif i == (s.worldUnlocked or 1) + 1 then
				b.Text = string.format("🔒 %s (x%s) — débloquer\n%s $", w.name, fmtMult(w.mult),
					Config.abbreviate(w.cost))
				b.BackgroundColor3 = s.money >= w.cost and Color3.fromRGB(70, 160, 90) or Color3.fromRGB(80, 100, 92)
			else
				b.Text = string.format("🔒 %s (x%s)\nDébloque d'abord %s", w.name, fmtMult(w.mult),
					(s.worlds[i - 1] and s.worlds[i - 1].name) or "le monde précédent")
				b.BackgroundColor3 = Color3.fromRGB(70, 72, 86)
			end
		end
	end

	-- ŒUFS du monde courant : nom + prix, verts quand on peut se les offrir.
	for i = 1, 3 do
		local b = eggButtons[i]
		local egg = (s.eggs or {})[i]
		if b then
			if egg then
				b:SetAttribute("EggKey", egg.key)
				b.Text = string.format("🥚 %s\n%s $", egg.name, Config.abbreviate(egg.cost))
				b.BackgroundColor3 = s.money >= egg.cost and Color3.fromRGB(70, 160, 90) or Color3.fromRGB(150, 115, 70)
				b.Visible = true
			else
				b.Visible = false
			end
		end
	end

	-- PETS : contenu du sac et pet équipé (le panneau ne se redessine que s'il
	-- est ouvert, cf. refreshBag).
	lastPets = s.pets or {}
	petsEquipped = s.petsEquipped or {}
	petSlots = s.petSlots or 1
	petMult = s.petMult or 1
	if indexPanel.Visible and indexMode == "pets" then refreshPetIndex() end

	-- SAC À DOS : contenu et effets, rafraîchis seulement si le panneau est ouvert.
	lastPotions = s.potions or {}
	lastEffects = s.effects or {}
	if bagPanel.Visible then refreshBag() end

	-- TUTORIEL : au premier passage seulement, et une seule fois par session.
	if not tutorialShown and s.tutorialDone ~= true then
		tutorialShown = true
		openTutorial()
	end

	-- NOUVEAUTÉS : une seule fois par mise à jour. Si le tutoriel est à l'écran
	-- (nouveau joueur), on attend qu'il soit fermé.
	if not releaseShown and s.releaseVersion and s.releaseSeen ~= s.releaseVersion then
		releaseShown = true
		if tutorialDim.Visible then
			pendingRelease = true
		else
			openRelease()
		end
	end

	-- Tir automatique : le bouton n'apparaît qu'une fois débloqué (passe Robux ou
	-- seuil d'argent cumulé), et son état vient du serveur, jamais du clic local.
	autoOn = s.autoShootOn == true
	autoBtn.Visible = s.autoShootUnlocked == true
	autoBtn.Text = if autoOn then "🤖 AUTO : ON" else "🤖 AUTO : OFF"
	autoBtn.BackgroundColor3 = if autoOn then Color3.fromRGB(90, 220, 140) else Color3.fromRGB(120, 130, 150)

	adminToggle.Visible = s.isAdmin == true

	-- AFK : l'état vient du serveur, jamais du clic local.
	afkOn = s.afk == true
	afkBtn.Text = if afkOn
		then string.format("💤 AFK : ON  (+%s/s)", Config.abbreviate(s.afkPerSec or 0))
		else "💤 AFK : OFF"
	afkBtn.BackgroundColor3 = if afkOn then Color3.fromRGB(150, 140, 220) else Color3.fromRGB(120, 130, 150)

	-- SPECTATEUR : bandeau permanent tant qu'on regarde quelqu'un, cliquable pour
	-- revenir chez soi — c'est la sortie la plus visible possible.
	local wasSpectating = spectating
	spectating = s.spectating
	if spectating then
		local target = Players:GetPlayerByUserId(spectating)
		spectateBanner.Text = "👁 Tu regardes " .. (target and target.DisplayName or "…")
			.. "  •  APPUIE POUR REVENIR"
		spectateBanner.Visible = true
	else
		spectateBanner.Visible = false
	end
	if wasSpectating ~= spectating then
		applyCamera()
		if spectatePanel.Visible then refreshSpectate() end
	end

	-- Ambiance du monde courant (ne fait rien si le monde n'a pas changé).
	applyAmbiance((s.world and s.world.index) or 1)
end)


toast("⚽ Lance les 🎲 pour recruter tes joueurs, place-les sur les 4 bases (11 max), "
	.. "puis vise à la caméra et relâche la jauge dans le vert foncé !",
	Color3.fromRGB(50, 80, 120))
print("[BabyFoot] Client prêt.")
