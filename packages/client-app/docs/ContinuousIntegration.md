# Building N1 with Continuous Integration

    script/grunt ci

N1 is designed to be built into a production app for Mac, Windows, and Linux.
Only Nylas core team members currently have access to produce a production
build.

Production builds are code-signed with a Nylas, Inc. certificate and include a
handful of other proprietary assets such as custom fonts and sounds.

We currently use [Travis](https://travis-ci.org/nylas/nylas-mail) to build
on Mac & Windows and AppVeyor to build on Windows.

A build can be run from a local machines by Jenkins or manually; however,
several environment variables must be setup.:

**ALL ENVIRONMENT VARIABLES ARE ENCRYPTED**

They exist in an encrypted file that only Travis can read in
`build/resources/certs/set_env.sh`

**IMPORTANT** Do NOT remove the `2>/dev/null 1>/dev/null` in the
`before_install` scripts. If any of commands fail we don't want to leak
sensitive data in the output.

That file must be decrypted and `source`d before the environment variables can
use.

If not building on Travis, the environment variables must be manually decrypted
via gpg and sourced

We use [Travis encryption](https://docs.travis-ci.com/user/encrypting-files/)
and AppVeyor encryption to store the certificates, keys, and passwords

To login to GitHub and clone the Nylas submodule with private assets you need
to clone recursively (or `git submodule init; git submodule update`) with a
valid SSH key or login username and password.

We have a CI GitHub account: https://github.com/nylas-deploy-scripts
The password for that account is stored in the environment variable:
- `GITHUB_CI_ACCOUNT_PASSWORD`

For signing builds on Mac only when the certificates are already in the
Keychain (not Travis):
- `XCODE_KEYCHAIN` - The name of the Mac keychain that contains the
  certificates and private key.
- `XCODE_KEYCHAIN_PASSWORD` - Th password to that keychain.
- `KEYCHAIN_ACCESS` - Alternatively, the `XCODE_KEYCHAIN` and
  `XCODE_KEYCHAIN_PASSWORD` in a single colon-separated string.

Alternatively, on Travis we decrypt the actual certificate files and create a
temporary keychain. To do this we need the password to the private key. That's
stored in:
- `APPLE_CODESIGN_KEY_PASSWORD`

For signing builds on Windows only:
- `CERTIFICATE_FILE` - The Windows certificate
- `CERTIFICATE_PASSWORD` - The password for the private key on the cert

To download Electron:
- `NYLAS_GITHUB_OAUTH_TOKEN` - The OAuth token to use for GitHub API requests. See
  https://github.com/atom/grunt-download-electron

To upload built artifacts to S3:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

To notify when builds are done:
- `NYLAS_INTERNAL_HOOK_URL` - Nylas internal Slack token and url
