#!/bin/bash

# Start the podman bedrock server

sudo podman run -d -it --name minecraft-bedrock \
  -v mc-bedrock-data:/data \
  -p 30132:30132/udp \
  -e MAX_THREADS="16" \
  -e DIFFICULTY="normal" \
  -e MAX_PLAYERS="20" \
  -e SERVER_PORT="30132" \
  -e EULA="true" \
  -e SERVER_NAME="Sean's Bedrock Server" \
  -e VERSION="latest" \
  -e OPS="2535466844222619" \
  itzg/minecraft-bedrock-server
