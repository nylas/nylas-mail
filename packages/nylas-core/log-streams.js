const os = require('os');
const createCWStream = require('bunyan-cloudwatch')
const PrettyStream = require('bunyan-prettystream')
const Bunyan2Loggly = require('bunyan-loggly')

const {LOGGLY_TOKEN} = process.env
const logglyConfig = (name, env) => ({
  token: LOGGLY_TOKEN,
  subdomain: 'nylas',
  tags: [`${name}-${env}`],
})
const cloudwatchConfig = (name, env) => ({
  logGroupName: `k2-${env}`,
  logStreamName: `${name}-${env}-${os.hostname()}`,
  cloudWatchLogsOptions: {
    region: 'us-east-1',
  },
})

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
        mode: 'pm2'
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
        {
          type: 'raw',
          reemitErrorEvents: true,
          stream: new Bunyan2Loggly(logglyConfig(name, env)),
        },
        {
          type: 'raw',
          reemitErrorEvents: true,
          stream: createCWStream(cloudwatchConfig(name, env)),
        },
      ]
    }
  }
}

module.exports = {getLogStreams}
