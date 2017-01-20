/* eslint global-require: 0 */
const path = require('path');

module.exports = (grunt) => {
  if (!grunt.option('platform')) {
    grunt.option('platform', process.platform);
  }

  // This allows all subsequent paths to the relative to the root of the repo
  grunt.config.init({
    'appDir': path.resolve('..'),
    'outputDir': path.resolve('../dist'),
    'appJSON': grunt.file.readJSON('../package.json'),
    'source:coffeescript': [
      'internal_packages/**/*.cjsx',
      'internal_packages/**/*.coffee',
      'dot-nylas/**/*.coffee',
      'src/**/*.coffee',
      'src/**/*.cjsx',
      'spec/**/*.cjsx',
      'spec/**/*.coffee',
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
      'spec/**/*.es6',
      'spec/**/*.es',
      'spec/**/*.jsx',
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

  grunt.loadTasks('./tasks');
  grunt.file.setBase(path.resolve('..'));

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

  const {shouldPublishBuild} = require('./tasks/task-helpers')(grunt);
  if (shouldPublishBuild()) {
    postBuildSteps.push('publish');
  }

  grunt.registerTask('build', ['setup-travis-keychain', 'packager']);
  grunt.registerTask('lint', ['eslint', 'lesslint', 'nylaslint', 'coffeelint', 'csslint']);
  grunt.registerTask('ci', ['build'].concat(postBuildSteps));
}
