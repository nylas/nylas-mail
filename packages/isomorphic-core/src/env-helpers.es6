
export function isClientEnv() {
  return typeof window !== 'undefined' && typeof window.NylasEnv !== 'undefined'
}

export function isCloudEnv() {
  return !isClientEnv()
}

export function inDevMode() {
  if (isClientEnv()) {
    return window.NylasEnv.inDevMode();
  }
  return process.env.NODE_ENV !== 'production';
}
