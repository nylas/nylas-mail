const childProcess = require('child_process')

export async function spawn(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    const env = Object.assign({}, process.env, opts.env || {})
    delete opts.env
    const options = Object.assign({env}, opts);
    const proc = childProcess.spawn(cmd, args, options)
    let stdout = ''
    let stderr = ''
    proc.stdout.on("data", (data) => {
      stdout += data
    })
    proc.stderr.on("data", (data) => {
      stderr += data
    })
    proc.on("error", reject)
    proc.on("exit", () => resolve({stdout, stderr}))
  })
}

export function exec(cmd, opts = {}) {
  return new Promise((resolve, reject) => {
    childProcess.exec(cmd, opts, (err, stdout) => {
      if (err) {
        return reject(err)
      }
      return resolve(stdout)
    })
  })
}
