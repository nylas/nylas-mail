/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */
const path = require('path');

module.exports = (grunt) => {
  if (!grunt.option('platform')) {
    grunt.option('platform', process.platform);
  }

  /**
   * The main appDir is that of the root nylas-mail-all repo. This Gruntfile
   * is designed to be run from the npm-build-client task whose repo root is
   * the main nylas-mail-all package.
   */
  const appDir = path.resolve(path.join('packages', 'client-app'));
  const buildDir = path.join(appDir, 'build');
  const tasksDir = path.join(buildDir, 'tasks');
  const taskHelpers = require(path.join(tasksDir, 'task-helpers'))(grunt)

  // This allows all subsequent paths to the relative to the root of the repo
  grunt.config.init({
    'taskHelpers': taskHelpers,
    'rootDir': path.resolve('./'),
    'buildDir': buildDir,
    'appDir': appDir,
    'classDocsOutputDir': './docs_src/classes',
    'outputDir': path.join(appDir, 'dist'),
    'appJSON': grunt.file.readJSON(path.join(appDir, 'package.json')),
    'source:coffeescript': [
      'internal_packages/**/*.cjsx',
      'internal_packages/**/*.coffee',
      'dot-nylas/**/*.coffee',
      'src/**/*.coffee',
      'src/**/*.cjsx',
      '!src/**/node_modules/**/*.coffee',
      '!internal_packages/**/node_modules/**/*.coffee',
    ],
    'source:es6': [
      'internal_packages/**/*.jsx',
      'internal_packages/**/*.es6',
      'internal_packages/**/*.es',
      'dot-nylas/**/*.es6',
      'dot-nylas/**/*.es',
      'src/**/*.es6',
      'src/**/*.es',
      'src/**/*.jsx',
      'src/K2/**/*.js', // K2 doesn't use ES6 extension, lint it anyway!
      '!src/K2/packages/local-private/src/error-logger-extensions/*.js',
      '!src/**/node_modules/**/*.es6',
      '!src/**/node_modules/**/*.es',
      '!src/**/node_modules/**/*.jsx',
      '!src/K2/**/node_modules/**/*.js',
      '!internal_packages/**/node_modules/**/*.es6',
      '!internal_packages/**/node_modules/**/*.es',
      '!internal_packages/**/node_modules/**/*.jsx',
    ],
  });

  grunt.loadTasks(tasksDir);
  grunt.file.setBase(appDir);

  grunt.registerTask('docs', ['docs-build', 'docs-render']);
  grunt.registerTask('lint', [
    'eslint',
    'lesslint',
    'nylaslint',
    'coffeelint',
    'csslint',
  ]);

  if (grunt.option('platform') === 'win32') {
    grunt.registerTask("build-client", [
      "package",
      // The Windows electron-winstaller task must be run outside of grunt
    ]);
  } else if (grunt.option('platform') === 'darwin') {
    grunt.registerTask("build-client", [
      "package",
      "create-mac-zip",
      "create-mac-dmg",
    ]);
  } else if (grunt.option('platform') === 'linux') {
    grunt.registerTask("build-client", [
      "package",
      "create-deb-installer",
      "create-rpm-installer",
    ]);
  }
}
