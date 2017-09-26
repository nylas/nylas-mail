const originalLog = console.log;
const originalWarn = console.warn;
const originalError = console.error;

export default class ConsoleReporter {
  reportSpecStarting(spec) {
    const withContext = log => {
      return (...args) => {
        if (args[0] === '.') {
          return log(...args);
        }
        return log(`[${spec.getFullName()}] ${args[0]}`, ...args.slice(1));
      };
    };
    console.log = withContext(originalLog);
    console.warn = withContext(originalWarn);
    console.error = withContext(originalError);
  }

  reportSpecResults() {
    if (console.log !== originalLog) {
      console.log = originalLog;
    }
    if (console.warn !== originalWarn) {
      console.warn = originalWarn;
    }
    if (console.error !== originalError) {
      console.error = originalError;
    }
  }
}
