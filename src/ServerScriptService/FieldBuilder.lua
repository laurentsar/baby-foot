--!strict
-- Génère la carte procédurale : baby-foot, tiges de figurines, zone d'entraînement,
-- point de tir, spawn et panneau de classement mondial. Aucune modélisation Studio requise.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local FieldBuilder = {}

local GREEN = Color3.fromRGB(30, 140, 70)
local NEON = Color3.fromRGB(80, 220, 255)
local WOOD = Color3.fromRGB(120, 80, 45)

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Construit le baby-foot. Retourne les infos utiles au moteur de tir.
-- originOverride permet un plot par joueur (offset dans le monde).
function FieldBuilder.build(fieldMult: number, originOverride: Vector3?)
	local F = Config.Field
	local length = F.length * fieldMult
	local width = F.width
	local origin = originOverride or F.origin

	local root = Instance.new("Model")
	root.Name = "BabyFoot"
	root.Parent = workspace

	-- Plateau du terrain
	part("Plateau", Vector3.new(width, 1, length),
		CFrame.new(origin), GREEN, root, Enum.Material.Grass)

	-- Lignes du milieu (déco)
	part("LigneMilieu", Vector3.new(width, 1.1, 1),
		CFrame.new(origin.X, origin.Y + 0.06, origin.Z),
		Color3.fromRGB(240, 240, 240), root)

	-- Murs latéraux
	local half = length / 2
	part("MurGauche", Vector3.new(2, F.wallHeight, length),
		CFrame.new(origin.X - width / 2 - 1, origin.Y + F.wallHeight / 2, origin.Z), WOOD, root)
	part("MurDroit", Vector3.new(2, F.wallHeight, length),
		CFrame.new(origin.X + width / 2 + 1, origin.Y + F.wallHeight / 2, origin.Z), WOOD, root)

	-- Fond du terrain = LE BUT adverse (cible du x3). Signalé en néon.
	local goalZ = origin.Z + half + F.goalDepth / 2
	local goal = part("But", Vector3.new(width, F.wallHeight + 4, F.goalDepth),
		CFrame.new(origin.X, origin.Y + (F.wallHeight + 4) / 2, goalZ), NEON, root, Enum.Material.Neon)
	goal.Transparency = 0.35

	-- Mur derrière ton point de tir
	local shootZ = origin.Z + F.shootLine
	part("MurArriere", Vector3.new(width, F.wallHeight, 2),
		CFrame.new(origin.X, origin.Y + F.wallHeight / 2, shootZ - 4), WOOD, root)

	-- Point de tir (marqueur au sol)
	local shootPad = part("PointDeTir", Vector3.new(10, 1.2, 10),
		CFrame.new(origin.X, origin.Y + 0.1, shootZ), Color3.fromRGB(255, 210, 60), root, Enum.Material.Neon)

	-- LIGNE D'ENGAGEMENT : le joueur ne va pas sur le terrain, il tire de derrière.
	-- Marquage au sol (visible) + mur invisible collant (infranchissable).
	local barrierZ = shootZ + F.barrierOffset
	local mark = part("LigneAvant", Vector3.new(width, 1.2, 1.5),
		CFrame.new(origin.X, origin.Y + 0.1, barrierZ), Color3.fromRGB(255, 90, 90), root, Enum.Material.Neon)
	mark.CanCollide = false

	-- La balle est simulée en Anchored/CanCollide=false : elle traverse ce mur,
	-- seuls les personnages sont bloqués.
	local fence = part("BarriereAvant", Vector3.new(width + 6, F.barrierHeight, 1),
		CFrame.new(origin.X, origin.Y + F.barrierHeight / 2, barrierZ), Color3.fromRGB(255, 90, 90), root)
	fence.Transparency = 1
	fence.CanCollide = true

	-- TROU D'ENTRÉE DE LA BALLE, au début du baby-foot : c'est de là que part le
	-- tir, comme la goulotte d'un vrai baby-foot. Purement visuel — la balle est
	-- simulée en Anchored et ne dépend d'aucune collision.
	local hole = part("TrouDeBalle", Vector3.new(F.holeRadius * 2, 1.6, F.holeRadius * 2),
		CFrame.new(origin.X, origin.Y + 0.2, shootZ), Color3.fromRGB(10, 10, 14), root,
		Enum.Material.SmoothPlastic)
	hole.Shape = Enum.PartType.Cylinder
	-- Un cylindre Roblox est couché sur X : on le redresse.
	hole.CFrame = CFrame.new(origin.X, origin.Y + 0.2, shootZ) * CFrame.Angles(0, 0, math.rad(90))
	hole.Size = Vector3.new(1.6, F.holeRadius * 2, F.holeRadius * 2)
	hole.CanCollide = false

	local ring = part("BordTrou", Vector3.new(1.2, F.holeRadius * 2 + 3, F.holeRadius * 2 + 3),
		CFrame.new(origin.X, origin.Y + 0.15, shootZ) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 210, 60), root, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.CanCollide = false

	-- MURS INVISIBLES SUR TOUT LE POURTOUR : rien ne sort du terrain, personne
	-- n'y entre en sautant par-dessus les rambardes en bois.
	local fenceFolder = Instance.new("Folder")
	fenceFolder.Name = "MursInvisibles"
	fenceFolder.Parent = root

	local function invisibleWall(name: string, size: Vector3, cf: CFrame)
		local w = part(name, size, cf, Color3.fromRGB(255, 255, 255), fenceFolder)
		w.Transparency = 1
		w.CanCollide = true
		return w
	end

	local fh = F.fenceHeight
	local halfLen = length / 2 + F.goalDepth
	invisibleWall("MurInvGauche", Vector3.new(1, fh, length + F.goalDepth * 2 + 20),
		CFrame.new(origin.X - width / 2 - 2, origin.Y + fh / 2, origin.Z + F.goalDepth / 2))
	invisibleWall("MurInvDroit", Vector3.new(1, fh, length + F.goalDepth * 2 + 20),
		CFrame.new(origin.X + width / 2 + 2, origin.Y + fh / 2, origin.Z + F.goalDepth / 2))
	invisibleWall("MurInvFond", Vector3.new(width + 8, fh, 1),
		CFrame.new(origin.X, origin.Y + fh / 2, origin.Z + halfLen + 8))
	invisibleWall("MurInvArriere", Vector3.new(width + 8, fh, 1),
		CFrame.new(origin.X, origin.Y + fh / 2, shootZ - 10))

	-- Dossier des figurines (peuplé dynamiquement par le moteur de tir)
	local figures = Instance.new("Folder")
	figures.Name = "Figures"
	figures.Parent = root

	local field = {
		root = root,
		figuresFolder = figures,
		origin = origin,
		width = width,
		length = length,
		goalZ = goalZ,
		goalPart = goal,
		shootPos = Vector3.new(origin.X, origin.Y + 2, shootZ),
		shootPad = shootPad,
		barrierZ = barrierZ,
	}

	FieldBuilder.buildBases(field)
	FieldBuilder.buildDecor(field)
	return field
