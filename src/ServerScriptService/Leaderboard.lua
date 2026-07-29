--!strict
-- Classement mondial via OrderedDataStore, rafraîchit le panneau in-game.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Leaderboard = {}

local ordered: OrderedDataStore? = nil
if game.PlaceId ~= 0 then  -- place non publié => OrderedDataStore inaccessible
	pcall(function()
		-- Cle v2 : la v1 stockait la valeur brute ecretee a 2^53, elle contient
		-- donc des scores faux et non comparables entre eux. On repart propre.
		ordered = DataStoreService:GetOrderedDataStore(Config.SaveKey .. "_top_v2")
	end)
end

-- Plusieurs panneaux peuvent afficher le classement (stade + parvis d'entrée) :
-- ils sont tous alimentés par le même appel à refresh(), et une seule requête
-- OrderedDataStore les sert tous.
local guis: { SurfaceGui } = {}

function Leaderboard.attach(surfaceGui: SurfaceGui)
	table.insert(guis, surfaceGui)
end

-- À appeler quand le panneau disparaît (départ d'un joueur) : sinon la liste
-- grossit indéfiniment avec des panneaux détruits.
function Leaderboard.detach(surfaceGui: SurfaceGui)
	for i, g in guis do
		if g == surfaceGui then
			table.remove(guis, i)
			return
		end
	end
end

-- Roblox limite les ecritures OrderedDataStore par cle (~1 / 6 s) : un tir toutes
-- les 0,3 s par joueur saturait la file et faisait echouer les ecritures en
-- silence (elles sont sous pcall). On n'ecrit donc qu'une fois par minute et par
-- joueur, plus une ecriture forcee au depart.
local SUBMIT_INTERVAL = 60
local lastSubmitAt: { [number]: number } = {}
local lastSubmitVal: { [number]: number } = {}

-- SCORE STOCKE EN ECHELLE LOG.
--
-- Un OrderedDataStore ne prend que des entiers, et un double perd la precision
-- entiere au-dela de 2^53 (~9 Qa). Or les gains du jeu sont multiplicatifs et
-- depassent 1e36 apres quelques renaissances : ecreter a 2^53 (ce que faisait
-- la version precedente) affichait un montant faux ET donnait la MEME valeur a
-- tous les joueurs au-dessus du plafond, rendant leur classement arbitraire.
--
-- On stocke donc log10(1 + total) * 1e6. Le log est strictement croissant, donc
-- l'ORDRE est exactement preserve ; et 6 decimales d'exposant laissent ~6
-- chiffres significatifs a la relecture, largement assez pour un affichage.
-- Un total de 1e300 ne pese que 3e8, tres loin de la limite.
local LOG_SCALE = 1e6
local MAX_SCORE = 4e8   -- log10 = 400, hors d'atteinte

local function encodeScore(total: number): number
	if total <= 0 then return 0 end
	return math.clamp(math.floor(math.log(1 + total, 10) * LOG_SCALE), 0, MAX_SCORE)
end

local function decodeScore(value: number): number
	if value <= 0 then return 0 end
	return 10 ^ (value / LOG_SCALE) - 1
end

-- Joueurs effacés à leur demande : plus aucune soumission jusqu'à la fin de leur
-- session, sinon l'écriture forcée du départ les remettrait au classement.
local erased: { [number]: boolean } = {}

function Leaderboard.submit(userId: number, totalEarned: number, force: boolean?)
	if not ordered then return end
	if erased[userId] then return end
	if totalEarned ~= totalEarned then return end  -- NaN

	local value = encodeScore(totalEarned)
	if lastSubmitVal[userId] == value then return end

	local now = os.clock()
	if not force and (now - (lastSubmitAt[userId] or -math.huge)) < SUBMIT_INTERVAL then
		return
	end
	lastSubmitAt[userId] = now

	local ok = pcall(function()
		ordered:SetAsync("u_" .. userId, value)
	end)
	if ok then
		lastSubmitVal[userId] = value
	end
end

-- Droit à l'oubli : retire le joueur du classement mondial.
function Leaderboard.erase(userId: number): boolean
	erased[userId] = true
	lastSubmitVal[userId] = nil
	if not ordered then return true end
	for attempt = 1, 3 do
		local ok = pcall(function()
			ordered:RemoveAsync("u_" .. userId)
		end)
		if ok then return true end
		task.wait(2 * attempt)
	end
	warn(string.format("[BabyFoot] Retrait du classement pour %d ECHOUE : a rejouer.", userId))
	return false
end

function Leaderboard.forget(userId: number)
	lastSubmitAt[userId] = nil
	lastSubmitVal[userId] = nil
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

local function setAll(text: string)
	for _, g in guis do
		local label = g:FindFirstChild("List") :: TextLabel?
		if label then
			label.Text = text
		end
	end
end

function Leaderboard.refresh()
	if #guis == 0 then return end
	if not ordered then
		setAll("Classement disponible après publication du jeu.")
		return
	end

	local ok, pages = pcall(function()
		return ordered:GetSortedAsync(false, 10)
	end)
	if not ok or not pages then
		setAll("Classement indisponible (API désactivée ?)")
		return
	end

	local rows = {}
	local rank = 1
	for _, entry in pages:GetCurrentPage() do
		-- Parenthèses obligatoires : gsub renvoie la chaîne ET le nombre de
		-- remplacements, et ce second retour partirait en base de tonumber.
		local uid = tonumber(((entry.key :: string):gsub("u_", ""))) or 0
		local medal = rank == 1 and "🥇" or rank == 2 and "🥈" or rank == 3 and "🥉" or (rank .. ".")
		table.insert(rows, string.format("%s  %s  —  %s $",
			medal, nameFor(uid), Config.abbreviate(decodeScore(entry.value))))
		rank += 1
	end
	if #rows == 0 then
		setAll("Sois le premier au classement !")
	else
		setAll(table.concat(rows, "\n"))
	end
end

return Leaderboard
