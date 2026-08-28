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
	-- Décor purement visuel : une passe d'ombre sur ~200 parts par plot coûte
	-- cher pour un jeu joué au téléphone, et rien ici ne se lit à son ombre.
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Contenu d'un panneau de classement : titre, liste des 10 premiers, bandeau du
-- compte à rebours. Partagé par le panneau du stade et celui du parvis — les
-- deux sont ensuite alimentés par Leaderboard.attach.
-- `accent` colore le bandeau de titre (chaque classement a sa couleur quand ils
-- sont côte à côte). `showTimer` : n'afficher le compte à rebours du coup de
-- sifflet que sur un seul des trois écrans, sinon on le répète trois fois.
function FieldBuilder.boardGui(surface: BasePart, face: Enum.NormalId,
	accent: Color3?, showTimer: boolean?): SurfaceGui
	local ACC = accent or Color3.fromRGB(255, 180, 40)
	local hasTimer = showTimer ~= false   -- par défaut oui (panneaux du parvis)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ClassementGui"
	gui.Face = face
	-- Canvas plus compact et net qu'avant (900x520) : le panneau physique est lui
	-- aussi plus petit, l'ensemble se lit mieux de loin.
	gui.CanvasSize = Vector2.new(520, 620)
	gui.Parent = surface

	-- Fond arrondi + léger dégradé : c'est ce qui fait « joli » sur une surface
	-- plate. Tout le contenu vit dans ce cadre, avec une marge.
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	root.BorderSizePixel = 0
	root.Parent = gui
	local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 26); rc.Parent = root
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(26, 30, 44), Color3.fromRGB(12, 13, 20))
	grad.Parent = root
	local stroke = Instance.new("UIStroke")
	stroke.Color = ACC; stroke.Thickness = 3; stroke.Transparency = 0.15; stroke.Parent = root
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 18); pad.PaddingRight = UDim.new(0, 18)
	pad.PaddingTop = UDim.new(0, 14); pad.PaddingBottom = UDim.new(0, 14)
	pad.Parent = root

	local title = Instance.new("TextLabel")
	title.Name = "Title"   -- mis à jour par Leaderboard.refresh
	title.Size = UDim2.fromScale(1, 0.13)
	title.BackgroundColor3 = ACC
	title.Text = "🏆 CLASSEMENT"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(18, 18, 22)
	title.Parent = root
	local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 14); tc.Parent = title
	local tp = Instance.new("UIPadding")
	tp.PaddingLeft = UDim.new(0, 10); tp.PaddingRight = UDim.new(0, 10); tp.Parent = title

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromScale(0, 0.16)
	list.Size = UDim2.fromScale(1, if hasTimer then 0.68 else 0.82)
	list.BackgroundTransparency = 1
	list.Text = "Chargement…"
	list.Font = Enum.Font.GothamBold
	list.TextScaled = false
	list.TextSize = 22
	list.TextWrapped = false   -- pas de retour à la ligne : une entrée = une ligne
	list.LineHeight = 1.2
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(238, 240, 252)
	list.Parent = root

	-- Bandeau du bas : compte à rebours du prochain coup de sifflet (bonus argent).
	-- Un seul écran le porte quand les trois sont côte à côte.
	if hasTimer then
		local timer = Instance.new("TextLabel")
		timer.Name = "Timer"
		timer.Position = UDim2.fromScale(0, 0.87)
		timer.Size = UDim2.fromScale(1, 0.13)
		timer.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
		timer.Text = "⏱ …"
		timer.Font = Enum.Font.GothamBlack
		timer.TextScaled = true
		timer.TextColor3 = Color3.fromRGB(255, 210, 60)
		timer.Parent = root
		local tmc = Instance.new("UICorner"); tmc.CornerRadius = UDim.new(0, 12); tmc.Parent = timer
	end

	return gui
end

