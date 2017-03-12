#!/bin/bash

# Redis is one of those servers which by default accept connections from
# everywhere. Luckily, homebrew and presumably debian come with sane defaults.
# However, they're located in different directories.
if [[ $(uname) = 'Darwin' ]]; then
    echo "Running redis from Homebrew..."
    redis-server /usr/local/etc/redis.conf
fi

if [[ $(uname) = 'Linux' ]]; then
    # redis-server package may have redis running by default; don't crash if so
    pgrep -lf redis-server
    if [ $? -ne 0 ]; then
        echo "Running redis"
        redis-server /etc/redis/redis.conf
    else
        echo "Redis already running"
        sleep infinity
    fi
fi
