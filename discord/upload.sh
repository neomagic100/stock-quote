#!/bin/bash

source /home/michael/discord/config.sh

./discord.sh \
--webhook-url "$WEBHOOK" \
--file "$1" \
--username "$BOTNAME"
