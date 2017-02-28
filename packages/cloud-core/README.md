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
1. Make sure you can login at [https://nylas.signin.aws.amazon.com/console](https://nylas.signin.aws.amazon.com/console). (Ask a Nylas AWS admin to create your username if it doesn't exist already)
  1. Make sure you're on **US West (Oregon)**

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

1. Setup the Elastic Beanstalk CLI to use `n1Cloud` on `us-west-2`.
   Note: This uses your AWS IAM Security Credentials you previously setup
   to authenticate against Elastic Beanstalk. **You must do this from the
   root /nylas-mail-all folder**. It will create a gitignored
   `.elasticbeanstalk/` folder when it's done.
  1. `eb init`
  1. Use region `us-west-2`, application `n1Cloud`

1. Test out the Elastic Beanstalk CLI:
  1. `eb logs` OR `eb ssh`

1. NOTE: While `eb ssh` is the easiest, if you want to ssh into a specific
   box Get the ec2-user private SSH key. Ask a Nylas teammember for a copy of
   the private SSH key. Copy it to your ~/.ssh folder. We currently use a
   single master SSH keypair called `k2-keypair` that you can find in the
   Console -> EC2 Dashboard -> Network & Security -> Key Pairs.
  1. Move to `~/.ssh/`
  1. Make read-only: `chmod 400 ~/.ssh/k2-keypair.pem`
  1. `ssh -i ~/.ssh/k2-keypair.pem ec2-user@some-ec2-box-we-own.amazonaws.com`

## New to Docker:

1. Read [Understanding Docker](https://docs.docker.com/engine/understanding-docker/)

1. Install [Docker](https://www.docker.com/products/overview) on your
   machine.

# Developing the Cloud Components Locally:
From the root /nylas-mail-all directory:

```
npm install
npm run start-cloud
```

We use [pm2](http://pm2.keymetrics.io/) to launch a variety of processes
(sync, api, dashboard, processor, etc).

The `npm run start-cloud` command will run `pm2 start
packages/cloud-core/pm2-dev.yml --no-daemon`

You can see the scripts that are running and their arguments in
`pm2-dev.yml`

The `pm2-dev.yml` file sets up required environment variables for a dev
environment. The prod environment variables are stored on the (Elastic
Beanstalk AWS Console)[https://nylas.signin.aws.amazon.com/console].

To test to see if the basic API is up go to: `http://lvh.me:5100/ping`.
You should see `pong`.

`lvh.me` is a DNS hack that redirects back to 127.0.0.1 with the added

## Debugging

From the root of the /nylas-mail-all directory:

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

# Deploying
1. Make sure you're in the root of /nylas-mail-cloud, and have alredy run `eb
   init`. Verify you're on the right env with `eb list` then:

    `./deploy-it <target>`

Woah wtf, did that just do‽ See the [EB CLI](http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb-cli3.html) as a start.

In a nutshell, this will use `git archive` to package up the repo as a
zip, upload it to the configured EC2 box, look for a `Dockerfile` in the
root, run `docker build` and then `docker run` with a large set of
hard-coded Amazon shell scripts.

Our Dockerfile exposes port 5100, and Elastic Beanstalk automatically maps
whatever single port is exposed to port 80 and serves it.

# Logs:

Don't use `eb logs`. It will download a static 100 lines of the
`eb-activity.log`, which only contains setup logs (no application logs).

1. `eb ssh`

1. `tail -f current` - This will tail and follow the application logs out of
   Docker. Use this to see what the app is doing.

1. `tail -f /var/log/eb-activity.log` - This shows you logs from when the
   container builds. See this to see the output of `npm install` and other
   setup.

# Diagnosing Deploys

Use `eb ssh` to login to the EC2 instance.

To enter the actual docker container, run:

```
source nylasbash
dockerbash
```

The deploys is copied to `/var/app/current`. Note that this is not the
running code. It's the starting place for `docker build` to run from. The
actual running code is within the docker container.

There are 2 common log files to look at:

1. `/var/log/eb-activity.log`. This will show you the progress of our npm
   install and other setup piped from the docker container. These are only
   the logs to setup the environment and do not contain application logs
2. `/var/log/eb-docker/containers/eb-current-app/{DOCKERVERSION}-stdouterr.log`
   is the location of the application logs of the current docker deploy.

The script Elastic Beanstalk runs when deploying your app can be found
here: `/opt/elasticbeanstalk/hooks/appdeploy/enact/00run.sh`
