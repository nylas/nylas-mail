export function trimTo(str, size) {
  const g = window || global || {}
  const TRIM_SIZE = size || process.env.TRIM_SIZE || g.TRIM_SIZE || 256;
  let trimed = str;
  if (str.length >= TRIM_SIZE) {
    trimed = `${str.slice(0, TRIM_SIZE / 2)}…${str.slice(str.length - TRIM_SIZE / 2, str.length)}`
  }
  return trimed
}
