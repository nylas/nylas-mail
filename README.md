# K2 - Sync Engine Experiment

# Initial Setup:

## New Computer (Mac):

1. Install [Homebrew](http://brew.sh/)
1. Install [VirtualBox 5+](https://www.virtualbox.org/wiki/Downloads)
1. Install [Docker for Mac](https://docs.docker.com/docker-for-mac/)
1. Install [NVM](https://github.com/creationix/nvm) `brew install nvm`
1. Install Node 6+ via NVM: `nvm install 6`

## New to AWS:

1. Install [Elastic Beanstalk CLI](http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb-cli3-install.html#eb-cli3-install-osx): `brew install awsebcli`
1. Install [AWS CLI](https://aws.amazon.com/cli/): `brew install awscli`
  1. Add your AWS IAM Security Credentials to `aws configure`.
  1. These are at Console Home -> IAM -> Users -> {{Your Name}} -> Security
     Credentials. Note that your private key was only shown unpon creation. If
     you've lost your private key you have to deactivate your old key and
     create a new one.
1. Get the K2 team private SSH key. (Ignore this when we have a Bastion Host). Ask someone on K2 for a copy of the private SSH key. Copy it to your ~/.ssh folder.
  1. `chmod 400 ~/.ssh/k2-keypair.pem`
  1. `ssh i ~/.ssh/k2-keypair.pem some-ec2-box-we-own.amazonaws.com`
1. Connect to Elastic Beanstalk instances: `eb init`. Select correct region. Select correct application.

# Developing Locally:

```
npm start
```

# Deploying
