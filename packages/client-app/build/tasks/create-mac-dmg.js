const path = require('path');
const createDMG = require('electron-installer-dmg')

module.exports = (grunt) => {
  grunt.registerTask('create-mac-dmg', 'Create DMG for Nylas Mail', function pack() {
    const done = this.async();
    const dmgPath = path.join(grunt.config('outputDir'), "NylasMail.dmg");
    createDMG({
      appPath: path.join(grunt.config('outputDir'), "Nylas Mail-darwin-x64", "Nylas Mail.app"),
      name: "NylasMail",
      background: path.resolve(grunt.config('appDir'), 'build', 'resources', 'mac', 'Nylas-Mail-DMG-background.png'),
      icon: path.resolve(grunt.config('appDir'), 'build', 'resources', 'mac', 'nylas.icns'),
      overwrite: true,
      out: grunt.config('outputDir'),
    }, (err) => {
      if (err) {
        done(err);
        return
      }

      grunt.log.writeln(`>> Created ${dmgPath}`);
      done(null);
    })
  });
};
