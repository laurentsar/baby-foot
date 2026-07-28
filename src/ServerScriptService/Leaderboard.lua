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
		ordered = DataStoreService:GetOrderedDataStore(Config.SaveKey .. "_top")
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

-- Les valeurs OrderedDataStore doivent tenir dans un entier 64 bits signe ; un
-- total astronomique ferait echouer l'ecriture au lieu de classer le joueur.
local MAX_SCORE = 2 ^ 53

-- Joueurs effacés à leur demande : plus aucune soumission jusqu'à la fin de leur
-- session, sinon l'écriture forcée du départ les remettrait au classement.
local erased: { [number]: boolean } = {}

function Leaderboard.submit(userId: number, totalEarned: number, force: boolean?)
	if not ordered then return end
	if erased[userId] then return end
	if totalEarned ~= totalEarned then return end  -- NaN

	local value = math.clamp(math.floor(totalEarned), 0, MAX_SCORE)
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
			medal, nameFor(uid), Config.abbreviate(entry.value)))
		rank += 1
	end
	if #rows == 0 then
		setAll("Sois le premier au classement !")
	else
		setAll(table.concat(rows, "\n"))
	end
end

return Leaderboard
