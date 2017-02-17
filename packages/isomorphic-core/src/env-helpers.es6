
export function isClientEnv() {
  return typeof window !== 'undefined' && typeof window.NylasEnv !== 'undefined'
}

export function isCloudEnv() {
  return !isClientEnv()
}
