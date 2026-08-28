--!strict
-- Classements mondiaux via OrderedDataStore, affichés en rotation sur les panneaux.
--
-- Plusieurs classements : Argent total, Puissance, Renaissances. Un seul jeu de
-- panneaux physiques : refresh() fait tourner le classement affiché (titre +
-- liste) à chaque appel (toutes les 30 s). Chaque métrique a son propre
-- OrderedDataStore, donc son propre top 10 mondial.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Leaderboard = {}

-- SCORE STOCKÉ EN ÉCHELLE LOG pour les métriques qui explosent (argent,
-- puissance) : un OrderedDataStore ne prend que des entiers et un double perd la
-- précision au-delà de 2^53. log10(1+v)*1e6 préserve l'ORDRE exactement. Les
-- petites métriques (renaissances) sont stockées brutes.
local LOG_SCALE = 1e6
local MAX_SCORE = 4e8   -- log10 = 400, hors d'atteinte

local function encodeLog(v: number): number
	if v <= 0 then return 0 end
	return math.clamp(math.floor(math.log(1 + v, 10) * LOG_SCALE), 0, MAX_SCORE)
end
local function decodeLog(value: number): number
	if value <= 0 then return 0 end
	return 10 ^ (value / LOG_SCALE) - 1
end

-- Définition des classements. `store` = suffixe de clé OrderedDataStore ; garder
-- `_top_v2` pour l'argent préserve le classement déjà en place.
type Metric = {
	key: string, title: string, store: string, log: boolean, suffix: string,
	handle: OrderedDataStore?,
}
local METRICS: { Metric } = {
	{ key = "earned",   title = "Argent total", store = "_top_v2",     log = true,  suffix = " $" },
	{ key = "power",    title = "Puissance",    store = "_power_v1",   log = true,  suffix = "" },
	{ key = "rebirths", title = "Renaissances", store = "_rebirth_v1", log = false, suffix = "" },
	{ key = "gems",     title = "Gemmes",       store = "_gems_v1",    log = false, suffix = " 💎" },
}

if game.PlaceId ~= 0 then  -- place non publié => OrderedDataStore inaccessible
	for _, m in METRICS do
		pcall(function()
			m.handle = DataStoreService:GetOrderedDataStore(Config.SaveKey .. m.store)
		end)
	end
end

local function encodeFor(m: Metric, v: number): number
	if m.log then return encodeLog(v) end
	return math.clamp(math.floor(v), 0, MAX_SCORE)
end
local function decodeFor(m: Metric, value: number): number
	if m.log then return decodeLog(value) end
	return value
end

-- Deux sortes de panneaux :
--   • FIXES  : chacun montre TOUJOURS la même métrique (les trois écrans côte à
--     côte derrière le terrain — Argent, Puissance, Renaissances). On les attache
--     avec une `metricKey`.
--   • TOURNANTS : un seul écran qui fait défiler les métriques à tour de rôle
--     (le petit panneau du parvis de chaque plot). Attaché sans metricKey.
type Board = { gui: SurfaceGui, metric: string? }
local guis: { Board } = {}

function Leaderboard.attach(surfaceGui: SurfaceGui, metricKey: string?)
	table.insert(guis, { gui = surfaceGui, metric = metricKey })
end

function Leaderboard.detach(surfaceGui: SurfaceGui)
	for i, b in guis do
		if b.gui == surfaceGui then
			table.remove(guis, i)
			return
		end
	end
end

-- Roblox limite les écritures OrderedDataStore par clé (~1 / 6 s). On n'écrit
-- donc qu'une fois par minute et par joueur ET PAR MÉTRIQUE, plus une écriture
-- forcée au départ.
local SUBMIT_INTERVAL = 60
local lastAt: { [string]: { [number]: number } } = {}
local lastVal: { [string]: { [number]: number } } = {}
for _, m in METRICS do
	lastAt[m.key] = {}
	lastVal[m.key] = {}
end

-- Joueurs effacés à leur demande : plus aucune soumission jusqu'à la fin de leur
-- session.
local erased: { [number]: boolean } = {}

-- `stats` = { earned = , power = , rebirths = }. Chaque métrique présente est
-- soumise à son propre classement.
function Leaderboard.submit(userId: number, stats: { [string]: number }, force: boolean?)
	if erased[userId] then return end
	-- Les admins ne figurent JAMAIS au classement mondial : ils s'attribuent
	-- argent/puissance/gemmes pour tester, ce qui fausserait le tableau.
	if Config.isAdmin(userId) then return end
	local now = os.clock()
	for _, m in METRICS do
		local handle = m.handle
		local raw = stats[m.key]
		if handle and raw == raw and raw ~= nil then  -- écarte NaN / manquant
			local value = encodeFor(m, raw)
			if lastVal[m.key][userId] ~= value then
				if force or (now - (lastAt[m.key][userId] or -math.huge)) >= SUBMIT_INTERVAL then
					lastAt[m.key][userId] = now
					local ok = pcall(function()
						(handle :: OrderedDataStore):SetAsync("u_" .. userId, value)
					end)
					if ok then lastVal[m.key][userId] = value end
				end
			end
		end
	end
