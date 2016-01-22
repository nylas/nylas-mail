// argv[0] = node
// argv[1] = jasmine
// argv[2] = JASMINE_CONFIG_PATH=./jasmine/config.json
// argv[3] = NYLAS_ROOT_PATH=/path/to/nylas/root
var babelOptions = require('../../static/babelrc.json');
require('babel-core/register')(babelOptions);

var chalk = require('chalk')
var util = require('util')

console.errorColor = function(err){
  if (typeof err === "string") {
    console.error(chalk.red(err));
  } else {
    console.error(chalk.red(util.inspect(err)));
  }
}

console.inspect = function(val) {
  console.log(util.inspect(val, true, depth=7, colorize=true));
}

jasmine.NYLAS_ROOT_PATH = process.argv[3].split("NYLAS_ROOT_PATH=")[1]
jasmine.UNIT_TEST_TIMEOUT = 120*1000;
jasmine.BOOT_TIMEOUT = 30*1000;
jasmine.DEFAULT_TIMEOUT_INTERVAL = 30*1000

Promise = require('bluebird')
Promise.config({
  warnings: true,
  longStackTraces: true,
  cancellation: true
})

process.on("unhandledRejection", function(reason, promise) {
  if (reason.stack) { console.errorColor(reason.stack); }
  console.errorColor(promise);
});
