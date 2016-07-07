# https://github.com/nodejs/docker-node
FROM node:6
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
COPY package.json /usr/src/app/
RUN npm install
COPY . /usr/src/app
EXPOSE 8080
CMD [ "./node_modules/pm2/bin/pm2", "start", "./pm2-prod-${AWS_SERVICE_NAME}.yml"]
