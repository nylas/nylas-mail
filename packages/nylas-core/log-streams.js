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
      const prettyStdOut = new PrettyStream();
      prettyStdOut.pipe(process.stdout);
      return [
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