end

-- DÉCOR : tribunes avec public, panneaux publicitaires, projecteurs et drapeaux
-- de corner. Tout est procédural et ancré — aucun modèle à importer dans Studio.
function FieldBuilder.buildDecor(field)
	local origin, width, length = field.origin, field.width, field.length
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = field.root

	local CROWD = {
		Color3.fromRGB(235, 80, 70), Color3.fromRGB(60, 130, 235),
		Color3.fromRGB(250, 205, 60), Color3.fromRGB(90, 200, 120),
		Color3.fromRGB(240, 240, 245), Color3.fromRGB(180, 110, 235),
	}

	-- Tribunes : 3 gradins de plus en plus hauts de chaque côté, avec du public.
	for _, side in { -1, 1 } do
		for tier = 0, 2 do
			local h = 4 + tier * 4
			local x = origin.X + side * (width / 2 + 7 + tier * 7)
			part("Gradin", Vector3.new(7, h, length + 20),
				CFrame.new(x, origin.Y + h / 2, origin.Z), Color3.fromRGB(70, 74, 88),
				folder, Enum.Material.Concrete)

			local seats = 14
			for i = 0, seats - 1 do
				local z = origin.Z - (length + 12) / 2 + (i + 0.5) * (length + 12) / seats
				local body = part("Spectateur", Vector3.new(2, 3, 2),
					CFrame.new(x, origin.Y + h + 1.5, z),
					CROWD[(i + tier * 2) % #CROWD + 1], folder)
				body.CanCollide = false
				local head = part("TeteSpectateur", Vector3.new(1.6, 1.6, 1.6),
					CFrame.new(x, origin.Y + h + 3.8, z),
					Color3.fromRGB(235, 200, 165), folder)
				head.Shape = Enum.PartType.Ball
				head.CanCollide = false
			end
		end
	end

	-- Panneaux publicitaires le long des rambardes, face au terrain.
	local ADS = { "BABY-FOOT POWER", "⚽ POWER LEAGUE", "HALTÈRES PRO", "DÉS D'OR" }
	for _, side in { -1, 1 } do
		for i = 0, 3 do
			local z = origin.Z - length / 2 + (i + 0.5) * length / 4
			local board = part("Panneau", Vector3.new(1, 5, length / 4 - 6),
				CFrame.new(origin.X + side * (width / 2 + 2.6), origin.Y + 3.5, z),
				Color3.fromRGB(25, 28, 38), folder)
			board.CanCollide = false
			local sign = Instance.new("SurfaceGui")
			sign.Face = if side < 0 then Enum.NormalId.Right else Enum.NormalId.Left
			sign.CanvasSize = Vector2.new(600, 120)
			sign.Parent = board
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Text = ADS[i + 1]
			lbl.Font = Enum.Font.GothamBlack
			lbl.TextScaled = true
			lbl.TextColor3 = Color3.fromRGB(255, 210, 60)
			lbl.Parent = sign
		end
	end

	-- Projecteurs aux quatre coins.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x = origin.X + sx * (width / 2 + 26)
			local z = origin.Z + sz * (length / 2 + 12)
			part("Mat", Vector3.new(2.5, 46, 2.5),
				CFrame.new(x, origin.Y + 23, z), Color3.fromRGB(40, 43, 54), folder, Enum.Material.Metal)
			local head = part("Projecteur", Vector3.new(12, 4, 3),
				CFrame.new(x, origin.Y + 47, z), Color3.fromRGB(250, 250, 235), folder, Enum.Material.Neon)
			head.CanCollide = false
			local light = Instance.new("SpotLight")
			light.Angle = 100
			light.Brightness = 2.2
			light.Range = 90
			light.Face = Enum.NormalId.Bottom
			light.Shadows = false  -- coûteux, et 4 projecteurs par plot
			light.Parent = head
		end
	end

	-- Drapeaux de corner, aux quatre angles du plateau.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x = origin.X + sx * (width / 2 - 2)
			local z = origin.Z + sz * (length / 2 - 2)
			local pole = part("MatCorner", Vector3.new(0.4, 8, 0.4),
				CFrame.new(x, origin.Y + 4, z), Color3.fromRGB(240, 240, 240), folder)
			pole.CanCollide = false
			local flag = part("Drapeau", Vector3.new(0.2, 2.2, 3),
				CFrame.new(x + sx * 1.6, origin.Y + 7, z), Color3.fromRGB(255, 90, 90), folder, Enum.Material.Fabric)
			flag.CanCollide = false
		end
	end
end

-- Emplacements du terrain, dans l'ordre où ils se débloquent : base par base
-- (attaque → gardien), centrés sur la largeur. Retourne une liste de
-- { base, position: Vector3 } de Config.totalSlots() entrées.
function FieldBuilder.slotLayout(field)
	local slots = {}
	local startZ = (field.barrierZ or (field.origin.Z + Config.Field.shootLine)) + 14
	local endZ = field.goalZ - Config.Field.goalDepth - 8
	local spanZ = endZ - startZ

	for _, base in Config.Bases do
		local z = startZ + spanZ * base.depth
		for c = 0, base.slots - 1 do
			local x = field.origin.X + ((c + 0.5) / base.slots - 0.5) * (field.width - 14)
			table.insert(slots, {
				base = base.name,
				position = Vector3.new(x, field.origin.Y + 3.5, z),
			})
		end
	end
	return slots
end

-- Les tiges du baby-foot : une barre traversante par base. Purement visuelle
-- (la balle est simulée sans collision), mais c'est ce qui donne la lecture
-- « 4 bases » du terrain.
function FieldBuilder.buildBases(field)
	if field.basesFolder then field.basesFolder:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Bases"
	folder.Parent = field.root
	field.basesFolder = folder

	local startZ = (field.barrierZ or (field.origin.Z + Config.Field.shootLine)) + 14
	local endZ = field.goalZ - Config.Field.goalDepth - 8
	local spanZ = endZ - startZ

	for i, base in Config.Bases do
		local z = startZ + spanZ * base.depth
		local bar = part("Base" .. i, Vector3.new(field.width + 8, 1.2, 1.2),
			CFrame.new(field.origin.X, field.origin.Y + 7, z),
			Color3.fromRGB(190, 195, 210), folder, Enum.Material.Metal)
		bar.CanCollide = false

		-- Étiquette de la base (Attaque / Milieu / Défense / Gardien).
		local sign = Instance.new("BillboardGui")
		sign.Name = "Etiquette"
		sign.Size = UDim2.fromOffset(190, 34)
		sign.StudsOffset = Vector3.new(0, 3, 0)
		sign.AlwaysOnTop = false
		sign.Parent = bar
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Text = string.format("%s (%d)", base.name, base.slots)
		lbl.Font = Enum.Font.GothamBold
		lbl.TextScaled = true
		lbl.TextColor3 = Color3.fromRGB(220, 225, 240)
		lbl.TextStrokeTransparency = 0.4
		lbl.Parent = sign
	end
end

-- Place l'équipe sur les bases. `squad` = liste de cartes { name, rarity },
-- au plus Config.MaxSquad. Les emplacements non pourvus restent vides (visibles
-- comme un socle gris) : on voit ce qu'il reste à débloquer.
function FieldBuilder.placeSquad(field, squad, unlockedSlots: number)
	field.figuresFolder:ClearAllChildren()
	local slots = FieldBuilder.slotLayout(field)

	for i, slot in slots do
		local unlocked = i <= unlockedSlots
		local card = squad[i]

		if not card then
			-- Socle vide : emplacement débloqué mais sans joueur, ou verrouillé.
			local pad = Instance.new("Part")
			pad.Name = "Emplacement"
			pad.Size = Vector3.new(4, 0.4, 4)
			pad.Anchored = true
			pad.CanCollide = false
			pad.Material = Enum.Material.SmoothPlastic
			pad.Color = if unlocked then Color3.fromRGB(90, 95, 110) else Color3.fromRGB(45, 47, 58)
			pad.Transparency = if unlocked then 0.2 else 0.6
			pad.CFrame = CFrame.new(slot.position - Vector3.new(0, 3.3, 0))
			pad.Parent = field.figuresFolder
		else
			local rarity = Config.rarity(card.rarity)
			local fig = Instance.new("Part")
			fig.Name = "Figure"
			fig.Size = Vector3.new(3, 6, 3)
			fig.Anchored = true
			fig.CanCollide = false
			fig.Color = rarity.color
			fig.Material = if card.rarity == "commun" then Enum.Material.SmoothPlastic else Enum.Material.Neon
			fig.CFrame = CFrame.new(slot.position)
			-- Lu par le moteur de tir : l'argent d'un joueur touché dépend de sa rareté.
			fig:SetAttribute("Mult", rarity.mult)
			fig:SetAttribute("Rarete", rarity.name)
			fig:SetAttribute("Joueur", card.name)
			fig.Parent = field.figuresFolder

			local head = Instance.new("Part")
			head.Name = "Tete"
			head.Shape = Enum.PartType.Ball
			head.Size = Vector3.new(2.4, 2.4, 2.4)
			head.Anchored = true
			head.CanCollide = false
			head.Color = Color3.fromRGB(255, 220, 180)
			head.CFrame = fig.CFrame + Vector3.new(0, 3.8, 0)
			head.Parent = fig

			local tag = Instance.new("BillboardGui")
			tag.Name = "Nom"
			tag.Size = UDim2.fromOffset(180, 40)
			tag.StudsOffset = Vector3.new(0, 4.6, 0)
			tag.Parent = fig
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Text = string.format("%s\n%s ×%s", card.name, rarity.name, Config.abbreviate(rarity.mult))
			lbl.Font = Enum.Font.GothamBold
			lbl.TextScaled = true
			lbl.TextColor3 = rarity.color
			lbl.TextStrokeTransparency = 0.3
			lbl.Parent = tag
		end
	end
end

-- Zone d'entraînement (haltères) + spawn, à côté du terrain.
function FieldBuilder.buildTrainingArea(originOverride: Vector3?)
	local o = originOverride or Config.Field.origin
	local model = Instance.new("Model")
	model.Name = "ZoneEntrainement"
	model.Parent = workspace

	local base = Vector3.new(o.X - Config.Field.width, 1, o.Z + Config.Field.shootLine)
	part("SolGym", Vector3.new(40, 1, 40),
		CFrame.new(base), Color3.fromRGB(50, 50, 65), model, Enum.Material.Metal)

	-- Râtelier d'haltères (déco)
	for i = -1, 1 do
		local db = part("Haltere", Vector3.new(2, 2, 8),
			CFrame.new(base.X + i * 8, base.Y + 2, base.Z),
			Color3.fromRGB(30, 30, 40), model, Enum.Material.Metal)
		part("Poids1", Vector3.new(3.5, 3.5, 2),
			CFrame.new(base.X + i * 8, base.Y + 2, base.Z - 3), Color3.fromRGB(20, 20, 25), model, Enum.Material.Metal)
		part("Poids2", Vector3.new(3.5, 3.5, 2),
			CFrame.new(base.X + i * 8, base.Y + 2, base.Z + 3), Color3.fromRGB(20, 20, 25), model, Enum.Material.Metal)
		local _ = db
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(base.X, base.Y + 1, base.Z + 14)
	spawn.Color = Color3.fromRGB(255, 210, 60)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = model

	return { model = model, trainPos = base }
end

-- Grand panneau de classement mondial, placé au fond derrière le but.
function FieldBuilder.buildLeaderboardBoard(field): SurfaceGui
	local stand = Instance.new("Model")
	stand.Name = "PanneauClassement"
	stand.Parent = workspace

	local z = field.goalZ + 24
	part("Pied", Vector3.new(4, 30, 4),
		CFrame.new(field.origin.X, field.origin.Y + 15, z), Color3.fromRGB(30, 30, 40), stand, Enum.Material.Metal)

	local board = part("Ecran", Vector3.new(60, 34, 2),
		CFrame.new(field.origin.X, field.origin.Y + 40, z),
		Color3.fromRGB(12, 14, 20), stand, Enum.Material.SmoothPlastic)
	board.Orientation = Vector3.new(0, 180, 0)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "ClassementGui"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(900, 520)
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.14)
	title.BackgroundColor3 = Color3.fromRGB(255, 180, 40)
	title.Text = "🏆 CLASSEMENT MONDIAL — Argent total"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(20, 20, 20)
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromScale(0, 0.16)
	list.Size = UDim2.fromScale(1, 0.84)
	list.BackgroundTransparency = 1
	list.Text = "Chargement…"
	list.Font = Enum.Font.GothamBold
	list.TextScaled = false
	list.TextSize = 34
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(240, 240, 255)
	list.Parent = gui

	return gui
end

return FieldBuilder
