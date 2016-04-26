# Configuration

This document outlines configuration options which aren't exposed via N1's
preferences interface, but may be useful.

## Running Against Open Source Sync Engine

N1 needs to fetch mail from a running instance of the [Nylas Sync
Engine](https://github.com/nylas/sync-engine). The Sync Engine is what
abstracts away IMAP, POP, and SMTP to serve your email on any provider
through a modern, RESTful API.

By default the N1 source points to our hosted version of the sync-engine;
however, the Sync Engine is open source and you can run it yourself.

1. Install the Nylas Sync Engine in a Vagrant virtual machine by following the
  [installation and setup](https://github.com/nylas/sync-engine#installation-and-setup)
  instructions.

2. Once you've installed the sync engine, add accounts by running the inbox-auth
   script. For Gmail accounts, the syntax is simple: `bin/inbox-auth you@gmail.com`

3. Start the sync engine by running `bin/inbox-start` and the API via `bin/inbox-api`.

4. After you've linked accounts to the Sync Engine, open or create a file at
   `~/.nylas/config.json`. This is the config file that N1 reads at launch.

   Replace `env: "production"` with `env: "local"` at the top level of the config.
   This tells N1 to look at `localhost:5555` for the sync engine. If you've deployed
   the sync engine elsewhere, add the following block beneath `env: "local"`:

   ```
   syncEngine:
     APIRoot: "http://mysite.com:5555"
   ```

   NOTE: If you are using a custom network layout and your sync engine is not on
   `localhost:5555`, use `env: custom` instead along with your alternate IP for the
   API Root, for example `192.168.1.00:5555`

   ```
   env: "custom"
   syncEngine:
     APIRoot: "http://192.168.1.100:5555"
   ```

   Copy the JSON array of accounts returned from the Sync Engine's `/accounts`
   endpoint (ex. `http://localhost:5555/accounts`) into the config file at the
   path `*.nylas.accounts`.

   N1 will look for access tokens for these accounts under `*.nylas.accountTokens`,
   but the open source version of the sync engine does not provide access tokens.
   When you make requests to the open source API, you provide an account
   ID in the HTTP Basic Auth username field instead of an account token.

   For each account you've created, add an entry to `*.nylas.accountTokens`
   with the account ID as both the key and value.

   The final `config.json` file should look something like this:

       {
         "*": {
           "env": "local",
           "nylas": {
             "accounts": [
               {
                 "server_id": "{ACCOUNT_ID_1}",
                 "object": "account",
                 "account_id": "{ACCOUNT_ID_1}",
                 "name": "{YOUR NAME}",
                 "provider": "{PROVIDER_NAME}",
                 "email_address": "{YOUR_EMAIL_ADDRESS}",
                 "organization_unit": "{folder or label}",
                 "id": "{ACCOUNT_ID_1}"
               },
               {
                 "server_id": "{ACCOUNT_ID_2}",
                 "object": "account",
                 "account_id": "{ACCOUNT_ID_2}",
                 "name": "{YOUR_NAME}",
                 "provider": "{PROVIDER_NAME}",
                 "email_address": "{YOUR_EMAIL_ADDRESS}",
                 "organization_unit": "{folder or label}",
                 "id": "{ACCOUNT_ID_2}"
               }
             ],
             "accountTokens": {
               "{ACCOUNT_ID_1}": "{ACCOUNT_ID_1}",
               "{ACCOUNT_ID_2}": "{ACCOUNT_ID_2}"
             }
           }
         }
       }

Note: `{ACCOUNT_ID_1}` refers to the database ID of the `Account` object
you create when setting up the Sync Engine. The JSON above should match
fairly closely with the Sync Engine `Account` object.


## Other Config Options

- `core.workspace.interfaceZoom`: If you'd like the N1 interface to be smaller or larger, this option allows you to scale the UI globally. (Default: 1)
