# Getting Started with Nylas Mail on Windows

## Dependencies
1. **Visual Studio 2013**: You must have Visual Studio 2013 installed to build
Nylas Mail's native node modules. See the notes about Visual Studio below if you encounter compilation
errors. You can install [Visual Studio 2013 Community Edition](https://www.visualstudio.com/en-us/news/releasenotes/vs2013-community-vs) for free.
1. **Node**: You must have Node 6.x to run Nylas Mail's build script. Run `node -v` to check which version of NodeJS you are using.
1. **Python 2.7**: The `python` command must be on your `PATH` and must point to
Python 2.7 (not 3.x)
1. **Git**: The `git` command must be on your `PATH`

## Building

        git clone https://github.com/nylas/nylas-mail.git
        cd nylas-mail
        npm config set msvs_version 2013 --global
        script\bootstrap.cmd

## Running

        electron\electron.exe . --dev

# Common Issues:
While `script\bootstrap.cmd` is designed to work out of the box, it needs to
compile native extensions with node-gyp. If `script\bootstrap.cmd` fails due
to a compilation error, it is likely a Visual Studio configuration issue.

## Visual Studio
There are several versions of Visual Studio. `node-gyp` is designed to detect
the current version installed on your system. Nylas Mail only officially supports
Visual Studio 2013. If you are using Visual Studio 2015, be sure you chose to
install the C++ features in the Visual Studio installer.

To ensure `node-gyp` uses Visual Studio 2013, run the following commands:

```
set GYP_MSVS_VERSION=2013
npm config set msvs_version 2013 --global
```

## Node & NPM
We only use your system's Node to bootstrap `apm`. Once we have `apm` installed,
your system's Node no longer matters and we install remaining packages with `apm`.

However, since bootstrapping this requires native extensions to be built, we need
a version of `node` and `node-gyp` that is compatible with your current Visual Studio
setup.

There is a small chance that depending on where you setup Nylas Mail, you will get an
error about file paths being too long. If this happens, you will need to manually
install npm 3.x (npm 2.x comes shipped with most Node installations).

Instead of running the whole `script\bootstrap.cmd` script to test this, you can
`cd` into the `\build` folder, and from there run `npm install`. Only the
`build\package.json` modules need your system's Node.

## Python
The `python` executable must be on your `PATH`. Depending on how you installed Python,
you may need to ensure the `python.exe` can be found.
