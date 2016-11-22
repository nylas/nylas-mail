module.exports = (grunt) => {
  grunt.config.merge({
    coffeelint: {
      'options': {
        configFile: 'build/config/coffeelint.json',
      },
      'src': grunt.config('source:coffeescript'),
      'build': [
        'build/tasks/**/*.coffee',
      ],
      'test': [
        'spec/**/*.cjsx',
        'spec/**/*.coffee',
      ],
      'static': [
        'static/**/*.coffee',
        'static/**/*.cjsx',
      ],
      'target': (grunt.option("target") ? grunt.option("target").split(" ") : []),
    },
  });

  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-coffeelint-cjsx');
}
