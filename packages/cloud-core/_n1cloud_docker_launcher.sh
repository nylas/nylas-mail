#!/bin/sh
# This is run from the DOCKERFILE
# The cwd context is where the DOCKERFILE is at the root of /nylas-mail-all
./node_modules/pm2/bin/pm2 start packages/cloud-core/pm2-prod-$1.yml
./node_modules/pm2/bin/pm2 logs --raw
