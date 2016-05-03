// Copied from https://github.com/babel/grunt-babel to ensure we always
// use the `babel-core` defined in our own package.json as opposed to the
// grunt-babel dependency's

const path = require('path');
const babel = require('babel-core');

module.exports = function babelTask(grunt) {
  grunt.registerMultiTask('babel', 'Use next generation JavaScript, today', () => {
    const options = this.options();

    this.files.forEach((el) => {
      delete options.filename;
      delete options.filenameRelative;

      options.sourceFileName = path.relative(path.dirname(el.dest), el.src[0]);

      if (process.platform === 'win32') {
        options.sourceFileName = options.sourceFileName.replace(/\\/g, '/');
      }

      options.sourceMapTarget = path.basename(el.dest);

      const res = babel.transformFileSync(el.src[0], options);
      let sourceMappingURL = '';

      if (res.map) {
        sourceMappingURL = `\n//# sourceMappingURL=${path.basename(el.dest)}.map`;
      }

      grunt.file.write(el.dest, `${res.code}${sourceMappingURL}\n`);

      if (res.map) {
        grunt.file.write(`${el.dest}.map`, JSON.stringify(res.map));
      }
    });
  });
};
