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

      errors = []

      esExport = {}
      esNoExport = {}
      esExportDefault = {}

      for f in fileset.src
        continue if not esExtensions[path.extname(f)]
        lookupPath = "#{path.dirname(f)}/#{path.basename(f, path.extname(f))}"

        content = fs.readFileSync(f, encoding:'utf8')
        if /module.exports\s?=\s?.+/gmi.test(content)
          errors.push("#{f}: Don't use module.exports in ES6")

        if /^export/gmi.test(content)
          if /^export\ default/gmi.test(content)
            esExportDefault[lookupPath] = true
          else
            esExport[lookupPath] = true
        else
          esNoExport[lookupPath] = true

      # blacklist = ["events", "main", "package", "task"]
      # for item in blacklist
      #   delete esExportDefault[item]
      #   delete esExport[item]
      #   delete esNoExport[item]

      # file.src is the list of all matching file names.
      for f in fileset.src
        continue if esExtensions[path.extname(f)]
        content = fs.readFileSync(f, encoding:'utf8')
        if extensionRegex.test(content)
          errors.push("#{f}: Remove require extension!")

        requireRe = /require[ (]['"]([\w_./-]*?)['"]/gmi
        while result = requireRe.exec(content)
          i = 1
          while i < result.length
            requirePath = result[i]
            i += 1

            if requirePath[0] is "."
              lookupPath = path.normalize(path.join(path.dirname(f), requirePath))
            else
              lookupPath = requirePath

            baseRequirePath = path.basename(requirePath)

            plainRequireRe = new RegExp("require[ (]['\"].*#{baseRequirePath}['\"]\\)?$","gm")
            defaultRequireRe = new RegExp("require\\(['\"].*#{baseRequirePath}['\"]\\)\\.default","gm")

            if esExport[lookupPath]
              if not plainRequireRe.test(content)
                errors.push("#{f}: ES6 no `default` exported #{requirePath}")

            else if esNoExport[lookupPath]
              errors.push("#{f}: nothing exported from #{requirePath}")

            else if esExportDefault[lookupPath]
              if not defaultRequireRe.test(content)
                errors.push("#{f}: ES6 add `default` to require #{requirePath}")

            else
              # must be a coffeescript or core file
              if defaultRequireRe.test(content)
                errors.push("#{f}: don't ask for `default` from #{requirePath}")

      if errors.length > 0
        grunt.log.error(err) for err in errors
        done(new Error("Please fix the #{errors.length} linter errors! Since we compile files in production to plain `.js` files it's very important you do NOT include the file extension when `require`ing a file. Also, as of Babel 6, `require` no longer returns whatever the `default` value is. If you are `require`ing an es6 file from a coffeescript file, you must explicitly request the `default` property. For example: do `require('./my-es6-file').default`"))

    done(null)
