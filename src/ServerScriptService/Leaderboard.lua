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

function Leaderboard.submit(userId: number, totalEarned: number)
	if not ordered then return end
	pcall(function()
		ordered:SetAsync("u_" .. userId, math.floor(totalEarned))
	end)
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
