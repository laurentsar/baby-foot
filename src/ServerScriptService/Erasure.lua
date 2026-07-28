--!strict
-- DROIT À L'OUBLI (RGPD / Right to Erasure).
--
-- Deux chemins, parce que les demandes arrivent de deux façons :
--
--  1. Le joueur est en jeu et clique « Supprimer mes données » dans la boutique.
--     Le serveur efface, puis l'éjecte : sa session tourne encore en mémoire et
--     la sauvegarde de sortie recréerait aussitôt ce qu'on vient d'effacer.
--
--  2. Roblox transmet une demande pour un joueur qui ne reviendra pas (Creator
--     Dashboard → e-mail de Right to Erasure). On colle son UserId dans
--     Config.ErasureRequests et le prochain démarrage de serveur s'en charge.
--
-- Ce qui est supprimé, c'est tout ce que le jeu écrit sur un joueur :
--   - le profil       : DataStore   "BabyFootPower_v1"     clé p_<userId>
--   - le classement   : OrderedDataStore "..._top"         clé u_<userId>
-- Le jeu n'écrit rien d'autre : ni nom, ni e-mail, ni adresse IP, ni journal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Server = script.Parent
local DataStore = require(Server.DataStore)
local Leaderboard = require(Server.Leaderboard)

local Erasure = {}

-- Efface les deux clés d'un joueur. Idempotent : rejouer une demande déjà
-- traitée ne coûte que deux requêtes et ne casse rien.
function Erasure.erase(userId: number): boolean
	local profileOk = DataStore.erase(userId)
	local boardOk = Leaderboard.erase(userId)
	local ok = profileOk and boardOk
	print(string.format(
		"[BabyFoot] Droit a l'oubli %d : profil=%s classement=%s",
		userId,
		if profileOk then "efface" else "ECHEC",
		if boardOk then "efface" else "ECHEC"))
	return ok
end

-- Demande venant du joueur lui-même, en jeu. On efface puis on l'éjecte : c'est
-- le seul moyen d'être sûr que sa session ne réécrira rien derrière nous.
function Erasure.eraseAndKick(player: Player)
	local userId = player.UserId
	Erasure.erase(userId)
	player:Kick(
		"Tes donnees de jeu ont ete supprimees a ta demande.\n"
		.. "Tu peux revenir quand tu veux : une nouvelle partie repartira de zero."
	)
end

-- Demandes transmises par Roblox, traitées au démarrage du serveur. Espacées
-- volontairement : les suppressions passent par les mêmes quotas DataStore que
-- les sauvegardes des joueurs en cours de partie.
function Erasure.processPendingRequests()
	local pending = Config.ErasureRequests
	if #pending == 0 then return end

	task.spawn(function()
		print(string.format("[BabyFoot] %d demande(s) de droit a l'oubli a traiter.", #pending))
		for _, userId in pending do
			if typeof(userId) == "number" and userId > 0 then
				-- Un joueur listé mais connecté serait recréé par sa propre
				-- sauvegarde de sortie : on l'éjecte comme une demande directe.
				local player = Players:GetPlayerByUserId(userId)
				if player then
					Erasure.eraseAndKick(player)
				else
					Erasure.erase(userId)
				end
				task.wait(7)  -- ~1 requête / 6 s par clé côté Roblox
			end
		end
		print("[BabyFoot] Demandes de droit a l'oubli traitees.")
	end)
end

return Erasure
