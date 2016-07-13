# K2 - Sync Engine Experiment

# Initial Setup:

## New Computer (Mac):

1. Install [Homebrew](http://brew.sh/)
2. Install [VirtualBox 5+](https://www.virtualbox.org/wiki/Downloads)
3. Install [Docker for Mac](https://docs.docker.com/docker-for-mac/)
4. Install [NVM](https://github.com/creationix/nvm) `brew install nvm`
5. Install Node 6+ via NVM: `nvm install 6`
6. Install Redis locally `brew install redis`

## New Computer (Linux - Debian/Ubuntu):
1. Install Node 6+ via NodeSource (trusted):
  1. `curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -`
  1. `sudo apt-get install -y nodejs`
2. Install Redis locally `sudo apt-get install -y redis-server redis-tools`

## New to AWS:

1. Install [Elastic Beanstalk CLI](http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb-cli3-install.html#eb-cli3-install-osx): `sudo pip install awsebcli`
  1. On Linux, you may need to install Python 3's pip via `sudo apt-get install python3-pip` and then run `pip3 install --user awsebcli`. This installs to your home directory and you need to have `~/.local/bin` in your $PATH.
2. Install [AWS CLI](https://aws.amazon.com/cli/): `brew install awscli` on Mac and `pip install --user awscli` on Linux.
  1. Add your AWS IAM Security Credentials to `aws configure`.
  1. These are at Console Home -> IAM -> Users -> {{Your Name}} -> Security
     Credentials. Note that your private key was only shown unpon creation. If
     you've lost your private key you have to deactivate your old key and
     create a new one.
3. Get the K2 team private SSH key. (Ignore this when we have a Bastion Host). Ask someone on K2 for a copy of the private SSH key. Copy it to your ~/.ssh folder.
  1. `chmod 400 ~/.ssh/k2-keypair.pem`
  1. `ssh i ~/.ssh/k2-keypair.pem some-ec2-box-we-own.amazonaws.com`
4. Connect to Elastic Beanstalk instances: `eb init`. Select correct region. Select correct application.

# Developing Locally:

```
npm run start
npm run logs
npm run stop
```

We use [pm2](http://pm2.keymetrics.io/) to launch a variety of processes
(sync, api, dashboard, processor, etc).

You can see the scripts that are running and their arguments in
`/pm2-dev.yml`

To test to see if the basic API is up go to: `http://lvh.me:5100/ping`.  You
should see `pong`.

`lvh.me` is a DNS hack that redirects back to 127.0.0.1 with the added
benefit of letting us use subdomains.

# Deploying
