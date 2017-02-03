#!/bin/sh

# Redis is one of those servers which by default
# accept connections from everywhere. Luckily,
# homebrew and presumably debian come with sane
# defaults. However, they're located in different
# directories.
if [[ $(uname) = 'Darwin' ]]; then
    echo "Running redis from Homebrew..."
    redis-server /usr/local/etc/redis.conf
fi

if [[ $(uname) = 'Linux' ]]; then
    echo "Running redis"
    redis-server /etc/redis/redis.conf
fi
