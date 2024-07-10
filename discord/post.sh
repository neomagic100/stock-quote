#!/bin/bash
text=$(cat config.txt)
arr=($text)
BOTNAME=${arr[0]}
WEBHOOK=${arr[1]}

/root/discord.sh \
--webhook-url "$WEBHOOK" \
--username "$BOTNAME" \
--text "$1"

