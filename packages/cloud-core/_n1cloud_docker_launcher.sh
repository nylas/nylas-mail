#!/bin/bash
# This is run from the DOCKERFILE
# The cwd context is where the DOCKERFILE is at the root of /nylas-mail-all

[ -z "$1" ] && echo '{"docker_startup": "FAILED", "error": "must include an AWS_SERVICE_NAME as arg1"}' && exit 1
AWS_SERVICE_NAME="$1"

case $AWS_SERVICE_NAME in 
    api|n1cloud-api)
        APP="n1cloud-api"
        echo '{"docker_startup": "'$APP'"}'
        ./node_modules/pm2/bin/pm2 start packages/cloud-core/pm2-prod-n1cloud-api.yml
        ./node_modules/pm2/bin/pm2 logs --raw
        ;;
    workers|worker|n1cloud-worker|n1cloud-workers)
        APP="n1cloud-workers"
        echo '{"docker_startup": "'$APP'"}'
        ./node_modules/pm2/bin/pm2 start packages/cloud-core/pm2-prod-n1cloud-workers.yml
        ./node_modules/pm2/bin/pm2 logs --raw
        ;;
    ei)
        APP="executiveintro"
        echo '{"docker_startup": "'$APP'"}'
        ## Uncomment these lines and update as necessary.
        #./node_modules/pm3/bin/pm2 start packages/cloud-core/pm2-prod-ei-frontend.yml
        #./node_modules/pm3/bin/pm2 start packages/cloud-core/pm2-prod-ei-backend.yml
        ./node_modules/pm2/bin/pm2 logs --raw
        ;;
     *)
        echo '{"docker_startup": "FAILED", "error": "unknown AWS_SERVICE_NAME name '$AWS_SERVICE_NAME'"}'
        exit 2
        ;;
esac
