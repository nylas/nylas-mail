var babelOptions = require('../static/babelrc.json');
require('babel-core/register')(babelOptions);
jasmine.APP_PATH = process.argv.slice(3)[0].split('APP_PATH=')[1];
jasmine.APP_ARGS = process.argv.slice(4)[0].split('APP_ARGS=')[1].split(',');
jasmine.DEFAULT_TIMEOUT_INTERVAL = 30000;
jasmine.BOOT_WAIT = 15000;
