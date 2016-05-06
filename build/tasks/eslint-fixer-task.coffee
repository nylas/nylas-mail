fs = require('fs')

module.exports = (grunt) ->
  grunt.registerMultiTask "eslintFixer", "Fixes eslint issues", ->
    done = @async()
    for fileset in @files
      for file in fileset.src
        content = fs.readFileSync(file, encoding: "utf8")
        re1 = /(.*[^ ])=> (.*)/g
        re2 = /(.*) =>([^ ].*)/g
        eolRe = /\ +$/gm
        replacer = (fullMatch, parens, rest) ->
          return "#{parens} => #{rest}"
        newContent = content.replace(re1, replacer)
        newContent = newContent.replace(re2, replacer)
        newContent = newContent.replace(eolRe, "")
        fs.writeFileSync(file, newContent, encoding: 'utf8')
