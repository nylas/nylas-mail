# K2 - The local sync engine for Nylas N1

# Initial Setup:

## New Computer (Mac):

1. Install [Homebrew](http://brew.sh/)
4. Install [NVM](https://github.com/creationix/nvm) `brew install nvm`
5. Install Node 6 via NVM: `nvm install 6`
6. Install Redis locally `brew install redis`

## New Computer (Linux - Debian/Ubuntu):
1. Install Node 6+ via NodeSource (trusted):
  1. `curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -`
  1. `sudo apt-get install -y nodejs`
2. Install Redis locally `sudo apt-get install -y redis-server redis-tools`

# Developing Locally:

```
npm install
npm start
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
