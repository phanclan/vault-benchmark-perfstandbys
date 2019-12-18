#!/bin/bash

if [ -f vault.pid ]; then
    kill $(cat vault.pid)
    rm vault.pid
fi
docker-compose down
rm -rf vault/data/singleinstance
rm -rf consul/data/*
