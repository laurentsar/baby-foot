#!/usr/bin/env bash
# Démarre / maintient le serveur Rojo pour ~/baby-foot (idempotent, localhost, port 34875).
#
# Bind sur 127.0.0.1 et pas 0.0.0.0 : l'API de `rojo serve` n'a AUCUNE
# authentification, donc un bind LAN laisse n'importe quelle machine du réseau
# lire et modifier le code source du projet. Studio se connecte en localhost
# (via le port-forward de VS Code Remote-SSH, ou un tunnel `ssh -L` depuis .148).
#
# Appelé par cron (@reboot + toutes les 3 min) : idempotent, il NE tue jamais un
# serveur vivant. Chaque passage écrit un heartbeat horodaté dans keeper.log
# (traçabilité), et rojo-serve.log ne reçoit que les vraies relances + la sortie
# de rojo — pas une ligne toutes les 3 min.
ROJO="$HOME/.local/bin/rojo"
KEEPERLOG="$HOME/baby-foot/keeper.log"
SERVELOG="$HOME/baby-foot/rojo-serve.log"
cd "$HOME/baby-foot" || exit 1

hb() { echo "$(date '+%F %T') $*" >> "$KEEPERLOG"; }

if ss -ltn 2>/dev/null | grep -q ':34875 '; then
  hb "check OK — rojo actif (port 34875)"
else
  nohup "$ROJO" serve --address 127.0.0.1 --port 34875 >>"$SERVELOG" 2>&1 &
  pid=$!
  hb "RELANCE — rojo était DOWN → relancé (PID $pid)"
  echo "$(date '+%F %T') rojo serve relancé (PID $pid)"
fi

# Rotation : garde les 1000 dernières lignes du heartbeat (évite la croissance sans fin).
if [ -f "$KEEPERLOG" ] && [ "$(wc -l < "$KEEPERLOG" 2>/dev/null || echo 0)" -gt 1200 ]; then
  tail -n 1000 "$KEEPERLOG" > "$KEEPERLOG.tmp" && mv "$KEEPERLOG.tmp" "$KEEPERLOG"
fi
exit 0
