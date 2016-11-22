/* eslint prefer-template: 0 */
/* eslint global-require: 0 */
/* eslint quote-props: 0 */
const path = require('path');

module.exports = (grunt) => {
  const {spawn} = require('./task-helpers')(grunt);

  grunt.registerTask('create-mac-installer', 'Zip up N1', function pack() {
    const done = this.async();
    const zipPath = path.join(grunt.config('outputDir'), 'N1.zip');

    if (grunt.file.exists(zipPath)) {
      grunt.file.delete(zipPath, {force: true});
    }

    const orig = process.cwd();
    process.chdir(path.join(grunt.config('outputDir'), 'Nylas N1-darwin-x64'));

    spawn({
      cmd: "zip",
      args: ["-9", "-y", "-r", "-9", "-X", zipPath, 'Nylas N1.app'],
    }, (error) => {
      process.chdir(orig);

      if (error) {
        done(error);
        return;
      }

      grunt.log.writeln(`>> Created ${zipPath}`);
      done(null);
    });
  });
};
