# This Dockerfile builds a production-ready image of K2 to be used across all
# services. See the Dockerfile documentation here:
# https://docs.docker.com/engine/reference/builder/

# Use the latest Node 6 base docker image
# https://github.com/nodejs/docker-node
FROM node:6

# Copy everything (excluding what's in .dockerignore) into an empty dir
COPY . /home
WORKDIR /home

# This installs global dependencies, then in the postinstall script, runs lerna
# bootstrap to install and link cloud-api, cloud-core, and cloud-workers.
# We need the --unsafe-perm param to run the postinstall script since Docker
# will run everything as sudo
RUN npm install --unsafe-perm

# This uses babel to compile any es6 to stock js for plain node
RUN node packages/cloud-core/build/build-n1-cloud

# External services run on port 80. Expose it.
EXPOSE 5100

# We use a start-aws command that automatically spawns the correct process
# based on environmpackages/cloud-coreent variables (which changes instance to instance)
CMD packages/cloud-core/_n1cloud_docker_launcher.sh ${AWS_SERVICE_NAME}
