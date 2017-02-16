# N1 Build Environment
Node version 0.10.x (Due to the version of electron currently used.)

# N1 Building and Tasks

This folder contains tasks to create production builds of N1

Tasks should not be executed from this folder, but rather from `/scripts`. The
`/scripts` folder has convenient methods that fix paths and do environment
checks.

Note that most of the task definitions are stored in `/build/tasks`

## Some useful tasks

NOTE: Run all of these from the N1 root folder.

**Linting:**

    `script/grunt lint`

**Building:**

    `script/grunt build`

The build folder has its own package.json and is isolated so we can use `npm`
to compile against v8's headers instead of `apm`
