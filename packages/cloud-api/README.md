# N1-Cloud API

This is an Elastic Beanstalk hosted service which provides an API for Auth
and Metdata for Nylas N1 desktop clients.

# Getting Started

## New to AWS:
1. Make sure you can login at [https://nylas.signin.aws.amazon.com/console](https://nylas.signin.aws.amazon.com/console). (Ask a Nylas AWS admin to create your username if it doesn't exist already)
  1. Make sure you're on **US East (N. Virginia)**

1. Create your AWS IAM Security Credentials
  1. Go to Console -> Home -> IAM -> Users -> {{Your Name}} ->
     Security Credentials and click **Create access key**.

     Note that your private key will only be shown unpon creation! If
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

1. Setup the Elastic Beanstalk CLI to use `nylas-k2-api` on `us-east-1`.
   Note: This uses your AWS IAM Security Credentials you previously setup
   to authenticate against Elastic Beanstalk. **You must do this from the
   root /k2 folder**. It will create a gitignored `.elasticbeanstalk/`
   folder when it's done.
  1. `eb init`
  1. Use region `us-east-1`, application `nylas-k2-api`

1. Test out the Elastic Beanstalk CLI:
  1. `eb logs` OR `eb ssh`

1. NOTE: While `eb ssh` is the easiest, if you want to ssh into a specific
   box Get the K2 team private SSH key. Ask a K2 teammember for a copy of
   the private SSH key. Copy it to your ~/.ssh folder. We currently use a
   single master SSH keypair called `k2-keypair` that you can find in the
   Console -> EC2 Dashboard -> Network & Security -> Key Pairs.
  1. Move to `~/.ssh/`
  1. Make read-only: `chmod 400 ~/.ssh/k2-keypair.pem`
  1. `ssh -i ~/.ssh/k2-keypair.pem ec2-user@some-ec2-box-we-own.amazonaws.com`

# Developing the Cloud Components Locally:
From the root /K2 directory:

```
npm install
npm start
```

We use [pm2](http://pm2.keymetrics.io/) to launch a variety of processes
(sync, api, dashboard, processor, etc).

The `npm start` command will run `pm2 start ./pm2-dev.yml --no-daemon`

You can see the scripts that are running and their arguments in
`/pm2-dev.yml`

The `pm2-dev.yml` file sets up required environment variables for a dev
environment. The prod environment variables are stored on the (Elastic
Beanstalk AWS Console)[https://nylas.signin.aws.amazon.com/console].

To test to see if the basic API is up go to: `http://lvh.me:5100/ping`.
You should see `pong`.

`lvh.me` is a DNS hack that redirects back to 127.0.0.1 with the added

# Deploying
1. Make sure you're in the root of /k2, and have alredy run `eb init` then:

    `eb delpoy`

Woah wtf, did that just do‽ See the [EB CLI](http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb-cli3.html) as a start.

In a nutshell, this will use `git archive` to package up the repo as a
zip, upload it to the configured EC2 box, look for a `Dockerfile` in the
root, run `docker build` and then `docker run` with a large set of
hard-coded Amazon shell scripts.

Our Dockerfile exposes port 5100, and Elastic Beanstalk automatically maps
whatever single port is exposed to port 80 and serves it.

# Diagnosing Deploys
Use `eb ssh` to login to the EC2 instance.

The deploys are put in `/var/app/current`

You can access logs with `eb logs`

If you're SSH'd into the machine, you can see logs stored in: `/var/log/`.
The most common log to look at is `/var/log/eb-activity.log`

The script Elastic Beanstalk runs when deploying your app can be found
here: `/opt/elasticbeanstalk/hooks/appdeploy/enact/00run.sh`
