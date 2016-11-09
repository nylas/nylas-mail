const childProcess = require('child_process');

module.exports = (grunt) => {
  return {
    spawn(options, callback) {
      const stdout = [];
      const stderr = [];
      let error = null;
      const proc = childProcess.spawn(options.cmd, options.args, options.opts);
      proc.stdout.on('data', data => stdout.push(data.toString()));
      proc.stderr.on('data', data => stderr.push(data.toString()));
      proc.on('error', (processError) => {
        return error != null ? error : (error = processError)
      });
      proc.on('close', (exitCode, signal) => {
        if (exitCode !== 0) { if (typeof error === 'undefined' || error === null) { error = new Error(signal); } }
        const results = {stderr: stderr.join(''), stdout: stdout.join(''), code: exitCode};
        if (exitCode !== 0) { grunt.log.error(results.stderr); }
        return callback(error, results, exitCode);
      });
    },

    shouldPublishBuild() {
      if (!process.env.PUBLISH_BUILD) { return false; }
      if (process.env.APPVEYOR) {
        if (process.env.APPVEYOR_PULL_REQUEST_NUMBER) {
          grunt.log.writeln("Skipping because this is a pull request");
          return false;
        }
      } else if (process.env.TRAVIS) {
        if (process.env.TRAVIS_PULL_REQUEST !== "false") {
          grunt.log.writeln("Skipping because this is a pull request");
          return false;
        }
      }
      return true;
    },
  };
}
