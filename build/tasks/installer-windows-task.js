const path = require('path');

module.exports = (grunt) => {
  const appPackageJSON = grunt.config('appJSON');

  grunt.config.merge({
    'create-windows-installer': {
      ia32: {
        usePackageJson: false,
        outputDirectory: path.join(grunt.config('appDir'), 'dist'),
        appDirectory: path.join(grunt.config('appDir'), 'dist', 'nylas-win32-ia32'),
        loadingGif: path.join(grunt.config('appDir'), 'build', 'resources', 'win', 'loading.gif'),
        iconUrl: 'http://edgehill.s3.amazonaws.com/static/nylas.ico',
        certificateFile: process.env.CERTIFICATE_FILE,
        certificatePassword: process.env.WINDOWS_CODESIGN_KEY_PASSWORD,
        description: appPackageJSON.description,
        version: appPackageJSON.version,
        title: appPackageJSON.productName,
        authors: 'Nylas Inc.',
        setupIcon: path.join(grunt.config('appDir'), 'build', 'resources', 'win', 'nylas.ico'),
        setupExe: 'NylasMailSetup.exe',
        exe: 'nylas.exe',
        name: 'Nylas',
      },
    },
  });

  grunt.loadNpmTasks('grunt-electron-installer');
}
