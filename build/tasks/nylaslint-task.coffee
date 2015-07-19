path = require 'path'
fs = require 'fs-plus'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerMultiTask 'nylaslint', 'Check requires for file extensions compiled away', ->
    done = @async()
    regex = /require ['"].*\.(coffee|cjsx|jsx)['"]/i

    for fileset in @files
      grunt.log.writeln('Nylinting ' + fileset.src.length + ' files.')

      # file.src is the list of all matching file names.
      for f in fileset.src
        content = fs.readFileSync(f, encoding:'utf8')
        if regex.test(content)
          done(new Error("#{f} contains a bad require including an coffee / cjsx / jsx extension. Remove the extension!"))
          return

    done(null)