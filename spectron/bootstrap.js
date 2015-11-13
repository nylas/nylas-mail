var babelOptions = require('../static/babelrc.json');
require('babel-core/register')(babelOptions);
jasmine.APP_PATH = process.argv.slice(3)[0].split('APP_PATH=')[1];
jasmine.DEFAULT_TIMEOUT_INTERVAL = 30000;
