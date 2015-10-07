FROM ubuntu:14.04
WORKDIR /usr/local/src/N1
RUN apt-get update
RUN apt-get install -y libgnome-keyring-dev git build-essential software-properties-common libgtk2.0-0 libgconf-2-4 libnss3 libasound2 libxtst6 dbus-x11
RUN apt-add-repository ppa:chris-lea/node.js && apt-get update
RUN apt-get install -y nodejs
COPY . /usr/local/src/N1/
RUN ./script/bootstrap --no-quiet
CMD ["dbus-launch", "./N1.sh", "--dev"]
