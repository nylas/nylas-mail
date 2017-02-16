#!/bin/sh

./node_modules/pm2/bin/pm2 start ./pm2-prod-$1.yml
./node_modules/pm2/bin/pm2 logs --raw
