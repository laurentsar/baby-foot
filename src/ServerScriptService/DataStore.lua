--!strict
-- Sauvegarde/chargement des profils joueur. Tolérant aux erreurs (Studio sans API access).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local DataModule = {}

-- Un place non publié a PlaceId == 0 : dans ce cas le DataStore est inaccessible
-- (et Roblox logge un message même sous pcall). On l'évite proprement.
local store: DataStore? = nil
if game.PlaceId ~= 0 then
	local ok = pcall(function()
		store = DataStoreService:GetDataStore(Config.SaveKey)
	end)
	if not ok then
		warn("[BabyFoot] DataStore indisponible — profils en mémoire uniquement.")
	end
else
	warn("[BabyFoot] Place non publié — sauvegarde désactivée (profils en mémoire).")
end

function DataModule.default()
	return {
		money = 0,
		power = 0,
		dumbbell = 1,   -- index dans Config.Dumbbells
		ball = 1,       -- index dans Config.Balls
		countLevel = 0, -- niveau nombre de figurines
		valueLevel = 0, -- niveau valeur des figurines
		rebirths = 0,
		totalEarned = 0, -- pour le classement mondial
	}
end

function DataModule.load(userId: number)
	local data = DataModule.default()
	if store then
		local success, saved = pcall(function()
			return store:GetAsync("p_" .. userId)
		end)
		if success and type(saved) == "table" then
			for k, v in DataModule.default() do
				if saved[k] ~= nil then
					data[k] = saved[k]
				end
			end
		end
	end
	return data
end

function DataModule.save(userId: number, data)
	if not store then return end
	pcall(function()
		store:SetAsync("p_" .. userId, data)
	end)
end

return DataModule
