const PrettyStream = require('bunyan-prettystream')

const stdoutStream = {
  level: 'info',
  stream: process.stdout,
}

const getLogStreams = (name, env) => {
  switch (env) {
    case 'development': {
      const prettyStdOut = new PrettyStream({
        mode: 'pm2',
        lessThan: 'error',
      });
      const prettyStdErr = new PrettyStream({
        mode: 'pm2',
      });
      prettyStdOut.pipe(process.stdout);
      prettyStdErr.pipe(process.stderr);
      return [
        {
          type: 'raw',
          level: 'error',
          stream: prettyStdErr,
          reemitErrorEvents: true,
        },
        {
          type: 'raw',
          level: 'debug',
          stream: prettyStdOut,
          reemitErrorEvents: true,
        },
      ]
    }
    default: {
      return [
        stdoutStream,
      ]
    }
  }
}

module.exports = {getLogStreams}
