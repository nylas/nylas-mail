module.exports = grunt => {
  grunt.config.merge({
    csslint: {
      options: {
        'adjoining-classes': false,
        'duplicate-background-images': false,
        'box-model': false,
        'box-sizing': false,
        'bulletproof-font-face': false,
        'compatible-vendor-prefixes': false,
        'display-property-grouping': false,
        'fallback-colors': false,
        'font-sizes': false,
        gradients: false,
        ids: false,
        important: false,
        'known-properties': false,
        'outline-none': false,
        'overqualified-elements': false,
        'qualified-headings': false,
        'unique-headings': false,
        'universal-selector': false,
        'vendor-prefix': false,
        'duplicate-properties': false, // doesn't place nice with mixins
      },
      src: ['static/**/*.css'],
    },
  });

  grunt.loadNpmTasks('grunt-contrib-csslint');
};
