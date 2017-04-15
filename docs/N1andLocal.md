# Use N1 and a local sync instance

* Install N1
    * Either build it from source or use the install package.
* Clone the sync engine 
* [Install the sync engine](https://github.com/nylas/sync-engine#installation-and-setup)
* Dont't start it yet
* Add your account ```bin/inbox-auth ben.bitdiddle1861@gmail.com```
* Now start the sync
* Additionally start the api ```bin/inbox-api```
* Back on your machine open ~/.nylas/config.cson
* If there is stuff in there, delete it
* Paste this:
```
"*":
  env: "local"
  nylas:
    accounts: [
```
* Visit http://localhost:5555/accounts
* Copy the output between the {}
* Paste it in the config file, after the stuff from before.
* Finally add the following information at the end of the file. The accountTokens have to be there for every account.
```
]
    accountTokens:
        "account_id value without quotations marks": "account_id value with quotations marks"
```
* Save
* Start N1
