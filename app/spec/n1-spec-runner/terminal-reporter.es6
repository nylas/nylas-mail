import { remote } from 'electron';
import { TerminalReporter } from 'jasmine-tagged';

export default class N1TerminalReporter extends TerminalReporter {
  constructor(opts = {}) {
    const options = Object.assign(opts, {
      color: true,
      print(str) {
        return remote.process.stdout.write(str);
      },
      onComplete(runner) {
        if (runner.results().failedCount > 0) {
          return AppEnv.exit(1);
        }
        return AppEnv.exit(0);
      },
    });
    super(options);
  }
}
