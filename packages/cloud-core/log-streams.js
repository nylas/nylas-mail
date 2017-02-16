const stream = require('stream');
const PrettyStream = require('bunyan-prettystream')


class StringStream extends stream.Writable {
  constructor() {
    super();
    this.chunks = [];
  }

  _write(chunk, enc, next) {
    this.chunks.push(chunk);
    next();
  }

  toString() {
    return Buffer.concat(this.chunks).toString();
  }

  reset() {
    this.chunks = [];
  }
}

const testStream = {
  level: 'info',
  stream: new StringStream(),
}

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
    case 'test': {
      return [
        testStream,
      ]
    }
    default: {
      return [
        stdoutStream,
      ]
    }
  }
}

module.exports = {getLogStreams, testStream}
