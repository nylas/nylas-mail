FROM mhart/alpine-node:0.12
WORKDIR /usr/local/src/N1
RUN apk --update add git python make g++
RUN apk add linux-headers
RUN apk add libgnome-keyring-dev
COPY . /usr/local/src/N1/
#RUN npm install --loglevel error --cwd=/usr/local/src/N1/build --ignoreStdout=true
RUN script/bootstrap --no-quiet
