const path = require('path');
const createDMG = require('electron-installer-dmg');

module.exports = grunt => {
  grunt.registerTask('create-mac-dmg', 'Create DMG for Mailspring', function pack() {
    const done = this.async();
    const dmgPath = path.join(grunt.config('outputDir'), 'Mailspring.dmg');
    createDMG(
      {
        appPath: path.join(grunt.config('outputDir'), 'Mailspring-darwin-x64', 'Mailspring.app'),
        name: 'Mailspring',
        background: path.resolve(
          grunt.config('appDir'),
          'build',
          'resources',
          'mac',
          'DMG-background.png'
        ),
        icon: path.resolve(grunt.config('appDir'), 'build', 'resources', 'mac', 'mailspring.icns'),
        overwrite: true,
        out: grunt.config('outputDir'),
      },
      err => {
        if (err) {
          done(err);
          return;
        }

        grunt.log.writeln(`>> Created ${dmgPath}`);
        done(null);
      }
    );
  });
};