end

-- Droit à l'oubli : retire le joueur de TOUS les classements.
function Leaderboard.erase(userId: number): boolean
	erased[userId] = true
	local allOk = true
	for _, m in METRICS do
		lastVal[m.key][userId] = nil
		local handle = m.handle
		if handle then
			local done = false
			for attempt = 1, 3 do
				local ok = pcall(function()
					(handle :: OrderedDataStore):RemoveAsync("u_" .. userId)
				end)
				if ok then done = true; break end
				task.wait(2 * attempt)
			end
			if not done then allOk = false end
		end
	end
	if not allOk then
		warn(string.format("[BabyFoot] Retrait des classements pour %d ECHOUE : a rejouer.", userId))
	end
	return allOk
end

-- Retire définitivement les admins de TOUS les classements. À appeler au
-- démarrage : le garde-fou de submit empêche les nouvelles écritures, mais une
-- entrée d'admin déjà présente (avant ce garde-fou) doit être effacée une fois.
function Leaderboard.purgeAdmins()
	for _, uid in Config.Admins do
		for _, m in METRICS do
			local handle = m.handle
			if handle then
				task.spawn(function()
					pcall(function()
						(handle :: OrderedDataStore):RemoveAsync("u_" .. uid)
					end)
				end)
			end
		end
	end
end

function Leaderboard.forget(userId: number)
	for _, m in METRICS do
		lastAt[m.key][userId] = nil
		lastVal[m.key][userId] = nil
	end
	erased[userId] = nil
end

local function nameFor(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then return player.DisplayName end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	return ok and name or ("Joueur " .. userId)
end

local function setGuiChild(gui: SurfaceGui, childName: string, text: string)
	-- Recherche récursive : les labels vivent désormais dans un cadre arrondi
	-- (cf. FieldBuilder.boardGui), plus directement sous la SurfaceGui.
	local label = gui:FindFirstChild(childName, true) :: TextLabel?
	if label then label.Text = text end
end

local function metricByKey(key: string): Metric?
	for _, m in METRICS do
		if m.key == key then return m end
	end
	return nil
end

-- Rend le titre + la liste d'une métrique (une seule lecture OrderedDataStore).
-- Résultat mis en cache le temps d'un refresh : trois écrans qui montrent trois
-- métriques différentes ne font ainsi qu'une lecture chacune, pas trois.
local function renderMetric(metric: Metric): (string, string)
	local title = "🏆 " .. string.upper(metric.title)
	local handle = metric.handle
	if not handle then
		return title, "Classement disponible après publication du jeu."
	end
	local ok, pages = pcall(function()
		return (handle :: OrderedDataStore):GetSortedAsync(false, 10)
	end)
	if not ok or not pages then
		return title, "Classement indisponible (API désactivée ?)"
	end
	local rows = {}
	local rank = 1
	for _, entry in pages:GetCurrentPage() do
		local uid = tonumber(((entry.key :: string):gsub("u_", ""))) or 0
		local medal = rank == 1 and "🥇" or rank == 2 and "🥈" or rank == 3 and "🥉" or (rank .. ".")
		local raw = decodeFor(metric, entry.value)
		local shown = if metric.log then Config.abbreviate(raw) else tostring(math.floor(raw))
		-- Nom tronqué : les panneaux sont étroits, un pseudo long débordait du cadre.
		local name = nameFor(uid)
		if utf8.len(name) and (utf8.len(name) :: number) > 11 then
			name = name:sub(1, (utf8.offset(name, 12) :: number) - 1) .. "…"
		end
		table.insert(rows, string.format("%s %s  %s%s", medal, name, shown, metric.suffix))
		rank += 1
	end
	if #rows == 0 then
		return title, "Sois le premier au classement !"
	end
	return title, table.concat(rows, "\n")
end

-- Métrique tournante des panneaux du parvis : avance d'un cran à chaque refresh.
local metricIndex = 0

function Leaderboard.refresh()
	if #guis == 0 then return end
	metricIndex = metricIndex % #METRICS + 1
	local rotating = METRICS[metricIndex]

	-- Une lecture par métrique et par refresh, réutilisée pour tous les panneaux.
	local cache: { [string]: { title: string, list: string } } = {}
	local function rendered(metric: Metric)
		local c = cache[metric.key]
		if not c then
			local t, l = renderMetric(metric)
			c = { title = t, list = l }
			cache[metric.key] = c
		end
		return c
	end

	for _, board in guis do
		local metric = if board.metric then metricByKey(board.metric) or rotating else rotating
		local c = rendered(metric)
		setGuiChild(board.gui, "Title", c.title)
		setGuiChild(board.gui, "List", c.list)
	end
end

return Leaderboard
