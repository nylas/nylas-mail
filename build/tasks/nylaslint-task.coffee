path = require 'path'
fs = require 'fs-plus'

normalizeRequirePath = (requirePath, fPath) ->
  if requirePath[0] is "."
    return path.normalize(path.join(path.dirname(fPath), requirePath))
  return requirePath


module.exports = (grunt) ->
  grunt.registerMultiTask 'nylaslint', 'Check requires for file extensions compiled away', ->
    done = @async()

    # Enable once path errors are fixed.
    if process.platform is 'win32'
      done()
      return

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

      # Temp TODO. Fix spec files
      for f in fileset.src
        continue if not esExtensions[path.extname(f)]
        continue if not /-spec/.test(f)
        content = fs.readFileSync(f, encoding:'utf8')

        # https://regex101.com/r/rQ3eD0/1
        # Matches only the first describe block
        describeRe = /[\n]describe\(['"](.*?)['"], ?\(\) ?=> ?/m
        if describeRe.test(content)
          errors.push("#{f}: Spec has to start with function")
          ## NOTE: Comment me in if you want to fix these files.
          # _str = require('underscore.string')
          # replacer = (match, describeName) ->
          #   fnName = _str.camelize(describeName, true)
          #   return "\ndescribe('#{describeName}', function #{fnName}() "
          # newContent = content.replace(describeRe, replacer)
          # fs.writeFileSync(f, newContent, encoding:'utf8')

      # Build the list of ES6 files that export things and categorize
      for f in fileset.src
        continue if not esExtensions[path.extname(f)]
        lookupPath = "#{path.dirname(f)}/#{path.basename(f, path.extname(f))}"

        content = fs.readFileSync(f, encoding:'utf8')
        if /module.exports\s?=\s?.+/gmi.test(content)
          unless f.endsWith('nylas-exports.es6')
            errors.push("#{f}: Don't use module.exports in ES6")

        if /^export/gmi.test(content)
          if /^export\ default/gmi.test(content)
            esExportDefault[lookupPath] = true
          else
            esExport[lookupPath] = true
        else
          esNoExport[lookupPath] = true

      # Now look again through all ES6 files, this time to check imports
      # instead of exports.
      for f in fileset.src
        continue if not esExtensions[path.extname(f)]
        content = fs.readFileSync(f, encoding:'utf8')
        importRe = /import \{.*\} from ['"](.*?)['"]/gmi
        while result = importRe.exec(content)
          i = 1
          while i < result.length
            requirePath = result[i]
            i += 1
            lookupPath = normalizeRequirePath(requirePath, f)
            if esExportDefault[lookupPath] or esNoExport[lookupPath]
              errors.push("#{f}: Don't destructure default export #{requirePath}")

      # Now look through all coffeescript files
      # If they require things from ES6 files, ensure they're using the
      # proper syntax.
      for f in fileset.src
        continue if esExtensions[path.extname(f)]
        content = fs.readFileSync(f, encoding:'utf8')
        if extensionRegex.test(content)
          errors.push("#{f}: Remove extensions when requiring files")

        requireRe = /require[ (]['"]([\w_./-]*?)['"]/gmi
        while result = requireRe.exec(content)
          i = 1
          while i < result.length
            requirePath = result[i]
            i += 1

            lookupPath = normalizeRequirePath(requirePath, f)

            baseRequirePath = path.basename(requirePath)

            plainRequireRe = new RegExp("require[ (]['\"].*#{baseRequirePath}['\"]\\)?$","gm")
            defaultRequireRe = new RegExp("require\\(['\"].*#{baseRequirePath}['\"]\\)\\.default","gm")

            if esExport[lookupPath]
              if not plainRequireRe.test(content)
                errors.push("#{f}: No `default` exported #{requirePath}")

            else if esNoExport[lookupPath]
              errors.push("#{f}: Nothing exported from #{requirePath}")

            else if esExportDefault[lookupPath]
              if not defaultRequireRe.test(content)
                errors.push("#{f}: Add `default` to require #{requirePath}")

            else
              # must be a coffeescript or core file
              if defaultRequireRe.test(content)
                errors.push("#{f}: Don't ask for `default` from #{requirePath}")

      if errors.length > 0
        grunt.log.error(err) for err in errors
        error = """
Please fix the #{errors.length} linter errors above. These are the issues we're looking for:

ISSUES WITH COFFEESCRIPT FILES:

1. Remove extensions when requiring files:
Since we compile files in production to plain `.js` files it's very important you do NOT include the file extension when `require`ing a file.

2. Add `default` to require:
As of Babel 6, `require` no longer returns whatever the `default` value is. If you are `require`ing an es6 file from a coffeescript file, you must explicitly request the `default` property. For example: do `require('./my-es6-file').default`

3. Don't ask for `default`:
If you're requiring a coffeescript file from a coffeescript file, you will almost never need to load a `default` object. This is likely an indication you incorrectly thought you were importing an ES6 file.

ISSUES WITH ES6 FILES:

4. Don't use module.exports in ES6:
You sholudn't manually assign module.exports anymore. Use proper ES6 module syntax like `export default` or `export const FOO`.

5. Don't destructure default export:
If you're using `import {FOO} from './bar'` in ES6 files, it's important that `./bar` does NOT export a `default`. Instead, in './bar', do `export const FOO = 'foo'`

6. Spec has to start with function
Top-level `describe` blocks can no longer use the `() => {}` function syntax. This will incorrectly bind `this` to the `window` object instead of the jasmine object. The top-level `describe` block must use the `function describeName() {}` syntax
        """
        done(new Error(error))

    done(null)
