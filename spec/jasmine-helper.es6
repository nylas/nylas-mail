import { remote } from 'electron';
import jasmineExports from './jasmine';
import {TerminalReporter} from 'jasmine-tagged';
import TimeReporter from './time-reporter'
import N1SpecReporter from './n1-spec-reporter';

export function runSpecSuite(specSuite) {
  for (const key of Object.keys(jasmineExports)) {
    window[key] = jasmineExports[key]
  }

  const timeReporter = new TimeReporter();

  const log = (str) => {
    return remote.process.stdout.write(str);
  };

  let reporter = new TerminalReporter({
    color: true,
    print(str) {
      return log(str);
    },
    onComplete(runner) {
      if (runner.results().failedCount > 0) {
        return NylasEnv.exit(1);
      }
      return NylasEnv.exit(0);
    },
  });

  if (NylasEnv.getLoadSettings().showSpecsInWindow) {
    reporter = N1SpecReporter
  }

  NylasEnv.initialize();

  require(specSuite);

  const jasmineEnv = jasmineExports.jasmine.getEnv();
  jasmineEnv.addReporter(reporter);
  jasmineEnv.addReporter(timeReporter);

  const div = document.createElement('div');
  div.id = 'jasmine-content';
  document.body.appendChild(div);

  return jasmineEnv.execute();
}
