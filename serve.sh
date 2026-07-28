#!/usr/bin/env bash
# Démarre le serveur Rojo pour ~/baby-foot (idempotent, localhost, port 34875).
#
# Bind sur 127.0.0.1 et pas 0.0.0.0 : l'API de `rojo serve` n'a AUCUNE
# authentification, donc un bind LAN laisse n'importe quelle machine du réseau
# lire et modifier le code source du projet. Studio se connecte en localhost.
# Pour piloter depuis une autre machine, passer par un tunnel SSH plutôt que de
# rouvrir l'écoute :  ssh -L 34875:127.0.0.1:34875 laurent@<cette-machine>
ROJO="$HOME/.local/bin/rojo"
cd "$HOME/baby-foot" || exit 1
if ss -ltn 2>/dev/null | grep -q ':34875 '; then
  echo "$(date '+%F %T') rojo serve déjà actif (port 34875)"; exit 0
fi
nohup "$ROJO" serve --address 127.0.0.1 --port 34875 >>"$HOME/baby-foot/rojo-serve.log" 2>&1 &
echo "$(date '+%F %T') rojo serve lancé (PID $!)"
