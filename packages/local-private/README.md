# Nylas Mail

This repo contains proprietary Nylas plugins and other extensions to N1

It is included as a submodule of the open source N1 repo at
`pro/nylas`

From the root of N1, run `script/grunt add-nylas-build-resources` to manually
copy the files from this repo into the appropriate places within N1.

That script is run as part of the N1 `build` task. Machines that have access
this repo will automatically include the proprietary plugins.
