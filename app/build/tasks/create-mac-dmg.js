const path = require('path');
const createDMG = require('electron-installer-dmg')

module.exports = (grunt) => {
  grunt.registerTask('create-mac-dmg', 'Create DMG for Merani', function pack() {
    const done = this.async();
    const dmgPath = path.join(grunt.config('outputDir'), "Merani.dmg");
    createDMG({
      appPath: path.join(grunt.config('outputDir'), "Merani-darwin-x64", "Merani.app"),
      name: "Merani",
      background: path.resolve(grunt.config('appDir'), 'build', 'resources', 'mac', 'DMG-background.png'),
      icon: path.resolve(grunt.config('appDir'), 'build', 'resources', 'mac', 'merani.icns'),
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
