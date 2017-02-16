# K2 - Local Sync Engine & Cloud Services for Nylas Mail

This is a collection of all sync and cloud components required to run N1.

1. [**Cloud API**](https://github.com/nylas/K2/tree/master/packages/cloud-api): The cloud-based auth and metadata APIs for N1
1. [**Cloud Core**](https://github.com/nylas/K2/tree/master/packages/cloud-core): Shared code used in all remote cloud services
1. [**Cloud Workers**](https://github.com/nylas/K2/tree/master/packages/cloud-workers): Cloud workers for services like send later
1. [**Isomorphic Core**](https://github.com/nylas/K2/tree/master/packages/isomorphic-core): Shared code across local client and cloud servers
1. [**Local Sync**](https://github.com/nylas/K2/tree/master/packages/local-sync): The local mailsync engine integreated in Nylas Mail

See `/packages` for the separate pieces. Each folder in `/packages` is
designed to be its own stand-alone repository. They are all bundled here
for the ease of source control management.

# Initial Setup for All Local & Cloud Services:

## New Computer (Mac):

1. Install [Homebrew](http://brew.sh/)
1. Install [NVM](https://github.com/creationix/nvm) `brew install nvm`
1. Install Node 6 via NVM: `nvm install 6`
1. Install Redis locally `brew install redis`

## New Computer (Linux - Debian/Ubuntu):

1. Install Node 6+ via NodeSource (trusted):
  1. `curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -`
  1. `sudo apt-get install -y nodejs`
1. Install Redis locally `sudo apt-get install -y redis-server redis-tools`
benefit of letting us use subdomains.
