// argv[0] = node
// argv[1] = jasmine
// argv[2] = JASMINE_CONFIG_PATH=./config.json
// argv[3] = NYLAS_ROOT_PATH=/path/to/nylas/root

var babelOptions = require('../static/babelrc.json');
require('babel-core/register')(babelOptions);

jasmine.NYLAS_ROOT_PATH = process.argv[3].split("NYLAS_ROOT_PATH=")[1]
jasmine.UNIT_TEST_TIMEOUT = 120*1000;
jasmine.BOOT_TIMEOUT = 30*1000;
jasmine.DEFAULT_TIMEOUT_INTERVAL = 30*1000
