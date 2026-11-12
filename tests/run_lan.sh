#!/bin/sh
# Runs the three-process LAN test. Usage: tests/run_lan.sh /path/to/godot [port]
GODOT="${1:-godot}"
PORT="${2:-24777}"
cd "$(dirname "$0")/.." || exit 1
"$GODOT" --headless --path . -s tests/lan.gd -- host "$PORT" > /tmp/lan_host.log 2>&1 &
H=$!
"$GODOT" --headless --path . -s tests/lan.gd -- client_a "$PORT" > /tmp/lan_a.log 2>&1 &
A=$!
"$GODOT" --headless --path . -s tests/lan.gd -- client_b "$PORT" > /tmp/lan_b.log 2>&1 &
B=$!
wait $H; RH=$?
wait $A; RA=$?
wait $B; RB=$?
grep -h "  ok \|FAIL\|RESULT\|SCRIPT ERROR" /tmp/lan_host.log /tmp/lan_a.log /tmp/lan_b.log
[ $RH -eq 0 ] && [ $RA -eq 0 ] && [ $RB -eq 0 ]
