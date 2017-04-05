const bunyan = require('bunyan')
const {getLogStreams} = require('./log-streams')
const NODE_ENV = process.env.NODE_ENV || 'unknown'

/**
 * We format our logs as JSON via Bunyan.
 * Read https://github.com/trentm/node-bunyan for more about how Bunyan
 * configures the log output.
 *
 * On production cloud infrastructure, we output logs to a flat file on the EC2
 * machine. That flat file is then uploaded to 2 cloud services:
 *
 * 1. Elasticsearch / Kibana - for raw log viewing / filtering. We have
 * filebeat installed on each AWS machine to do this automatically. SSH into a
 * cloud machine and see /etc/filebeat/filebeat.yml for details.
 *
 * 2. Honeycomb - for aggregate log statistics. We have honeytail installed on
 * each AWS machine to upload logs automatically. SSH into a cloud box and see
 * /etc/sv/honeytail/run
 *
 * From the Bunyan Docs:
 * log.info();     // Returns a boolean: is the "info" level enabled?
 *                 // This is equivalent to `log.isInfoEnabled()` or
 *                 // `log.isEnabledFor(INFO)` in log4j.
 *
 * log.info('hi');                     // Log a simple string message (or number).
 * log.info('hi %s', bob, anotherVar); // Uses `util.format` for msg formatting.
 *
 * log.info({foo: 'bar'}, 'hi');
 *                 // The first field can optionally be a "fields" object, which
 *                 // is merged into the log record.
 *
 * log.info(err);  // Special case to log an `Error` instance to the record.
 *                 // This adds an "err" field with exception details
 *                 // (including the stack) and sets "msg" to the exception
 *                 // message.
 * log.info(err, 'more on this: %s', more);
 *                 // ... or you can specify the "msg".
 *
 * log.info({foo: 'bar', err: err}, 'some msg about this error');
 *                 // To pass in an Error *and* other fields, use the `err`
 *                 // field name for the Error instance.
 *
 * You may use:
 * log.trace()
 * log.debug()
 * log.info()
 * log.warn()
 * log.error()
 * log.fatal()
 */
function createLogger(name, env = NODE_ENV) {
  const logger = bunyan.createLogger({
    name,
    env,
    serializers: bunyan.stdSerializers,
    streams: getLogStreams(name, env),
  })

  return Object.assign(logger, {
    forAccount(account = {}, parentLogger = logger) {
      return parentLogger.child({
        account_id: account.id,
        account_email: account.emailAddress,
        account_provider: account.provider,
        n1_id: account.n1IdentityToken || 'Not available',
      });
    },
  });
}

module.exports = {
  createLogger,
}
