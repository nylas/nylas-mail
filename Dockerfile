# This Dockerfile builds a production-ready image of K2 to be used across all
# services. See the Dockerfile documentation here:
# https://docs.docker.com/engine/reference/builder/

# Use the latest Node 6 base docker image
# https://github.com/nodejs/docker-node
FROM node:6

# Copy everything (excluding what's in .dockerignore) into an empty dir
COPY . /home
WORKDIR /home

RUN npm install --production

# This will do an `npm install` for each of our modules and then link them all
# together. See more about Lerna here: https://github.com/lerna/lerna We have
# to run this separately from npm postinstall due to permission issues.
RUN node_modules/.bin/lerna bootstrap

# This uses babel to compile any es6 to stock js for plain node
RUN npm run build-n1-cloud

# External services run on port 80. Expose it.
EXPOSE 5100

# We use a start-aws command that automatically spawns the correct process
# based on environment variables (which changes instance to instance)
CMD ./node_modules/pm2/bin/pm2 start --no-daemon ./pm2-prod-${AWS_SERVICE_NAME}.yml
