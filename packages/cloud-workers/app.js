const Metrics = require(`cloud-metrics`)
Metrics.startCapturing('n1-cloud-workers')

const {Logger} = require(`cloud-core`)

global.Metrics = Metrics
global.Logger = Logger.createLogger('n1-cloud-workers')

const onUnhandledError = (err) => {
  global.Logger.fatal(err, 'Unhandled error')
  global.Metrics.reportError(err)
}
process.on('uncaughtException', onUnhandledError)
process.on('unhandledRejection', onUnhandledError)

// CODE FOR PLUGINS GOES HERE!
// for now, just don't exit
setTimeout(() => {
  console.log("still here")
}, 1000000);
