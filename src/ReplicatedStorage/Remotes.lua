--!strict
-- Fabrique/attend les RemoteEvents partagés. Le serveur les crée, le client les attend.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENT_NAMES = {
	"Train",        -- client -> serveur : une rep d'entraînement
	"Shoot",        -- client -> serveur : tir (angle, chargePct)
	"BuyUpgrade",   -- client -> serveur : {kind = "dumbbell"|"ball"|"slot"|"value"}
	"Rebirth",      -- client -> serveur : demande de renaissance
	"BuyPass",      -- client -> serveur : ouvre la boutique Robux d'un pass
	"RollDice",     -- client -> serveur : lance les dés pour recruter un joueur
	"StatsUpdate",  -- serveur -> client : table d'état complète
	"ShotResult",   -- serveur -> client : {hits, money, scored, tier}
	"DiceResult",   -- serveur -> client : {card = {name, rarity}, cost}
	"Collection",   -- serveur -> client : {cards, squad, unlockedSlots}
	"Toast",        -- serveur -> client : message d'info
}

local Remotes = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild("Remotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
		for _, name in EVENT_NAMES do
			if not folder:FindFirstChild(name) then
				local ev = Instance.new("RemoteEvent")
				ev.Name = name
				ev.Parent = folder
			end
		end
		return folder
	else
		return ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
end

function Remotes.get(name: string): RemoteEvent
	local folder = getFolder()
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
