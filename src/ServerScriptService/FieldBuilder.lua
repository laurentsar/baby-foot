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

	-- Dossier des figurines (peuplé dynamiquement par le moteur de tir)
	local figures = Instance.new("Folder")
	figures.Name = "Figures"
	figures.Parent = root

	return {
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
		rows = F.rows,
	}
end

-- (Re)peuple les rangées de figurines selon le nb de joueurs voulu.
function FieldBuilder.populateFigures(field, count: number)
	field.figuresFolder:ClearAllChildren()
	if count <= 0 then return end

	-- Les figurines sont bien plus nombreuses qu'avant : on privilégie des rangées
	-- larges (8 de front) plutôt qu'un carré, sinon elles s'empilent en profondeur
	-- sur la moitié de terrain qui reste.
	local ROW_MAX = 8
	local rows = math.clamp(math.ceil(count / ROW_MAX), 1, 10)
	local placed = 0

	-- Réparties entre la ligne d'engagement et le but : même un tir faible touche
	-- les figurines proches, les rangées lointaines exigent plus de puissance.
	local startZ = (field.barrierZ or (field.origin.Z + Config.Field.shootLine)) + 8
	local endZ = field.goalZ - Config.Field.goalDepth - 6
	local spanZ = endZ - startZ

	for r = 0, rows - 1 do
		local z = startZ + (rows == 1 and spanZ / 2 or (spanZ * r / (rows - 1)))
		-- Le reste est réparti sur les rangées restantes puis centré : une dernière
		-- rangée incomplète reste au milieu du terrain au lieu de coller à gauche.
		local inRow = math.ceil((count - placed) / (rows - r))
		for c = 0, inRow - 1 do
			if placed >= count then break end
			local x = field.origin.X + ((c + 0.5) / inRow - 0.5) * (field.width - 8)
			local fig = Instance.new("Part")
			fig.Name = "Figure"
			fig.Size = Vector3.new(2.4, 5, 2.4)
			fig.Anchored = true
			fig.Color = Color3.fromRGB(230, 60, 60)
			fig.Material = Enum.Material.SmoothPlastic
			fig.CFrame = CFrame.new(x, field.origin.Y + 3, z)
			fig.Parent = field.figuresFolder
			-- tête déco
			local head = Instance.new("Part")
			head.Shape = Enum.PartType.Ball
			head.Size = Vector3.new(2, 2, 2)
			head.Anchored = true
			head.Color = Color3.fromRGB(255, 220, 180)
			head.CFrame = fig.CFrame + Vector3.new(0, 3.2, 0)
			head.Parent = fig
			placed += 1
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
