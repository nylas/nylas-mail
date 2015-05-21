# FreeBSD

FreeBSD -RELEASE 64-bit is the recommended platform.

## Requirements

  * FreeBSD
  * `pkg install node`
  * `pkg install npm`
  * `pkg install libgnome-keyring`
  * `npm config set python /usr/local/bin/python2 -g` to ensure that gyp uses Python 2

## Instructions

  ```sh
  git clone https://github.com/nylas/edgehill
  cd edgehill
  script/build # Creates application at $TMPDIR/nylas-build/Nylas
  sudo script/grunt install # Installs command to /usr/local/bin/nylas
  ```

## Troubleshooting
