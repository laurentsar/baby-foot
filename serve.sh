#!/usr/bin/env bash
# Démarre le serveur Rojo pour ~/baby-foot (idempotent, LAN, port 34875).
ROJO="$HOME/.local/bin/rojo"
cd "$HOME/baby-foot" || exit 1
if ss -ltn 2>/dev/null | grep -q ':34875 '; then
  echo "$(date '+%F %T') rojo serve déjà actif (port 34875)"; exit 0
fi
nohup "$ROJO" serve --address 0.0.0.0 --port 34875 >>"$HOME/baby-foot/rojo-serve.log" 2>&1 &
echo "$(date '+%F %T') rojo serve lancé (PID $!)"
