const childProcess = require('child_process');

module.exports = grunt => {
  function spawn(options, callback) {
    const stdout = [];
    const stderr = [];
    let error = null;
    const proc = childProcess.spawn(options.cmd, options.args, options.opts);
    proc.stdout.on('data', data => stdout.push(data.toString()));
    proc.stderr.on('data', data => stderr.push(data.toString()));
    proc.on('error', processError => {
      return error != null ? error : (error = processError);
    });
    proc.on('close', (exitCode, signal) => {
      if (exitCode !== 0) {
        if (typeof error === 'undefined' || error === null) {
          error = new Error(signal);
        }
      }
      const results = { stderr: stderr.join(''), stdout: stdout.join(''), code: exitCode };
      if (exitCode !== 0) {
        grunt.log.error(results.stderr);
      }
      return callback(error, results, exitCode);
    });
  }

  function spawnP(options) {
    return new Promise((resolve, reject) => {
      spawn(options, error => {
        if (error) return reject(error);
        return resolve();
      });
    });
  }

  return { spawn, spawnP };
};