-- Construit le baby-foot. Retourne les infos utiles au moteur de tir.
-- originOverride permet un plot par joueur (offset dans le monde).
-- bigGoal = pass Grand Terrain. Il élargit le BUT, il n'allonge plus le terrain :
-- allonger éloignait le fond et rendait le but plus dur, l'inverse de ce que le
-- pass promet.
-- sizeMult = agrandissement du terrain gagné par les renaissances (voir
-- Config.fieldSizeMultiplier) : le but s'éloigne d'autant, il faut plus de
-- puissance pour l'atteindre. extraSlots = emplacements de joueurs bonus gagnés
-- par les renaissances (voir Config.extraSlotsFromRebirths), répartis sur les
-- 4 bases.
-- worldIndex = monde débloqué (Config.Worlds) : il ne change que l'habillage
-- (sol, murs, couleur du but). Le multiplicateur d'argent, lui, est appliqué
-- côté serveur — un décor ne doit jamais porter une règle de jeu.
function FieldBuilder.build(bigGoal: boolean, originOverride: Vector3?, sizeMult: number?, extraSlots: number?,
	worldIndex: number?)
	local F = Config.Field
	local mult = sizeMult or 1
	local length = F.length * mult
	local width = F.width * mult
	local origin = originOverride or F.origin
	local world = Config.world(worldIndex)
	local GROUND = world.ground or GREEN
	local WALL = world.wall or WOOD
	local ACCENT = world.accent or NEON

	local root = Instance.new("Model")
	root.Name = "BabyFoot"
	root.Parent = workspace

	-- Plateau du terrain
	local pitchMaterial = world.groundMaterial or Enum.Material.Grass
	part("Plateau", Vector3.new(width, 1, length),
		CFrame.new(origin), GROUND, root, pitchMaterial)

	-- PELOUSE TONDUE : bandes alternées dans le sens de la longueur, comme sur un
	-- vrai terrain. C'est le détail qui fait le plus pour l'œil, et il ne coûte
	-- que 8 parts plates : les bandes sombres sont posées par-dessus le plateau,
	-- les claires sont le plateau lui-même.
	local STRIPES = 8
	local stripeW = width / STRIPES
	for i = 0, STRIPES - 1, 2 do
		local x = origin.X - width / 2 + (i + 0.5) * stripeW
		local band = part("Bande", Vector3.new(stripeW, 1.02, length),
			CFrame.new(x, origin.Y + 0.01, origin.Z),
			Color3.new(GROUND.R * 0.86, GROUND.G * 0.86, GROUND.B * 0.86), root, pitchMaterial)
		band.CanCollide = false
	end

	-- MARQUAGES AU SOL (peinture, sans collision) : ligne médiane, rond central,
	-- surface de réparation devant le but, ligne de but.
	local LINE = Color3.fromRGB(242, 244, 248)
	local function paint(name: string, size: Vector3, cf: CFrame)
		local p = part(name, size, cf, LINE, root, Enum.Material.SmoothPlastic)
		p.CanCollide = false
		return p
	end

	paint("LigneMilieu", Vector3.new(width, 1.06, 1), CFrame.new(origin.X, origin.Y + 0.03, origin.Z))

	-- Rond central : 16 segments d'arc. Un vrai cercle demanderait un mesh, et à
	-- cette échelle 16 segments se lisent comme un rond parfait.
	local circleR = math.min(width, length) * 0.11
	for i = 0, 15 do
		local a = (i / 16) * math.pi * 2
		local seg = paint("RondCentral", Vector3.new(0.8, 1.06, circleR * 0.42),
			CFrame.new(origin.X + math.sin(a) * circleR, origin.Y + 0.03, origin.Z + math.cos(a) * circleR)
				* CFrame.Angles(0, -a, 0))
		seg.Transparency = 0.05
	end
	paint("PointCentral", Vector3.new(1.6, 1.06, 1.6), CFrame.new(origin.X, origin.Y + 0.03, origin.Z))

	-- Murs latéraux
	local half = length / 2
	part("MurGauche", Vector3.new(2, F.wallHeight, length),
		CFrame.new(origin.X - width / 2 - 1, origin.Y + F.wallHeight / 2, origin.Z), WALL, root)
	part("MurDroit", Vector3.new(2, F.wallHeight, length),
		CFrame.new(origin.X + width / 2 + 1, origin.Y + F.wallHeight / 2, origin.Z), WALL, root)

	-- Fond du terrain = LE BUT adverse (cible du x3). Il ne fait qu'une fraction
	-- de la largeur : il faut viser, une balle qui arrive à côté ne marque pas.
	local goalZ = origin.Z + half + F.goalDepth / 2
	local goalWidth = math.min(width * F.goalWidthRatio * (if bigGoal then Config.BigGoalMultiplier else 1),
		width - 8)
	-- Bouche du but : un fond sombre et mat, pas un bloc néon coloré. C'est le
	-- cadre blanc (poteaux + barre) et le filet qui donnent l'allure d'un vrai
	-- but. GOAL_MOUTH est aussi la couleur de repli après le flash de but
	-- (cf. Main.server) : la garder synchronisée là-bas.
	local GOAL_MOUTH = Color3.fromRGB(24, 26, 34)
	local goalHeight = F.wallHeight + 4
	local goal = part("But", Vector3.new(goalWidth, goalHeight, F.goalDepth),
		CFrame.new(origin.X, origin.Y + goalHeight / 2, goalZ), GOAL_MOUTH, root, Enum.Material.SmoothPlastic)
	goal.Transparency = 0.15

	-- Cadre blanc : deux poteaux + une barre transversale, en plastique mat.
	local POST = Color3.fromRGB(245, 245, 250)
	local postZ = goalZ - F.goalDepth / 2
	local postH = goalHeight + 4
	for _, side in { -1, 1 } do
		part("Poteau", Vector3.new(1.6, postH, 1.6),
			CFrame.new(origin.X + side * goalWidth / 2, origin.Y + postH / 2, postZ),
			POST, root, Enum.Material.SmoothPlastic)
		local sidePanel = (width - goalWidth) / 2
		part("FondPlein", Vector3.new(sidePanel, F.wallHeight, F.goalDepth),
			CFrame.new(origin.X + side * (goalWidth + sidePanel) / 2,
				origin.Y + F.wallHeight / 2, goalZ), WALL, root)
	end
	-- Barre transversale, posée sur les deux poteaux.
	part("BarreTransversale", Vector3.new(goalWidth + 1.6, 1.6, 1.6),
		CFrame.new(origin.X, origin.Y + postH, postZ), POST, root, Enum.Material.SmoothPlastic)

	-- Ligne de but + surface de réparation : c'est ce qui fait lire le fond comme
	-- un vrai but et pas comme un simple mur lumineux.
	local goalLineZ = goalZ - F.goalDepth / 2
	paint("LigneDeBut", Vector3.new(width, 1.06, 1), CFrame.new(origin.X, origin.Y + 0.03, goalLineZ))
	local boxW = math.min(goalWidth * 2.1, width - 6)
	local boxD = math.min(length * 0.16, 30)
	paint("SurfaceCote", Vector3.new(0.9, 1.06, boxD),
		CFrame.new(origin.X - boxW / 2, origin.Y + 0.03, goalLineZ - boxD / 2))
	paint("SurfaceCote", Vector3.new(0.9, 1.06, boxD),
		CFrame.new(origin.X + boxW / 2, origin.Y + 0.03, goalLineZ - boxD / 2))
	paint("SurfaceFront", Vector3.new(boxW, 1.06, 0.9),
		CFrame.new(origin.X, origin.Y + 0.03, goalLineZ - boxD))

	-- FILET DU BUT : une grille de fils fins tendue au fond de la cage. Rien de
	-- physique (la balle est simulée), mais sans filet le but ressemblait à une
	-- vitre bleue. Nombre de fils FIXE : la cage peut doubler de largeur avec le
	-- pass Grand Terrain, on ne veut pas doubler le nombre de parts avec elle.
	do
		local netFolder = Instance.new("Folder")
		netFolder.Name = "Filet"
		netFolder.Parent = root
		local netZ = goalZ + F.goalDepth / 2 - 0.6
		local netH = F.wallHeight + 2
		local netY = origin.Y + netH / 2
		for i = 1, 9 do
			local x = origin.X + (i / 10 - 0.5) * goalWidth
			local wire = part("FilVertical", Vector3.new(0.18, netH, 0.18),
				CFrame.new(x, netY, netZ), Color3.fromRGB(238, 240, 245), netFolder)
			wire.CanCollide = false
			wire.Transparency = 0.25
		end
		for i = 1, 5 do
			local y = origin.Y + (i / 6) * netH
			local wire = part("FilHorizontal", Vector3.new(goalWidth, 0.18, 0.18),
				CFrame.new(origin.X, y, netZ), Color3.fromRGB(238, 240, 245), netFolder)
			wire.CanCollide = false
			wire.Transparency = 0.25
		end
	end

	-- Mur derrière ton point de tir, PERCÉ au milieu : c'est par ce trou qu'on
	-- entre depuis l'allée. Deux panneaux de part et d'autre de l'ouverture.
	--
	-- RECULÉ (backOffset) : le mur se trouvait à 4 studs derrière le point de tir,
	-- ce qui laissait une zone de jeu à l'étroit. On le repousse pour dégager de la
	-- place derrière le tireur — le mur invisible d'arrière (plus bas) suit.
	local shootZ = origin.Z + F.shootLine
	local backOffset = 40   -- mur d'entrée bien reculé : zone de jeu large et dégagée
	local wallZ = shootZ - backOffset
	local gap = Config.Entrance.pathWidth + 4
	local panel = (width - gap) / 2
	for _, side in { -1, 1 } do
		part("MurArriere", Vector3.new(panel, F.wallHeight, 2),
			CFrame.new(origin.X + side * (gap + panel) / 2, origin.Y + F.wallHeight / 2, wallZ),
			WOOD, root)
	end
	-- Encadrement du passage, pour qu'on voie l'entrée de loin.
	for _, side in { -1, 1 } do
		part("MontantEntree", Vector3.new(2, F.wallHeight + 6, 2.5),
			CFrame.new(origin.X + side * gap / 2, origin.Y + (F.wallHeight + 6) / 2, wallZ),
			Color3.fromRGB(255, 210, 60), root, Enum.Material.Neon)
	end
	part("LinteauEntree", Vector3.new(gap + 4, 2, 2.5),
		CFrame.new(origin.X, origin.Y + F.wallHeight + 5, wallZ),
		Color3.fromRGB(255, 210, 60), root, Enum.Material.Neon)

	-- PANNEAUX de la zone de tir, à ton nom d'équipe : QUÊTES à gauche, STATS
	-- D'ÉQUIPE à droite. Face Back = le +Z, côté où se tient le tireur (il est à un
	-- Z plus grand que le mur). Remplis côté serveur (updateQuestBoard /
	-- updateTeamBoard) ; ici on ne pose que le support et les labels.
	local questGui
	local teamGui
	do
		local leftX = origin.X - (gap + panel) / 2
		local boardW = math.min(panel - 4, 40)
		-- Panneau plus haut que le mur : il monte au-dessus pour loger reco + quêtes.
		local qboard = part("PanneauQuetes", Vector3.new(boardW, 16, 0.5),
			CFrame.new(leftX, origin.Y + 8, wallZ + 1.1),
			Color3.fromRGB(14, 16, 24), root, Enum.Material.SmoothPlastic)
		questGui = Instance.new("SurfaceGui")
		questGui.Name = "QuetesGui"
		questGui.Face = Enum.NormalId.Back
		questGui.CanvasSize = Vector2.new(560, 360)
		questGui.Parent = qboard
		local qroot = Instance.new("Frame")
		qroot.Size = UDim2.fromScale(1, 1)
		qroot.BackgroundTransparency = 1
		qroot.Parent = questGui
		local qpad = Instance.new("UIPadding")
		qpad.PaddingLeft = UDim.new(0, 14); qpad.PaddingRight = UDim.new(0, 14)
		qpad.PaddingTop = UDim.new(0, 10); qpad.PaddingBottom = UDim.new(0, 10)
		qpad.Parent = qroot
		local team = Instance.new("TextLabel")
		team.Name = "Team"
		team.Size = UDim2.fromScale(1, 0.16)
		team.BackgroundColor3 = Color3.fromRGB(150, 110, 235)
		team.Text = "📜 QUÊTES"
		team.Font = Enum.Font.GothamBlack
		team.TextScaled = true
		team.TextColor3 = Color3.fromRGB(245, 245, 255)
		team.Parent = qroot
		local qtc = Instance.new("UICorner"); qtc.CornerRadius = UDim.new(0, 10); qtc.Parent = team
		local qlist = Instance.new("TextLabel")
		qlist.Name = "List"
		qlist.Position = UDim2.fromScale(0, 0.19)
		qlist.Size = UDim2.fromScale(1, 0.81)
		qlist.BackgroundTransparency = 1
		qlist.Text = "…"
		qlist.Font = Enum.Font.GothamBold
		qlist.TextSize = 19
		qlist.LineHeight = 1.12
		qlist.TextXAlignment = Enum.TextXAlignment.Left
		qlist.TextYAlignment = Enum.TextYAlignment.Top
		qlist.TextColor3 = Color3.fromRGB(232, 234, 246)
		qlist.Parent = qroot
	end

	-- PANNEAU STATS D'ÉQUIPE (mur de droite) : même système que le classement, mais
	-- tes chiffres à toi depuis le début (buts, argent, puissance, gemmes…).
	do
		local rightX = origin.X + (gap + panel) / 2
		local boardW = math.min(panel - 4, 40)
		local tboard = part("PanneauEquipe", Vector3.new(boardW, 16, 0.5),
			CFrame.new(rightX, origin.Y + 8, wallZ + 1.1),
			Color3.fromRGB(14, 16, 24), root, Enum.Material.SmoothPlastic)
		teamGui = Instance.new("SurfaceGui")
		teamGui.Name = "EquipeGui"
		teamGui.Face = Enum.NormalId.Back
		teamGui.CanvasSize = Vector2.new(560, 360)
		teamGui.Parent = tboard
		local troot = Instance.new("Frame")
		troot.Size = UDim2.fromScale(1, 1)
		troot.BackgroundTransparency = 1
		troot.Parent = teamGui
		local tpad = Instance.new("UIPadding")
		tpad.PaddingLeft = UDim.new(0, 14); tpad.PaddingRight = UDim.new(0, 14)
		tpad.PaddingTop = UDim.new(0, 10); tpad.PaddingBottom = UDim.new(0, 10)
		tpad.Parent = troot
		local tteam = Instance.new("TextLabel")
		tteam.Name = "Team"
		tteam.Size = UDim2.fromScale(1, 0.16)
		tteam.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
		tteam.Text = "📊 STATS"
		tteam.Font = Enum.Font.GothamBlack
		tteam.TextScaled = true
		tteam.TextColor3 = Color3.fromRGB(20, 20, 24)
		tteam.Parent = troot
		local ttc = Instance.new("UICorner"); ttc.CornerRadius = UDim.new(0, 10); ttc.Parent = tteam
		local tlist = Instance.new("TextLabel")
		tlist.Name = "List"
		tlist.Position = UDim2.fromScale(0, 0.19)
		tlist.Size = UDim2.fromScale(1, 0.81)
		tlist.BackgroundTransparency = 1
		tlist.Text = "…"
		tlist.Font = Enum.Font.GothamBold
		tlist.TextSize = 26
		tlist.LineHeight = 1.15
		tlist.TextXAlignment = Enum.TextXAlignment.Left
		tlist.TextYAlignment = Enum.TextYAlignment.Top
		tlist.TextColor3 = Color3.fromRGB(232, 234, 246)
		tlist.Parent = troot
	end

	-- AFFICHE AU-DESSUS de l'entrée (banderole de tribune) : posée PLUS HAUT que le
	-- linteau pour ne PAS barrer le passage (elle traînait en plein milieu de
	-- l'ouverture). Largeur limitée à l'ouverture pour ne pas mordre sur les
	-- panneaux Quêtes/Stats. Contenu fixe.
	do
		local banner = part("Affiche", Vector3.new(gap + 6, 4.5, 0.4),
			CFrame.new(origin.X, origin.Y + F.wallHeight + 8, wallZ + 1.1),
			Color3.fromRGB(214, 38, 48), root, Enum.Material.SmoothPlastic)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Back
		sg.CanvasSize = Vector2.new(420, 80)
		sg.Parent = banner
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundColor3 = Color3.fromRGB(214, 38, 48)
		lbl.Text = "⚽ BABY-FOOT POWER — VISE LE SOMMET 🏆"
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextScaled = true
		lbl.TextColor3 = Color3.fromRGB(245, 245, 250)
		lbl.Parent = sg
		local lp = Instance.new("UIPadding")
		lp.PaddingLeft = UDim.new(0, 8); lp.PaddingRight = UDim.new(0, 8)
		lp.Parent = lbl
	end

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
	-- Arrière : deux panneaux, l'ouverture de l'allée reste franchissable. Le
	-- terrain lui-même reste protégé par la barrière avant, plus loin.
	local invPanel = (width + 8 - gap) / 2
	for _, side in { -1, 1 } do
		invisibleWall("MurInvArriere", Vector3.new(invPanel, fh, 1),
			CFrame.new(origin.X + side * (gap + invPanel) / 2, origin.Y + fh / 2, wallZ - 6))
	end

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
		goalHalfWidth = goalWidth / 2,
		shootPos = Vector3.new(origin.X, origin.Y + 2, shootZ),
		shootPad = shootPad,
		barrierZ = barrierZ,
		crowd = {},
		bases = Config.basesWithExtra(extraSlots),
		world = world,
		questGui = questGui,   -- panneau de quêtes, rempli par updateQuestBoard (serveur)
		teamGui = teamGui,     -- panneau stats d'équipe, rempli par updateTeamBoard (serveur)
	}

	FieldBuilder.buildBases(field)
	FieldBuilder.buildWalkways(field)
	FieldBuilder.buildDecor(field)
	FieldBuilder.buildPlotBoundary(field, origin)
	return field
