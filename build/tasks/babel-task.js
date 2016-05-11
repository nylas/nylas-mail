// Copied from https://github.com/babel/grunt-babel to ensure we always
// use the `babel-core` defined in our own package.json as opposed to the
// grunt-babel dependency's
module.exports = function (grunt) {
  grunt.registerMultiTask('babel', 'Use next generation JavaScript, today', function () {
    var path = require('path');
    var babel = require('babel-core');
    var options = this.options();

    this.files.forEach(function (el) {
      delete options.filename;
      delete options.filenameRelative;

      options.sourceFileName = path.relative(path.dirname(el.dest), el.src[0]);

      if (process.platform === 'win32') {
        options.sourceFileName = options.sourceFileName.replace(/\\/g, '/');
      }

      options.sourceMapTarget = path.basename(el.dest);

      var res = babel.transformFileSync(el.src[0], options);
      var sourceMappingURL = '';

      if (res.map) {
        sourceMappingURL = '\n//# sourceMappingURL=' + path.basename(el.dest) + '.map';
      }

      grunt.file.write(el.dest, res.code + sourceMappingURL + '\n');

      if (res.map) {
        grunt.file.write(el.dest + '.map', JSON.stringify(res.map));
      }
    });
  });
};
