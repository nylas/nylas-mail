/* eslint global-require:0 */
const fs = require('fs');
const path = require('path');
const _ = require('underscore');

module.exports = (grunt) => {
  const {spawn} = require('./task-helpers')(grunt);

  const outputDir = grunt.config.get('outputDir');
  const contentsDir = path.join(grunt.config('outputDir'), `nylas-linux-${process.arch}`);
  const linuxAssetsDir = path.resolve(path.join('resources', 'linux'));
  const arch = {
    ia32: 'i386',
    x64: 'amd64',
  }[process.arch];

  // a few helpers

  const writeFromTemplate = (filePath, data) => {
    const template = _.template(String(fs.readFileSync(filePath)))
    const finishedPath = path.join(outputDir, path.basename(filePath).replace('.in', ''));
    grunt.file.write(finishedPath, template(data));
    return finishedPath;
  }

  const getInstalledSize = (dir, callback) => {
    const cmd = 'du';
    const args = ['-sk', dir];
    spawn({cmd, args}, (error, {stdout}) => {
      const installedSize = stdout.split(/\s+/).shift() || '200000'; // default to 200MB
      callback(null, installedSize);
    });
  }

  grunt.registerTask('create-rpm-installer', 'Create rpm package', function mkrpmf() {
    const done = this.async()
    if (!arch) {
      done(new Error(`Unsupported arch ${process.arch}`));
      return;
    }

    const rpmDir = path.join(grunt.config('outputDir'), 'rpm');
    if (grunt.file.exists(rpmDir)) {
      grunt.file.delete(rpmDir, {force: true});
    }

    const templateData = {
      name: grunt.config('appJSON').name,
      version: grunt.config('appJSON').version,
      description: grunt.config('appJSON').description,
      productName: grunt.config('appJSON').productName,
      linuxShareDir: '/usr/local/share/nylas',
      linuxAssetsDir: linuxAssetsDir,
      contentsDir: contentsDir,
    }

    // This populates nylas.spec
    const specInFilePath = path.join(linuxAssetsDir, 'redhat', 'nylas.spec.in')
    writeFromTemplate(specInFilePath, templateData)

    // This populates nylas.desktop
    const desktopInFilePath = path.join(linuxAssetsDir, 'nylas-mail.desktop.in')
    writeFromTemplate(desktopInFilePath, templateData)

    const cmd = path.join('script', 'mkrpm')
    const args = [outputDir, contentsDir, linuxAssetsDir]
    spawn({cmd, args}, (error) => {
      if (error) {
        return done(error);
      }
      grunt.log.ok(`Created rpm package in ${rpmDir}`);
      return done();
    });
  });

  grunt.registerTask('create-deb-installer', 'Create debian package', function mkdebf() {
    const done = this.async()
    if (!arch) {
      done(`Unsupported arch ${process.arch}`);
      return;
    }

    getInstalledSize(contentsDir, (error, installedSize) => {
      if (error) {
        done(error);
        return;
      }

      const version = grunt.config('appJSON').version;
      const data = {
        version: version,
        name: grunt.config('appJSON').name,
        description: grunt.config('appJSON').description,
        productName: grunt.config('appJSON').productName,
        linuxShareDir: '/usr/share/nylas-mail',
        arch: arch,
        section: 'devel',
        maintainer: 'Nylas Team <support@nylas.com>',
        installedSize: installedSize,
      }
      writeFromTemplate(path.join(linuxAssetsDir, 'debian', 'control.in'), data)
      writeFromTemplate(path.join(linuxAssetsDir, 'nylas-mail.desktop.in'), data)

      const icon = path.join('build', 'resources', 'nylas.png')
      const cmd = path.join('script', 'mkdeb');
      const args = [version, arch, icon, linuxAssetsDir, contentsDir, outputDir];
      spawn({cmd, args}, (spawnError) => {
        if (spawnError) {
          return done(spawnError);
        }
        grunt.log.ok(`Created ${outputDir}/nylas-${version}-${arch}.deb`);
        return done()
      });
    });
  });
}
