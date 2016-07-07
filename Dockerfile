# Use the latest Node 6 base docker image
# https://github.com/nodejs/docker-node
FROM node:6

# Copy everything (excluding what's in .dockerignore) into an empty dir
COPY . /home
WORKDIR /home

RUN npm install --production

# This will do an `npm install` for each of our modules and then link them
# all together. See more about Lerna here: https://github.com/lerna/lerna
RUN node_modules/.bin/lerna bootstrap

# External services run on port 5100. Expose it.
EXPOSE 5100

# We use a start-aws command that automatically spawns the correct process
# based on environment variables (which changes instance to instance)
CMD [ "npm", "run", "start-aws"]
