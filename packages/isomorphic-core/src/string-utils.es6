export function logTrim(...args) {
  const g = window || global || {}
  const LOG_TRIM_SIZE = process.env.LOG_TRIM_SIZE || g.LOG_TRIM_SIZE || 256;
  for (let i = 0; i < args.length; i++) {
    let str = args[i];
    if (str.length >= LOG_TRIM_SIZE) {
      str = `${str.slice(0, LOG_TRIM_SIZE / 2)}…${str.slice(str.length - LOG_TRIM_SIZE / 2, str.length)}`
    }
    args[i] = str;
  }
  console.log(...args);
}
