# Cloud Core

## Cloud Core the Library
This contains all shared resources for Nylas Mail Cloud services.

You may use Cloud Core through a regular import: `import cloud-core from
'cloud-core'`

It is required as a dependency in the package.json of other modules.

This library isn't on the npm registry, but works as a dependency thanks to
`lerna bootstrap`

See index.js for what gets explicitly exported by this library.

# Cloud Infrastructure

This also contains scripts and config files used to deploy to production
infrastructure.

# Getting Started

## New to AWS:

1. Create an AWS account and sign in

1. Create your AWS IAM Security Credentials
  1. Go to Console -> Home -> IAM -> Users -> {{Your Name}} ->
     Security Credentials and click **Create access key**.

     Note that your private key will only be shown upon creation! If
     you've lost your private key you have to deactivate your old key and
     create a new one.

     You'll use your `AWS Access Key ID` and `AWS Secret Access Key` in
     the next step to login to our AWS environment and make the
     appropriate resources available.

1. Install [AWS CLI](https://aws.amazon.com/cli/):
  1. `brew install awscli` on Mac
  1. `pip install --user awscli` on Linux.

1. Run `aws configure` and add your AWS IAM Security Credentials (`AWS
   Access Key ID` and `AWS Secret Access Key`)

1. Install the [Elastic Benstalk CLI](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb-cli3-install.html?icmpid=docs_elasticbeanstalk_console):
  1. `brew install awsebcli` on Mac
  1. `pip install --upgrade --user awsebcli` on Linux

## New to Docker:

1. Read [Understanding Docker](https://docs.docker.com/engine/understanding-docker/)

1. Install [Docker](https://www.docker.com/products/overview) on your
   machine.

# Developing the Cloud Components Locally:

Open `cloud-core/pm2-dev.yml` and replace `XXXXXX` fields with values.
You need to generate a Google Client ID and Secret.

From the root of the nylas-mail repository:

```
npm install
npm run start-cloud
```

We use [pm2](http://pm2.keymetrics.io/) to launch a variety of processes
(sync, api, dashboard, processor, etc).

The `npm run start-cloud` command will run `pm2 start packages/cloud-core/pm2-dev.yml --no-daemon`

You can see the scripts that are running and their arguments in `pm2-dev.yml`

The `pm2-dev.yml` file sets up required environment variables for a dev
environment. The prod environment variables are stored on the (Elastic
Beanstalk AWS Console)[https://nylas.signin.aws.amazon.com/console].

To test to see if the basic API is up go to: `http://lvh.me:5100/ping`.
You should see `pong`. (`lvh.me` is a DNS hack that redirects back to 127.0.0.1.)

## Debugging

From the root of the nylas-mail repository:

```
npm run start-cloud-debug
```

will run `pm2 start packages/cloud-core/pm2-debug-cloud-api.yml --no-daemon`,
which passes in an `--inspect` flag to the cloud-api interpreter. This will
allow you to live debug using chrome web tools.

A useful tool to automatically connect to the chrome dev tools without knowing
the url is
[NIM](https://chrome.google.com/webstore/detail/nim-node-inspector-manage/gnhhdgbaldcilmgcpfddgdbkhjohddkj)

You can either set breakpoints through the inspector, or by putting `debugger;`
statements in your code.
