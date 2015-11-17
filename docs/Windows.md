# Getting Started with N1 on Windows

## Dependencies
1. **Visual Studio**: You must have Visual Studio installed to build native
extensions. See the notes about Visual Studio below if you encounter compilation
errors.
1. **Node**: Node 0.10, 0.11, 0.12, and 4.x supported
1. **Python 2.7**: The `python` command must be on your `PATH` and must point to
Python 2.7 (not 3.x)
1. **Git**: The `git` command must be on your `PATH`

## Building

        git clone https://github.com/nylas/N1.git
        cd N1
        script\bootstrap.cmd

## Running

        electron\electron.exe . --dev

# Common Issues:
While `script\bootstrap.cmd` is designed to work out of the box, we have to
compile a few native extensions via node-gyp and expect certain programs to be
available on your `PATH`. If `script\bootstrap.cmd` fails due to a compilation
error, it is likely due to a Visual Studio problem.

## Visual Studio
There are now several versions of Visual Studio. Node-gyp is designed to detect
the current version installed on your system. If you are using Visual Studio 2015,
you must be using a newer version of Node.

If during compilation, node-gyp looks in the wrong place for headers, you can
explicitly set the version of Visual Studio you want it to use by setting the
`GYP_MSVS_VERSION` environment variable to the year of your Visual Studio version.
Valid values are `2015`, `2013`, `2013e`, `2012`, etc. (`e` stands for "express").
The full set of values are [here](https://github.com/nodejs/node/blob/v4.2.1/tools/gyp/pylib/gyp/MSVSVersion.py#L411)

## Node & Npm
We only use your system's Node to bootstrap `apm`. Once we have `apm` installed,
your system's Node no longer matters and we install remaining packages with `apm`.

However, since bootstrapping this requires native extensions to be built, we need
a version of `node` and `node-gyp` that is compatible with your current Visual Studio
setup.

There is a small chance that depending on where you setup N1, you will get an
error about file paths being too long. If this happens, you will need to manually
install npm 3.x (npm 2.x comes shipped with most Node installations).

Instead of running the whole `script\bootstrap.cmd` script to test this, you can
`cd` into the `\build` folder, and from there run `npm install`. Only the
`build\package.json` modules need your system's Node.

## Python
The `python` executable must be on your `PATH`. Depending on how you installed Python,
you may need to ensure the `python.exe` can be found.
