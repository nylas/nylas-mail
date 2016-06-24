# K2 - Sync Engine Experiment

# Initial Setup

1. Download https://toolbelt.heroku.com/

```
brew install redis
nvm install 6
npm install
```

# Running locally

```
npm start
```

## Auth an account

```
curl -X POST -H "Content-Type: application/json" -d '{"email":"inboxapptest2@fastmail.fm", "name":"Ben Gotow", "provider":"imap", "settings":{"imap_username":"inboxapptest1@fastmail.fm","imap_host":"mail.messagingengine.com","imap_port":993,"smtp_host":"mail.messagingengine.com","smtp_port":0,"smtp_username":"inboxapptest1@fastmail.fm", "smtp_password":"trar2e","imap_password":"trar2e","ssl_required":true}}' "http://localhost:5100/auth?client_id=123"
```
