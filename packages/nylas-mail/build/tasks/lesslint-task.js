module.exports = (grunt) => {
  grunt.config.merge({
    lesslint: {
      src: [
        'internal_packages/**/*.less',
        'dot-nylas/**/*.less',
        'static/**/*.less',
      ],
      options: {
        less: {
          paths: ['static', 'static/variables/'],
        },
        imports: ['static/variables/*.less'],
      },
    },
  });

  grunt.loadNpmTasks('grunt-contrib-less');
  grunt.loadNpmTasks('grunt-lesslint');
}
