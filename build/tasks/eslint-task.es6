// Copied from https://github.com/sindresorhus/grunt-eslint
// So we can use our own eslint instead of this tasks's dependency.
const chalk = require('chalk');
const eslint = require('eslint');

module.exports = function eslintTask(grunt) {
  grunt.registerMultiTask('eslint', 'Validate files with ESLint', () => {
    const opts = this.options({
      outputFile: false,
      quiet: false,
      maxWarnings: -1,
    });

    // legacy
    // TODO: remove in the future
    if (opts.config) {
      opts.configFile = opts.config;
    }
    if (opts.rulesdir) {
      opts.rulePaths = opts.rulesdir;
    }

    if (this.filesSrc.length === 0) {
      grunt.log.writeln(chalk.magenta('Could not find any files to validate.'));
      return true;
    }

    const formatter = eslint.CLIEngine.getFormatter(opts.format);

    if (!formatter) {
      grunt.warn(`Could not find formatter ${opts.format}'.`);
      return false;
    }

    const engine = new eslint.CLIEngine(opts);

    let report;
    try {
      report = engine.executeOnFiles(this.filesSrc);
    } catch (err) {
      grunt.warn(err);
      return false;
    }

    if (opts.fix) {
      eslint.CLIEngine.outputFixes(report);
    }

    let results = report.results;

    if (opts.quiet) {
      results = eslint.CLIEngine.getErrorResults(results);
    }

    const output = formatter(results);

    if (opts.outputFile) {
      grunt.file.write(opts.outputFile, output);
    } else if (output) {
      console.log(output);
    }

    const tooManyWarnings = opts.maxWarnings >= 0 && report.warningCount > opts.maxWarnings;

    if (report.errorCount === 0 && tooManyWarnings) {
      grunt.warn(`ESLint found too many warnings (maximum:${opts.maxWarnings})`);
    }

    return report.errorCount === 0;
  });
};
