# Nylas Mail

This is a collection of all components required to run Nylas Mail.

1. [**Isomorphic Core**](https://github.com/nylas/nylas-mail-all/tree/master/packages/isomorphic-core): Shared code across local client and cloud servers
1. [**Client App**](https://github.com/nylas/nylas-mail-all/tree/master/packages/client-app): The main Electron app for Nylas Mail
   mirrored to open source repo.
1. [**Client Sync**](https://github.com/nylas/nylas-mail-all/tree/master/packages/client-sync): The local mailsync engine integreated in Nylas Mail
1. [**Client Private Plugins**](https://github.com/nylas/nylas-mail-all/tree/master/packages/client-private-plugins): Private Nylas Mail plugins (like SFDC)
1. [**Cloud API**](https://github.com/nylas/nylas-mail-all/tree/master/packages/cloud-api): The cloud-based auth and metadata APIs for N1
1. [**Cloud Core**](https://github.com/nylas/nylas-mail-all/tree/master/packages/cloud-core): Shared code used in all remote cloud services
1. [**Cloud Workers**](https://github.com/nylas/nylas-mail-all/tree/master/packages/cloud-workers): Cloud workers for services like send later

See `/packages` for the separate pieces. Each folder in `/packages` is
designed to be its own stand-alone repository. They are all bundled here
for the ease of source control management.

# Initial Setup for All Local & Cloud Services:

## New Computer (Mac):

1. Install [Homebrew](http://brew.sh/)
1. Install [NVM](https://github.com/creationix/nvm) & Redis `brew install nvm redis`
1. Install Node 6 via NVM: `nvm install 6`

## New Computer (Linux - Debian/Ubuntu):

1. Install Node 6+ via NodeSource (trusted):
  1. `curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -`
  1. `sudo apt-get install -y nodejs`
1. Install Redis locally `sudo apt-get install -y redis-server redis-tools`
benefit of letting us use subdomains.

# Running Nylas Mail

1. `npm install` (Only on fresh install and new packages)
1. `npm run start-client`: Starts Electron app client
1. `npm run start-cloud`: Starts cloud API locally
