--!strict
-- Sauvegarde/chargement des profils joueur. Tolérant aux erreurs (Studio sans API access).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
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

-- Anti « DataStore request was added to queue » : Roblox limite les écritures par
-- clé (~1 toutes les 6 s) et met le surplus en file. On saute donc les sauvegardes
-- trop rapprochées ET celles dont le contenu n'a pas bougé.
local MIN_INTERVAL = 20
local lastSaveAt: { [number]: number } = {}
local lastPayload: { [number]: string } = {}

function DataModule.save(userId: number, data, force: boolean?)
	if not store then return end
	local payload = HttpService:JSONEncode(data)
	if lastPayload[userId] == payload then return end
	local now = os.clock()
	if not force and (now - (lastSaveAt[userId] or -math.huge)) < MIN_INTERVAL then
		return
	end
	lastSaveAt[userId] = now
	local ok = pcall(function()
		store:SetAsync("p_" .. userId, data)
	end)
	if ok then
		lastPayload[userId] = payload
	end
end

function DataModule.forget(userId: number)
	lastSaveAt[userId] = nil
	lastPayload[userId] = nil
end

return DataModule