end

-- MURS INVISIBLES SUR LES 4 CÔTÉS DE TOUT LE PLOT (parvis + allée + zone
-- d'entraînement + terrain), pas seulement autour du baby-foot : sans ça, un
-- joueur qui s'écarte du chemin peut sortir de la zone construite et tomber
-- dans le vide. Recalculé à chaque construction du terrain, donc à chaque
-- renaissance quand celui-ci grandit — le côté "terrain" du rectangle suit,
-- le côté "parvis" ne bouge jamais (l'entrée ne grandit pas).
function FieldBuilder.buildPlotBoundary(field, origin: Vector3)
	local F = Config.Field
	local E = Config.Entrance

	local shootZ = origin.Z + F.shootLine
	local plazaZ = shootZ - E.plazaOffset
	local nearZ = plazaZ - E.plazaSize / 2 - 90   -- derrière le parvis (pelouse, arbres épars)
	local farZ = field.goalZ + 40                 -- derrière le panneau de classement

	-- Le rectangle doit couvrir les deux annexes à largeur FIXE (gym et plateforme
	-- des œufs, à ±1,6 largeur) ET le terrain agrandi par les renaissances.
	local halfX = math.max(F.width * 1.6 + 36, field.width / 2 + 50)

	local folder = Instance.new("Folder")
	folder.Name = "MursPlot"
	folder.Parent = field.root

	local function wall(name: string, size: Vector3, cf: CFrame)
		local w = part(name, size, cf, Color3.fromRGB(255, 255, 255), folder)
		w.Transparency = 1
		w.CanCollide = true
		return w
	end

	local h = 70
	local midZ = (farZ + nearZ) / 2
	local spanZ = farZ - nearZ

	-- SOL DU PLOT. La Baseplate du projet ne fait que 400 studs et ne couvre donc
	-- que le premier plot : à partir du deuxième, tout ce qui n'était pas un
	-- élément construit (les abords du parvis, les côtés de l'allée, le pourtour
	-- du gym) était un trou, et on tombait dans le vide. Une seule dalle par plot
	-- suffit, posée juste sous les surfaces construites.
	local ground = part("SolPlot", Vector3.new(halfX * 2, 2, spanZ),
		CFrame.new(origin.X, origin.Y - 1.5, midZ),
		(field.world and field.world.ground) or Color3.fromRGB(48, 92, 52), folder,
		(field.world and field.world.groundMaterial) or Enum.Material.Grass)
	ground.CanCollide = true

	wall("PlotGauche", Vector3.new(1, h, spanZ), CFrame.new(origin.X - halfX, origin.Y + h / 2, midZ))
	wall("PlotDroit", Vector3.new(1, h, spanZ), CFrame.new(origin.X + halfX, origin.Y + h / 2, midZ))
	wall("PlotFond", Vector3.new(halfX * 2, h, 1), CFrame.new(origin.X, origin.Y + h / 2, farZ))
	wall("PlotArriere", Vector3.new(halfX * 2, h, 1), CFrame.new(origin.X, origin.Y + h / 2, nearZ))
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

			-- Nez de marche clair : sans lui, les trois gradins se lisent comme un
			-- seul bloc gris depuis le point de tir.
			local nose = part("NezDeMarche", Vector3.new(7.4, 0.5, length + 20),
				CFrame.new(x, origin.Y + h + 0.2, origin.Z), Color3.fromRGB(150, 155, 172),
				folder, Enum.Material.Concrete)
			nose.CanCollide = false

			local seats = Config.Crowd.seatsPerTier
			for i = 0, seats - 1 do
				local z = origin.Z - (length + 12) / 2 + (i + 0.5) * (length + 12) / seats
				-- Corps + tête sont soudés dans un Model : le public saute d'un
				-- bloc quand on marque (voir FieldBuilder.cheer).
				local fan = Instance.new("Model")
				fan.Name = "Spectateur"
				fan.Parent = folder

				local body = part("Corps", Vector3.new(2, 3, 2),
					CFrame.new(x, origin.Y + h + 1.5, z),
					CROWD[(i + tier * 2) % #CROWD + 1], fan)
				body.CanCollide = false
				local head = part("Tete", Vector3.new(1.6, 1.6, 1.6),
					CFrame.new(x, origin.Y + h + 3.8, z),
					Color3.fromRGB(235, 200, 165), fan)
				head.Shape = Enum.PartType.Ball
				head.CanCollide = false
				fan.PrimaryPart = body
				table.insert(field.crowd, fan)
			end
		end
	end

	-- TOITURE DE TRIBUNE : un auvent au-dessus du dernier gradin, porté par deux
	-- poteaux. C'est ce qui donne au stade sa silhouette — sans toit, les gradins
	-- ressemblent à des marches posées dans un champ.
	for _, side in { -1, 1 } do
		local xOuter = origin.X + side * (width / 2 + 7 + 2 * 7)
		local roofY = origin.Y + 26
		local roof = part("Toiture", Vector3.new(26, 1, length + 24),
			CFrame.new(xOuter + side * 4, roofY, origin.Z), Color3.fromRGB(38, 42, 54),
			folder, Enum.Material.Metal)
		roof.CanCollide = false
		local edge = part("BordToiture", Vector3.new(1.4, 1.6, length + 24),
			CFrame.new(xOuter + side * 16, roofY - 0.8, origin.Z), Color3.fromRGB(255, 210, 60),
			folder, Enum.Material.Metal)
		edge.CanCollide = false
		for _, sz in { -1, 1 } do
			local pillar = part("PoteauToiture", Vector3.new(1.6, 26, 1.6),
				CFrame.new(xOuter + side * 15, origin.Y + 13, origin.Z + sz * (length / 2 + 6)),
				Color3.fromRGB(48, 52, 66), folder, Enum.Material.Metal)
			pillar.CanCollide = false
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
-- { base, position: Vector3 } de Config.totalSlots() entrées (plus les
-- emplacements bonus de field.bases si le terrain vient d'une renaissance).
function FieldBuilder.slotLayout(field)
	local startZ = (field.barrierZ or (field.origin.Z + Config.Field.shootLine)) + 14
	local endZ = field.goalZ - Config.Field.goalDepth - 8
	local spanZ = endZ - startZ
	local bases = field.bases or Config.Bases

	-- Positions, base par base.
	local perBase = {}
	for b, base in bases do
		perBase[b] = {}
		local z = startZ + spanZ * base.depth
		for c = 0, base.slots - 1 do
			local x = field.origin.X + ((c + 0.5) / base.slots - 0.5) * (field.width - 14)
			table.insert(perBase[b], Vector3.new(x, field.origin.Y + 3.5, z))
		end
	end

	-- L'ORDRE vient de Config.slotOrder, partagé avec le client : c'est lui qui
	-- décide quel emplacement est le n°1. L'écran de composition d'équipe s'en
	-- sert aussi — les deux doivent lire exactement la même liste, sinon poser un
	-- joueur au gardien ne le poserait pas au gardien.
	local slots = {}
	for i, entry in Config.slotOrder(nil, bases) do
		local pos = perBase[entry.baseIndex] and perBase[entry.baseIndex][entry.indexInBase]
		if pos then
			slots[i] = { base = entry.base, position = pos }
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

	for i, base in (field.bases or Config.Bases) do
		local z = startZ + spanZ * base.depth
		local bar = part("Base" .. i, Vector3.new(field.width + 8, 1.2, 1.2),
			CFrame.new(field.origin.X, field.origin.Y + 7, z),
			Color3.fromRGB(190, 195, 210), folder, Enum.Material.Metal)
		bar.CanCollide = false

		-- Étiquette de la base (Attaque / Milieu / Défense / Gardien).
		local sign = Instance.new("BillboardGui")
		sign.Name = "Etiquette"
		sign.Size = UDim2.fromOffset(130, 24)
		sign.StudsOffset = Vector3.new(0, 3, 0)
		sign.AlwaysOnTop = false
		sign.Parent = bar
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Text = string.format("%s (%d)", base.name, base.slots)
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 14
		lbl.TextColor3 = Color3.fromRGB(220, 225, 240)
		lbl.TextStrokeTransparency = 0.4
		lbl.Parent = sign
	end
end

-- PASSERELLES LATÉRALES : une de chaque côté, le long des lignes de touche.
-- Elles courent de la première base à la dernière et relient les bouts des 4
-- tiges par une équerre montante.
--
-- Elles passent SUR LE HAUT DU MUR (origin.Y + wallHeight), pas à la hauteur
-- des tiges. Premier essai : tablier calé sous les tiges, à 6 studs — soit
-- derrière un mur latéral de 10 studs de haut, qui le masquait entièrement
-- depuis le terrain. Une passerelle invisible ne sert à rien.
--
-- Le garde-corps reste du côté EXTÉRIEUR : à l'intérieur il repasserait devant
-- les figurines.
function FieldBuilder.buildWalkways(field)
	if field.walkwayFolder then field.walkwayFolder:Destroy() end
	local W = Config.Walkway
	local folder = Instance.new("Folder")
	folder.Name = "Passerelles"
	folder.Parent = field.root
	field.walkwayFolder = folder

	local bases = field.bases or Config.Bases
	if #bases == 0 then return end

	local startZ = (field.barrierZ or (field.origin.Z + Config.Field.shootLine)) + 14
	local endZ = field.goalZ - Config.Field.goalDepth - 8
	local spanZ = endZ - startZ

	local firstZ = startZ + spanZ * bases[1].depth - W.margin
	local lastZ = startZ + spanZ * bases[#bases].depth + W.margin
	local length = lastZ - firstZ
	local midZ = (firstZ + lastZ) / 2

	-- Le tablier repose sur la crête du mur latéral et déborde vers l'extérieur
	-- jusqu'à l'aplomb des bouts de tiges, où descendent les équerres.
	local barTop = field.origin.Y + 7 + 0.6          -- dessus des tiges
	local deckBottom = field.origin.Y + Config.Field.wallHeight
	local deckY = deckBottom + 0.25
	-- Bord intérieur sur l'axe du mur, bord extérieur au bout des tiges.
	local innerX = field.width / 2
	local outerX = field.width / 2 + W.overhang
	local deckWidth = outerX - innerX
	local cxAbs = (innerX + outerX) / 2

	for _, side in { -1, 1 } do
		local cx = field.origin.X + side * cxAbs

		local deck = part("Tablier", Vector3.new(deckWidth, 0.5, length),
			CFrame.new(cx, deckY, midZ),
			Color3.fromRGB(150, 120, 80), folder, Enum.Material.WoodPlanks)
		deck.CanCollide = W.walkable

		local rail = part("GardeCorps", Vector3.new(0.35, W.railHeight, length),
			CFrame.new(field.origin.X + side * outerX, deckY + 0.25 + W.railHeight / 2, midZ),
			Color3.fromRGB(190, 195, 210), folder, Enum.Material.Metal)
		rail.CanCollide = false

		-- Une équerre entre le tablier et le bout de chaque tige : c'est ce qui
		-- donne la lecture « les 4 tiges tiennent sur la même structure ».
		-- Pas de poteau jusqu'au sol : il traverserait les panneaux
		-- publicitaires, qui occupent la même bande verticale.
		local barEndX = field.origin.X + side * (field.width / 2 + 4)
		for i, base in bases do
			local z = startZ + spanZ * base.depth
			local bracket = part("Equerre" .. i, Vector3.new(0.7, deckBottom - barTop, 0.7),
				CFrame.new(barEndX, (deckBottom + barTop) / 2, z),
				Color3.fromRGB(90, 95, 110), folder, Enum.Material.Metal)
			bracket.CanCollide = false
		end
	end
end

-- Place l'équipe sur les bases. `squad` = liste de cartes { name, rarity },
-- au plus le plafond du joueur (Config.MaxSquad + bonus de renaissance). Les
-- emplacements non pourvus restent vides (visibles comme un socle gris) : on
-- voit ce qu'il reste à débloquer.
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
			pad.CastShadow = false
			pad.Material = Enum.Material.SmoothPlastic
			pad.Color = if unlocked then Color3.fromRGB(90, 95, 110) else Color3.fromRGB(45, 47, 58)
			pad.Transparency = if unlocked then 0.2 else 0.6
			pad.CFrame = CFrame.new(slot.position - Vector3.new(0, 3.3, 0))
			pad.Parent = field.figuresFolder
		else
			local rarity = Config.rarity(card.rarity)
			-- Tenue de base, sauf pour les raretés qui ont la leur (Exclusif).
			local J = Config.skinFor(rarity.key)

			-- Corps = le maillot. La rareté n'est plus portée par la couleur du
			-- corps (tous les joueurs ont le même maillot) : elle passe sur le
			-- socle lumineux et le liseré, sinon on ne distinguerait plus rien.
			local fig = Instance.new("Part")
			fig.Name = "Figure"
			fig.Size = Vector3.new(3, 6, 3)
			fig.Anchored = true
			fig.CanCollide = false
			fig.CastShadow = false
			fig.Color = J.body
			-- glow : la figurine s'éclaire d'elle-même. Réservé aux tenues qui le
			-- demandent — du Neon sur les 41 figurines d'un plot noierait le socle,
			-- qui est justement ce qui porte la lecture des raretés.
			fig.Material = if J.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
			fig.CFrame = CFrame.new(slot.position)
			-- Lu par le moteur de tir : l'argent d'un joueur touché dépend de sa rareté.
			fig:SetAttribute("Mult", rarity.mult)
			fig:SetAttribute("Rarete", rarity.name)
			fig:SetAttribute("Joueur", card.name)
			fig.Parent = field.figuresFolder

			-- Bande rouge verticale + liseré, les couleurs de Paris.
			local stripe = Instance.new("Part")
			stripe.Name = "Bande"
			stripe.Size = Vector3.new(0.9, 6.05, 3.05)
			stripe.Anchored = true
			stripe.CanCollide = false
			stripe.CastShadow = false
			stripe.Color = J.stripe
			stripe.Material = if J.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
			stripe.CFrame = fig.CFrame
			stripe.Parent = fig

			local trim = Instance.new("Part")
			trim.Name = "Liseré"
			trim.Size = Vector3.new(3.1, 0.5, 3.1)
			trim.Anchored = true
			trim.CanCollide = false
			trim.CastShadow = false
			trim.Color = J.trim
			trim.Material = Enum.Material.SmoothPlastic
			trim.CFrame = fig.CFrame + Vector3.new(0, 2.6, 0)
			trim.Parent = fig

			local shorts = Instance.new("Part")
			shorts.Name = "Short"
			shorts.Size = Vector3.new(3.05, 1.8, 3.05)
			shorts.Anchored = true
			shorts.CanCollide = false
			shorts.CastShadow = false
			shorts.Color = J.shorts
			shorts.Material = Enum.Material.SmoothPlastic
			shorts.CFrame = fig.CFrame - Vector3.new(0, 2.1, 0)
			shorts.Parent = fig

			-- Socle lumineux : c'est lui qui porte la rareté.
			local socle = Instance.new("Part")
			socle.Name = "Socle"
			socle.Shape = Enum.PartType.Cylinder
			socle.Size = Vector3.new(0.6, 4.4, 4.4)
			socle.Anchored = true
			socle.CanCollide = false
			socle.CastShadow = false
			socle.Color = rarity.color
			socle.Material = Enum.Material.Neon
			socle.CFrame = CFrame.new(slot.position - Vector3.new(0, 3.1, 0))
				* CFrame.Angles(0, 0, math.rad(90))
			socle.Parent = fig

			local head = Instance.new("Part")
			head.Name = "Tete"
			head.Shape = Enum.PartType.Ball
			head.Size = Vector3.new(2.4, 2.4, 2.4)
			head.Anchored = true
			head.CanCollide = false
			head.CastShadow = false
			head.Color = J.head
			head.CFrame = fig.CFrame + Vector3.new(0, 3.8, 0)
			head.Parent = fig

			-- Couronne : un disque neon posé à plat au-dessus de la tête. Le
			-- cylindre Roblox a son axe sur X, d'où la rotation de 90°. Disque
			-- plein et non anneau : à distance de tir, seule la lueur se lit, et
			-- un vrai anneau demanderait un mesh.
			if J.halo then
				local halo = Instance.new("Part")
				halo.Name = "Couronne"
				halo.Shape = Enum.PartType.Cylinder
				halo.Size = Vector3.new(0.28, 3.2, 3.2)
				halo.Anchored = true
				halo.CanCollide = false
				halo.CastShadow = false
				halo.Color = J.halo
				halo.Material = Enum.Material.Neon
				halo.CFrame = (fig.CFrame + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
				halo.Parent = fig
			end

			-- BRAS + MAINS, sur TOUTES les figurines (elles ont enfin des membres).
			-- Le bras prend la couleur de peau déclarée (J.arms) ou, à défaut, celle
			-- de la tête ; la main est une petite boule couleur peau au bout du bras.
			local skin = J.arms or J.head
			for _, side in { -1, 1 } do
				local arm = Instance.new("Part")
				arm.Name = "Bras"
				arm.Size = Vector3.new(1.1, 3.2, 1.5)
				arm.Anchored = true
				arm.CanCollide = false
				arm.CastShadow = false
				arm.Color = J.body   -- manche du maillot
				arm.Material = if J.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
				arm.CFrame = fig.CFrame + Vector3.new(side * 2.05, 0.9, 0)
				arm.Parent = fig

				local hand = Instance.new("Part")
				hand.Name = "Main"
				hand.Shape = Enum.PartType.Ball
				hand.Size = Vector3.new(1.25, 1.25, 1.25)
				hand.Anchored = true
				hand.CanCollide = false
				hand.CastShadow = false
				hand.Color = skin
				hand.Material = Enum.Material.SmoothPlastic
				hand.CFrame = fig.CFrame + Vector3.new(side * 2.05, -1.0, 0)
				hand.Parent = fig
			end

			-- Chaussettes et chaussures : des bandeaux autour du bas du corps, pas
			-- des jambes séparées. La figurine est un bloc plein de 6 studs posé
			-- sur un socle à -3.1 ; des pieds modélisés à part traverseraient ce
			-- socle par le dessous.
			if J.socks then
				local sock = Instance.new("Part")
				sock.Name = "Chaussettes"
				sock.Size = Vector3.new(3.07, 0.84, 3.07)
				sock.Anchored = true
				sock.CanCollide = false
				sock.CastShadow = false
				sock.Color = J.socks
				sock.Material = Enum.Material.SmoothPlastic
				sock.CFrame = fig.CFrame - Vector3.new(0, 2.32, 0)
				sock.Parent = fig
			end

			-- PIEDS, sur TOUTES les figurines : deux petites chaussures qui dépassent
			-- vers l'avant. Couleur de la tenue (J.shoes) ou noir mat par défaut.
			local shoeColor = J.shoes or Color3.fromRGB(28, 28, 32)
			for _, side in { -1, 1 } do
				local foot = Instance.new("Part")
				foot.Name = "Pied"
				foot.Size = Vector3.new(1.2, 0.7, 2.3)
				foot.Anchored = true
				foot.CanCollide = false
				foot.CastShadow = false
				foot.Color = shoeColor
				foot.Material = Enum.Material.SmoothPlastic
				foot.CFrame = fig.CFrame + Vector3.new(side * 0.72, -2.9, 0.8)
				foot.Parent = fig
			end

			-- Étiquette discrète : taille fixe (pas de TextScaled, qui gonflait le
			-- texte à la hauteur du cadre) et masquée au-delà de 120 studs.
			local tag = Instance.new("BillboardGui")
			tag.Name = "Nom"
			tag.Size = UDim2.fromOffset(110, 26)
			tag.StudsOffset = Vector3.new(0, 4.2, 0)
			tag.MaxDistance = 120
			tag.Parent = fig
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Text = string.format("%s\n%s ×%s", card.name, rarity.name, Config.abbreviate(rarity.mult))
			lbl.Font = Enum.Font.GothamBold
			lbl.TextSize = 11
			lbl.TextColor3 = rarity.color
			lbl.TextStrokeTransparency = 0.3
			lbl.Parent = tag
		end
	end
end

-- Une figurine touchée est MASQUÉE, pas détruite. Avant, chaque tir détruisait
-- les figurines touchées puis placeSquad reconstruisait toute l'équipe : à 41
-- emplacements et 8 instances par figurine, ça faisait ~330 instances créées et
-- détruites toutes les 2,2 s et par joueur, chacune répliquée à tous les
-- clients (étiquette comprise). Masquer/réafficher ne touche que 7 propriétés
-- d'un arbre déjà en place.
local function setVisible(fig: BasePart, visible: boolean)
	fig.Transparency = if visible then 0 else 1
	for _, d in fig:GetChildren() do
		if d:IsA("BasePart") then
			d.Transparency = if visible then 0 else 1
		elseif d:IsA("BillboardGui") then
			d.Enabled = visible
		end
	end
end

function FieldBuilder.knockDown(fig: BasePart)
	fig:SetAttribute("Down", true)
	setVisible(fig, false)
end

-- DÉFI DU LOIN : le terrain se vide. On masque les figurines, les socles et le
-- fond du but — c'est le « baby-foot infini » annoncé, et surtout il ne doit
-- rien rester à toucher pendant un tir de défi.
--
-- On ne DÉTRUIT rien : la composition de l'équipe est intacte, elle est
-- simplement invisible le temps du défi, et un simple placeSquad la remet en
-- place à la fin (c'est ce que fait le serveur).
function FieldBuilder.setChallengeMode(field, on: boolean)
	if not field or not field.figuresFolder then return end
	for _, inst in field.figuresFolder:GetChildren() do
		if inst:IsA("BasePart") and inst.Name == "Figure" then
			setVisible(inst, not on)
		elseif inst:IsA("BasePart") and inst.Name == "Emplacement" then
			inst.Transparency = if on then 1 else 0.2
		end
	end
	if field.goalPart then
		field.goalPart.Transparency = if on then 0.95 else 0.35
	end
end

-- Relève les figurines couchées. Ne recrée rien : à utiliser après un tir, quand
-- la composition de l'équipe n'a pas bougé (sinon, placeSquad).
function FieldBuilder.standUp(field)
	for _, fig in field.figuresFolder:GetChildren() do
		if fig:IsA("BasePart") and fig.Name == "Figure" and fig:GetAttribute("Down") then
			fig:SetAttribute("Down", nil)
			setVisible(fig, true)
		end
	end
end

-- PARVIS + ALLÉE + PORTIQUE : ce qu'on traverse en arrivant dans le jeu.
-- Retourne la position d'apparition (le joueur y est téléporté à chaque spawn :
-- avec un plot par joueur, on ne peut pas laisser Roblox choisir un
-- SpawnLocation au hasard entre les plots).
function FieldBuilder.buildEntrance(originOverride: Vector3?)
	local o = originOverride or Config.Field.origin
	local E = Config.Entrance
	local F = Config.Field
	local model = Instance.new("Model")
	model.Name = "Entree"
	model.Parent = workspace

	local shootZ = o.Z + F.shootLine
	local plazaZ = shootZ - E.plazaOffset
	local gateZ = shootZ - E.gateOffset

	-- Parvis d'apparition.
	part("Parvis", Vector3.new(E.plazaSize, 1, E.plazaSize),
		CFrame.new(o.X, o.Y, plazaZ), Color3.fromRGB(105, 108, 120), model, Enum.Material.Slate)

	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Anchored = true
	spawnPad.Size = Vector3.new(14, 1, 14)
	spawnPad.CFrame = CFrame.new(o.X, o.Y + 1, plazaZ)
	spawnPad.Color = Color3.fromRGB(255, 210, 60)
	spawnPad.Material = Enum.Material.Neon
	-- Marqueur visuel seulement : tous les SpawnLocation de plot sont désactivés
	-- (Roblox en choisirait un au hasard et on arriverait chez le voisin). Le
	-- point d'apparition par défaut est créé une fois pour toutes par le serveur,
	-- hors plot — un plot est détruit quand son joueur part.
	spawnPad.Enabled = false
	spawnPad.Neutral = true
	spawnPad.Parent = model

	-- Allée du parvis jusqu'au stade.
	local pathLen = E.plazaOffset - 6
	part("Allee", Vector3.new(E.pathWidth, 1, pathLen),
		CFrame.new(o.X, o.Y + 0.05, plazaZ + pathLen / 2), Color3.fromRGB(150, 140, 120),
		model, Enum.Material.Cobblestone)

	-- Portique d'entrée, à mi-chemin : deux piliers et un fronton.
	for _, side in { -1, 1 } do
		part("Pilier", Vector3.new(5, 26, 5),
			CFrame.new(o.X + side * (E.pathWidth / 2 + 4), o.Y + 13, gateZ),
			Color3.fromRGB(60, 64, 80), model, Enum.Material.Concrete)
	end
	local fronton = part("Fronton", Vector3.new(E.pathWidth + 18, 7, 3),
		CFrame.new(o.X, o.Y + 29, gateZ), Color3.fromRGB(30, 33, 44), model, Enum.Material.Metal)

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sign = Instance.new("SurfaceGui")
		sign.Face = face
		sign.CanvasSize = Vector2.new(900, 220)
		sign.Parent = fronton
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Text = "⚽ BABY-FOOT POWER"
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextScaled = true
		lbl.TextColor3 = Color3.fromRGB(255, 210, 60)
		lbl.Parent = sign
	end

	-- Paysage : arbres le long de l'allée, pelouse autour du parvis.
	part("Pelouse", Vector3.new(E.plazaSize + 90, 0.6, E.plazaOffset + 40),
		CFrame.new(o.X, o.Y - 0.3, plazaZ + E.plazaOffset / 2 - 10),
		Color3.fromRGB(60, 130, 60), model, Enum.Material.Grass)

	-- ARBRES. Le feuillage n'est plus une pile de trois boules centrées (qui
	-- donnait un sapin de dessin animé) : quatre boules décalées et de tailles
	-- différentes, plus une ombre portée au sol. À distance, c'est la silhouette
	-- irrégulière qui fait « arbre ».
	local function tree(x: number, z: number, scale: number, seed: number)
		local rng = Random.new(seed)
		local trunk = part("Tronc", Vector3.new(2.2 * scale, 13 * scale, 2.2 * scale),
			CFrame.new(x, o.Y + 6.5 * scale, z) * CFrame.Angles(math.rad(rng:NextNumber(-3, 3)), 0, math.rad(rng:NextNumber(-3, 3))),
			Color3.fromRGB(86, 58, 34), model, Enum.Material.Wood)
		trunk.CanCollide = false

		local clumps = {
			{ dx = 0,    dy = 12.5, dz = 0,    r = 11.5 },
			{ dx = -3.4, dy = 10.5, dz = 1.8,  r = 8.5 },
			{ dx = 3.2,  dy = 11.2, dz = -1.6, r = 8.0 },
			{ dx = 0.4,  dy = 15.4, dz = 0.6,  r = 7.4 },
		}
		for i, c in clumps do
			local tint = rng:NextNumber(-12, 12)
			local foliage = part("Feuillage",
				Vector3.new(c.r * scale, c.r * 0.86 * scale, c.r * scale),
				CFrame.new(x + c.dx * scale, o.Y + c.dy * scale, z + c.dz * scale),
				Color3.fromRGB(math.clamp(46 + tint, 20, 90), math.clamp(112 + i * 9 + tint, 60, 190), math.clamp(48 + tint, 20, 90)),
				model, Enum.Material.Grass)
			foliage.Shape = Enum.PartType.Ball
			foliage.CanCollide = false
		end

		-- Ombre peinte : le CastShadow est coupé partout (coûteux au téléphone),
		-- un disque sombre au sol suffit à ancrer l'arbre dans le décor.
		local shade = part("Ombre", Vector3.new(0.15, 12 * scale, 12 * scale),
			CFrame.new(x, o.Y + 0.36, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(38, 78, 40), model, Enum.Material.SmoothPlastic)
		shade.Shape = Enum.PartType.Cylinder
		shade.CanCollide = false
		shade.Transparency = 0.55
	end

	-- Buissons et cailloux : de quoi casser la pelouse plate autour du parvis.
	local function bush(x: number, z: number, scale: number)
		for i = 0, 2 do
			local b = part("Buisson", Vector3.new(4.2 * scale - i, 3 * scale - i * 0.6, 4.2 * scale - i),
				CFrame.new(x + (i - 1) * 1.8 * scale, o.Y + 1.2 * scale, z + (i % 2) * 1.2 * scale),
				Color3.fromRGB(52, 104 + i * 10, 54), model, Enum.Material.Grass)
			b.Shape = Enum.PartType.Ball
			b.CanCollide = false
		end
	end

	-- Lampadaires le long de l'allée : ils donnent l'échelle et éclairent le
	-- chemin le soir (ClockTime 20 côté projet).
	local function lamp(x: number, z: number)
		local pole = part("Lampadaire", Vector3.new(0.8, 16, 0.8),
			CFrame.new(x, o.Y + 8, z), Color3.fromRGB(38, 40, 52), model, Enum.Material.Metal)
		pole.CanCollide = false
		local bulb = part("Ampoule", Vector3.new(2.2, 2.2, 2.2),
			CFrame.new(x, o.Y + 16.4, z), Color3.fromRGB(255, 236, 190), model, Enum.Material.Neon)
		bulb.Shape = Enum.PartType.Ball
		bulb.CanCollide = false
		local light = Instance.new("PointLight")
		light.Brightness = 1.6
		light.Range = 26
		light.Color = Color3.fromRGB(255, 226, 170)
		light.Shadows = false
		light.Parent = bulb
	end

	for i = 0, E.trees - 1 do
		local z = plazaZ + 14 + i * (pathLen - 10) / math.max(1, E.trees - 1)
		local scale = 0.85 + ((i % 3) * 0.15)
		tree(o.X - E.pathWidth / 2 - 10, z, scale, i * 7 + 1)
		tree(o.X + E.pathWidth / 2 + 12, z, scale, i * 7 + 2)
		-- Un lampadaire une fois sur deux, en bord d'allée.
		if i % 2 == 0 then
			lamp(o.X - E.pathWidth / 2 - 2.5, z)
			lamp(o.X + E.pathWidth / 2 + 2.5, z)
		else
			bush(o.X - E.pathWidth / 2 - 5, z + 4, 1)
			bush(o.X + E.pathWidth / 2 + 5, z - 4, 1.1)
		end
	end

	-- Quelques arbres dispersés derrière le parvis, pour fermer le décor.
	for i = 0, 5 do
		local side = if i % 2 == 0 then -1 else 1
		tree(o.X + side * (18 + (i % 3) * 13), plazaZ - 16 - (i % 3) * 12, 1 + (i % 2) * 0.2, 100 + i)
	end
	for i = 0, 3 do
		local side = if i % 2 == 0 then -1 else 1
		bush(o.X + side * (E.plazaSize / 2 + 6), plazaZ - 10 + i * 9, 1 + (i % 2) * 0.3)
	end

	-- Classement mondial visible dès l'arrivée, à côté du parvis : le panneau du
	-- stade est derrière le but, donc invisible tant qu'on n'a pas traversé.
	local boardStand = Instance.new("Model")
	boardStand.Name = "PanneauClassementEntree"
	boardStand.Parent = model
	local boardZ = plazaZ + 6
	local boardX = o.X - E.plazaSize / 2 - 16
	part("Pied", Vector3.new(3, 20, 3),
		CFrame.new(boardX, o.Y + 10, boardZ), Color3.fromRGB(30, 30, 40), boardStand, Enum.Material.Metal)
	local panel = part("Ecran", Vector3.new(2, 24, 40),
		CFrame.new(boardX, o.Y + 28, boardZ), Color3.fromRGB(12, 14, 20), boardStand)
	local entranceGui = FieldBuilder.boardGui(panel, Enum.NormalId.Right)

	return {
		model = model,
		-- On apparaît au DÉBUT DE L'ALLÉE, face au stade : le centre du parvis
		-- laissait le joueur dos au portique, sans savoir où aller.
		spawnPos = Vector3.new(o.X, o.Y + 4, plazaZ + E.plazaSize / 2 - 6),
		board = entranceGui,
	}
end

-- Le public saute et crie : appelé quand le joueur marque.
function FieldBuilder.cheer(field)
	if not field.crowd then return end
	local E = Config.Crowd

	if E.soundId ~= "" then
		local snd = Instance.new("Sound")
		snd.SoundId = E.soundId
		snd.Volume = E.volume
		snd.RollOffMaxDistance = 300
		snd.Parent = field.goalPart
		snd:Play()
		snd.Ended:Connect(function() snd:Destroy() end)
		task.delay(8, function() if snd.Parent then snd:Destroy() end end)
	end

	-- Une seule boucle anime toute la tribune : un TweenService par supporter (ou
	-- une coroutine chacun) coûterait beaucoup pour un bond d'une demi-seconde.
	if field.cheering then return end
	field.cheering = true

	local bases = {}
	for i, fan in field.crowd do
		if fan.PrimaryPart then
			bases[i] = fan:GetPivot()
		end
	end

	local WAVE = E.waveOffset  -- décalage par supporter : ça fait une ola, pas un bloc
	local step = 1 / E.waveFps
	task.spawn(function()
		local start = os.clock()
		local duration = E.jumpTime * 2 + WAVE * #field.crowd
		-- Un supporter déjà reposé n'a pas besoin qu'on lui réécrive sa position :
		-- à un instant donné, seule une fraction de la tribune est en l'air, et
		-- chaque PivotTo inutile est un CFrame répliqué à tous les clients.
		local atRest = {}
		while os.clock() - start < duration do
			local t = os.clock() - start
			for i, fan in field.crowd do
				local base = bases[i]
				if base then
					local phase = (t - i * WAVE) / E.jumpTime
					local h = if phase <= 0 or phase >= 2 then 0
						elseif phase <= 1 then phase
						else 2 - phase
					if h ~= 0 or not atRest[i] then
						fan:PivotTo(base + Vector3.new(0, E.jumpHeight * h, 0))
						atRest[i] = h == 0
					end
				end
			end
			task.wait(step)
		end
		for i, fan in field.crowd do
			if bases[i] then fan:PivotTo(bases[i]) end
		end
		field.cheering = false
	end)
end

-- Zone d'entraînement (haltères) + spawn, à côté du terrain.
function FieldBuilder.buildTrainingArea(originOverride: Vector3?)
	local o = originOverride or Config.Field.origin
	local model = Instance.new("Model")
	model.Name = "ZoneEntrainement"
	model.Parent = workspace

	-- Même distance que la plateforme des œufs, de l'autre côté : sous l'ancien
	-- écart (une seule largeur), un terrain agrandi par les renaissances passait
	-- par-dessus le gym.
	local base = Vector3.new(o.X - Config.Field.width * 1.6, 1, o.Z + Config.Field.shootLine)
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

	-- Marqueur de la zone d'entraînement. Ce n'est plus un point d'apparition :
	-- on arrive sur le parvis (voir buildEntrance), pas au milieu des haltères.
	local pad = part("PlateformeGym", Vector3.new(10, 1, 10),
		CFrame.new(base.X, base.Y + 1, base.Z + 14),
		Color3.fromRGB(255, 210, 60), model, Enum.Material.Neon)
	pad.CanCollide = false

	return { model = model, trainPos = base }
end

-- PLATEFORME DES ŒUFS : trois socles côte à côte, à droite du point de tir,
-- face au joueur qui arrive de l'allée. On clique l'œuf pour l'ouvrir (le prix
-- est écrit dessus) — le serveur revérifie tout, le clic n'est qu'une intention.
--
-- Elle est RECONSTRUITE à chaque changement de monde : les trois œufs affichés
-- sont ceux du monde où l'on se trouve, jamais un mélange.
--
-- Retourne le modèle et la liste { key, clickDetector } à brancher côté serveur.
function FieldBuilder.buildEggPlatform(originOverride: Vector3?, worldIndex: number?)
	local o = originOverride or Config.Field.origin
	local F = Config.Field
	local world = Config.world(worldIndex)
	local eggs = Config.eggsFor(worldIndex)

	local model = Instance.new("Model")
	model.Name = "PlateformeOeufs"
	model.Parent = workspace

	-- AU PARVIS, à droite du point d'apparition : c'est la première chose qu'on
	-- voit en arrivant, et on n'a plus à traverser tout le stade pour ouvrir un
	-- œuf. Le panneau de classement occupe le côté gauche du parvis, d'où le
	-- côté droit ici.
	local E = Config.Entrance
	local plazaZ = o.Z + F.shootLine - E.plazaOffset
	local base = Vector3.new(o.X + E.plazaSize / 2 + 34, o.Y, plazaZ + 4)

	local floor = part("SolOeufs", Vector3.new(46, 1.4, 34),
		CFrame.new(base.X, base.Y + 0.7, base.Z), Color3.fromRGB(58, 62, 78), model, Enum.Material.Slate)
	floor.CanCollide = true

	local trim = part("BordOeufs", Vector3.new(48, 0.6, 36),
		CFrame.new(base.X, base.Y + 0.2, base.Z), world.accent, model, Enum.Material.Neon)
	trim.CanCollide = false

	-- Enseigne de la plateforme.
	local signPost = part("MatEnseigne", Vector3.new(1.2, 14, 1.2),
		CFrame.new(base.X, base.Y + 7, base.Z - 15), Color3.fromRGB(40, 44, 58), model, Enum.Material.Metal)
	signPost.CanCollide = false
	local signTitle = Instance.new("BillboardGui")
	signTitle.Name = "Enseigne"
	signTitle.Size = UDim2.fromOffset(260, 60)
	signTitle.StudsOffset = Vector3.new(0, 8, 0)
	signTitle.AlwaysOnTop = false
	signTitle.MaxDistance = 260
	signTitle.Parent = signPost
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.fromScale(1, 1)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🥚 ŒUFS — " .. string.upper(world.name)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = world.accent
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = signTitle

	local spots = {}
	for i, egg in eggs do
		local x = base.X + (i - 2) * 14
		local z = base.Z

		local pedestal = part("SocleOeuf", Vector3.new(8, 3, 8),
			CFrame.new(x, base.Y + 2.9, z), Color3.fromRGB(44, 48, 62), model, Enum.Material.Concrete)
		local glow = part("HaloSocle", Vector3.new(9, 0.4, 9),
			CFrame.new(x, base.Y + 4.5, z), egg.color, model, Enum.Material.Neon)
		glow.CanCollide = false

		-- L'œuf : une sphère un peu étirée, posée sur le socle.
		local shell = part("Oeuf", Vector3.new(6, 7.6, 6),
			CFrame.new(x, base.Y + 8.4, z), egg.color, model, Enum.Material.SmoothPlastic)
		shell.Shape = Enum.PartType.Ball
		shell.CanCollide = false
		local speck = part("TacheOeuf", Vector3.new(6.1, 2.2, 6.1),
			CFrame.new(x, base.Y + 9.6, z), Color3.fromRGB(250, 250, 255), model, Enum.Material.SmoothPlastic)
		speck.Shape = Enum.PartType.Ball
		speck.CanCollide = false
		speck.Transparency = 0.35

		-- Étiquette : nom + prix. Elle est réécrite par le serveur quand le prix
		-- change (renaissance), d'où le nom d'instance stable.
		local tag = Instance.new("BillboardGui")
		tag.Name = "Etiquette"
		tag.Size = UDim2.fromOffset(190, 62)
		tag.StudsOffset = Vector3.new(0, 6.5, 0)
		tag.MaxDistance = 200
		tag.Parent = shell
		local label = Instance.new("TextLabel")
		label.Name = "Texte"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = egg.name .. "\n" .. Config.abbreviate(egg.cost) .. " $"
		label.Font = Enum.Font.GothamBold
		label.TextSize = 15
		label.TextColor3 = egg.color
		label.TextStrokeTransparency = 0.25
		label.Parent = tag

		-- Chances des pets : n'apparaît qu'à l'APPROCHE (MaxDistance court), pour
		-- ne pas encombrer la vue de loin. Liste chaque pet, son % et son bonus.
		local chances = Instance.new("BillboardGui")
		chances.Name = "Chances"
		chances.Size = UDim2.fromOffset(240, 128)
		chances.StudsOffset = Vector3.new(0, -2, 0)
		chances.MaxDistance = 44
		chances.Parent = shell
		local chFrame = Instance.new("Frame")
		chFrame.Size = UDim2.fromScale(1, 1)
		chFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
		chFrame.BackgroundTransparency = 0.25
		chFrame.BorderSizePixel = 0
		chFrame.Parent = chances
		local chCorner = Instance.new("UICorner")
		chCorner.CornerRadius = UDim.new(0, 8)
		chCorner.Parent = chFrame
		local chLines = { "🎲 CHANCES" }
		for _, c in Config.eggChances(egg) do
			table.insert(chLines, string.format("%s  %.1f%%  ×%s", c.name, c.pct, Config.abbreviate(c.mult)))
		end
		local chText = Instance.new("TextLabel")
		chText.Size = UDim2.new(1, -12, 1, -10)
		chText.Position = UDim2.fromOffset(6, 5)
		chText.BackgroundTransparency = 1
		chText.Text = table.concat(chLines, "\n")
		chText.Font = Enum.Font.GothamBold
		chText.TextSize = 15
		chText.TextColor3 = Color3.fromRGB(240, 240, 250)
		chText.TextStrokeTransparency = 0.4
		chText.TextXAlignment = Enum.TextXAlignment.Left
		chText.TextYAlignment = Enum.TextYAlignment.Top
		chText.Parent = chFrame

		-- Le clic marche à la souris comme au doigt. MaxActivationDistance borné :
		-- on ouvre l'œuf devant lequel on se trouve, pas celui d'en face.
		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 26
		click.Parent = shell

		table.insert(spots, { key = egg.key, egg = egg, click = click, label = label, shell = shell })
	end

	return { model = model, spots = spots, base = base }
end

-- ÉCLOSION : l'œuf tremble, éclate en éclats de sa couleur, et le pet obtenu
-- s'élève au-dessus du socle avant de disparaître.
--
-- Jouée CÔTÉ SERVEUR : elle se voit donc aussi des autres joueurs qui passent
-- (c'est ce qui donne envie d'aller ouvrir un œuf). Les éclats sont des parts
-- jetables, détruites au bout d'une seconde — pas de ParticleEmitter, qui
-- demanderait une texture uploadée.
--
-- `spot` vient de FieldBuilder.buildEggPlatform. Une éclosion déjà en cours sur
-- le même œuf est ignorée : sans ça, un joueur qui enchaîne les achats
-- superposerait dix animations sur la même coquille.
function FieldBuilder.hatchAnimation(spot, pet)
	if not spot or not spot.shell or not spot.shell.Parent then return end
	if spot.busy then return end
	spot.busy = true

	local TweenService = game:GetService("TweenService")
	local shell = spot.shell :: BasePart
	local home = shell.CFrame
	local color = (pet and pet.color) or shell.Color

	task.spawn(function()
		-- 1. Tremblement : de plus en plus vite, comme un œuf qui va craquer.
		for i = 1, 8 do
			local a = math.rad(9 + i * 1.5)
			shell.CFrame = home * CFrame.Angles(0, 0, if i % 2 == 0 then a else -a)
			task.wait(0.10 - i * 0.008)
		end
		shell.CFrame = home

		-- 2. La coquille s'efface un instant : c'est le moment de l'éclosion.
		shell.Transparency = 1
		local shellTag = shell:FindFirstChild("Etiquette")
		if shellTag and shellTag:IsA("BillboardGui") then shellTag.Enabled = false end

		-- 3. Éclats projetés.
		for i = 1, 12 do
			local shard = Instance.new("Part")
			shard.Name = "Eclat"
			shard.Size = Vector3.new(0.8, 0.8, 0.8)
			shard.Color = color
			shard.Material = Enum.Material.Neon
			shard.Anchored = true
			shard.CanCollide = false
			shard.CastShadow = false
			shard.CFrame = home
			shard.Parent = shell.Parent
			local a = (i / 12) * math.pi * 2
			local away = home * CFrame.new(math.cos(a) * 7, math.random(2, 6), math.sin(a) * 7)
			TweenService:Create(shard, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CFrame = away, Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) }):Play()
			game:GetService("Debris"):AddItem(shard, 1)
		end

		-- 4. Le pet apparaît et monte.
		if pet then
			local orb = Instance.new("Part")
			orb.Name = "PetRevele"
			orb.Shape = Enum.PartType.Ball
			orb.Size = Vector3.new(1, 1, 1)
			orb.Color = pet.color
			orb.Material = Enum.Material.Neon
			orb.Anchored = true
			orb.CanCollide = false
			orb.CastShadow = false
			orb.CFrame = home
			orb.Parent = shell.Parent

			local tag = Instance.new("BillboardGui")
			tag.Size = UDim2.fromOffset(210, 44)
			tag.StudsOffset = Vector3.new(0, 3, 0)
			tag.AlwaysOnTop = true
			tag.MaxDistance = 220
			tag.Parent = orb
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = string.format("%s\nargent x%s", pet.name, Config.abbreviate(pet.mult))
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = true
			label.TextColor3 = pet.color
			label.TextStrokeTransparency = 0.2
			label.Parent = tag

			TweenService:Create(orb, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size = Vector3.new(3.4, 3.4, 3.4) }):Play()
			task.wait(0.5)
			TweenService:Create(orb, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CFrame = home * CFrame.new(0, 9, 0), Transparency = 1 }):Play()
			game:GetService("Debris"):AddItem(orb, 1.6)
			task.wait(1.1)
		else
			task.wait(0.5)
		end

		-- 5. Un nouvel œuf a repoussé sur le socle.
		if shell.Parent then
			shell.Transparency = 0
			shell.CFrame = home
			if shellTag and shellTag:IsA("BillboardGui") then shellTag.Enabled = true end
		end
		spot.busy = false
	end)
end

-- Grand panneau de classement mondial, placé au fond derrière le but.
-- TROIS classements côte à côte, un par métrique, chacun sur son propre écran
-- (plus « un seul panneau qui tourne »). Renvoie la liste { {gui, metric}, … }
-- pour que le serveur attache chaque écran à SA métrique (cf. Leaderboard.attach).
function FieldBuilder.buildLeaderboardBoard(field)
	local stand = Instance.new("Model")
	stand.Name = "PanneauClassement"
	stand.Parent = workspace

	local z = field.goalZ + 24
	-- Trois écrans compacts (28 de large) espacés, plutôt qu'un pavé de 60. Chaque
	-- écran a sa couleur de titre pour qu'on distingue les classements d'un regard.
	local screens = {
		{ metric = "earned", title = "Argent total", accent = Color3.fromRGB(255, 200, 60) },
		{ metric = "power",  title = "Puissance",    accent = Color3.fromRGB(90, 200, 255) },
		{ metric = "gems",   title = "Gemmes",       accent = Color3.fromRGB(180, 130, 255) },
	}
	local screenW, gapW = 28, 6
	local pitch = screenW + gapW
	local baseX = field.origin.X - pitch    -- centre les trois autour de l'axe

	local out = {}
	for i, s in screens do
		local x = baseX + (i - 1) * pitch
		part("Pied", Vector3.new(3, 30, 3),
			CFrame.new(x, field.origin.Y + 15, z), Color3.fromRGB(30, 30, 40), stand, Enum.Material.Metal)
		local board = part("Ecran", Vector3.new(screenW, 34, 2),
			CFrame.new(x, field.origin.Y + 40, z),
			Color3.fromRGB(12, 14, 20), stand, Enum.Material.SmoothPlastic)
		board.Orientation = Vector3.new(0, 180, 0)
		-- Seul le premier écran porte le compte à rebours du coup de sifflet.
		local gui = FieldBuilder.boardGui(board, Enum.NormalId.Front, s.accent, i == 1)
		table.insert(out, { gui = gui, metric = s.metric })
	end
	return out
end

return FieldBuilder
