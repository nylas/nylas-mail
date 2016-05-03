path = require 'path'
fs = require 'fs-plus'

module.exports = (grunt) ->
  grunt.registerMultiTask 'nylaslint', 'Check requires for file extensions compiled away', ->
    done = @async()
    extensionRegex = /require ['"].*\.(coffee|cjsx|jsx|es6|es)['"]/i

    for fileset in @files
      grunt.log.writeln('Nylinting ' + fileset.src.length + ' files.')

      esExtensions = {
        ".es6": true
        ".es": true
        ".jsx": true
      }
      coffeeExtensions = {
        ".coffee": true
        ".cjsx": true
      }

      esSet = {}
      for f in fileset.src
        if esExtensions[path.extname(f)]
          esSet[path.basename(f, path.extname(f))] = true

      errors = []

      # file.src is the list of all matching file names.
      for f in fileset.src
        continue if esExtensions[path.extname(f)]
        content = fs.readFileSync(f, encoding:'utf8')
        if extensionRegex.test(content)
          errors.push("#{f}: Remove require extension!")

        requireRe = /require[\s()]['"](.*)['"]/gmi
        while result = requireRe.exec(content)
          i = 1
          while i < result.length
            requirePath = result[i]
            i += 1
            baseRequirePath = path.basename(requirePath)
            if esSet[baseRequirePath]
              testForPath = new RegExp("require\\(['\"].*#{baseRequirePath}['\"]\\)\\.","gm")
              if not testForPath.test(content)
                errors.push("#{f}: ES6 add `default` to require #{requirePath}")

      if errors.length > 0
        grunt.log.error(err) for err in errors
        done(new Error("Please fix the linter errors! Since we compile files in production to plain `.js` files it's very important you do NOT include the file extension when `require`ing a file. Also, as of Babel 6, `require` no longer returns whatever the `default` value is. If you are `require`ing an es6 file from a coffeescript file, you must explicitly request the `default` property. For example: do `require('./my-es6-file').default`"))

    done(null)
