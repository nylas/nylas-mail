/* eslint global-require: 0 */
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

  // Register CI Tasks
  const postBuildSteps = [];
  if (grunt.option('platform') === 'win32') {
    postBuildSteps.push('create-windows-installer')
  } else if (grunt.option('platform') === 'darwin') {
    postBuildSteps.push('create-mac-zip')
    postBuildSteps.push('create-mac-dmg')
  } else if (grunt.option('platform') === 'linux') {
    postBuildSteps.push('create-deb-installer');
    postBuildSteps.push('create-rpm-installer');
  }

  if (taskHelpers.shouldPublishBuild()) {
    postBuildSteps.push('publish');
  }

  grunt.registerTask('build', ['setup-travis-keychain', 'packager']);
  grunt.registerTask('lint', ['eslint', 'lesslint', 'nylaslint', 'coffeelint', 'csslint']);
  grunt.registerTask('ci', ['build'].concat(postBuildSteps));

  grunt.registerTask('docs', ['docs-build', 'docs-render']);

}
