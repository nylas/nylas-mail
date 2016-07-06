const proc = require('child_process');

// TODO: Swtich on env variables
proc.spawn('node', ['packages/nylas-api/app.js'], {
  stdio: 'inherit'
})
