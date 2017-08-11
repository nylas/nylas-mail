/* eslint prefer-template: 0 */
/* eslint global-require: 0 */
/* eslint quote-props: 0 */
const path = require('path');

module.exports = (grunt) => {
  const {spawn} = grunt.config('taskHelpers')

  grunt.registerTask('create-mac-zip', 'Zip up Merani', function pack() {
    const done = this.async();
    const zipPath = path.join(grunt.config('outputDir'), 'Merani.zip');

    if (grunt.file.exists(zipPath)) {
      grunt.file.delete(zipPath, {force: true});
    }

    const orig = process.cwd();
    process.chdir(path.join(grunt.config('outputDir'), 'Merani-darwin-x64'));

    spawn({
      cmd: "zip",
      args: ["-9", "-y", "-r", "-9", "-X", zipPath, 'Merani.app'],
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
