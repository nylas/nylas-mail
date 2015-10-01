path = require 'path'
Handlebars = require 'handlebars'
marked = require 'meta-marked'
fs = require 'fs-plus'
_ = require 'underscore'

marked.setOptions
  highlight: (code) ->
    require('highlight.js').highlightAuto(code).value

standardClassURLRoot = 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/'

standardClasses = [
  'string',
  'object',
  'array',
  'function',
  'number',
  'date',
  'error',
  'boolean',
  'null',
  'undefined',
  'json',
  'set',
  'map',
  'typeerror',
  'syntaxerror',
  'referenceerror',
  'rangeerror'
]

thirdPartyClasses = {
  'react.component': 'https://facebook.github.io/react/docs/component-api.html',
  'promise': 'https://github.com/petkaantonov/bluebird/blob/master/API.md',
  'range': 'https://developer.mozilla.org/en-US/docs/Web/API/Range',
  'selection': 'https://developer.mozilla.org/en-US/docs/Web/API/Selection',
  'node': 'https://developer.mozilla.org/en-US/docs/Web/API/Node',
}

module.exports = (grunt) ->

  {cp, mkdir, rm} = require('./task-helpers')(grunt)

  relativePathForGuide = (filename) ->
    '/guides/'+filename[0..-4]+'.html'

  relativePathForClass = (classname) ->
    '/docs/'+classname+'.html'

  outputPathFor = (relativePath) ->
    docsOutputDir = grunt.config.get('docsOutputDir')
    path.join(docsOutputDir, relativePath)

  processFields = (json, fields = [], tasks = []) ->
    if json instanceof Array
      for val in json
        processFields(val, fields, tasks)
    else
      for key, val of json
        if key in fields
          for task in tasks
            val = task(val)
          json[key] = val
        if _.isObject(val)
          processFields(val, fields, tasks)

  grunt.registerTask 'render-docs', 'Builds html from the API docs', ->
    docsOutputDir = grunt.config.get('docsOutputDir')

    # Parse API reference Markdown

    classes = []
    apiJsonPath = path.join(docsOutputDir, 'api.json')
    apiJSON = JSON.parse(grunt.file.read(apiJsonPath))

    for classname, contents of apiJSON.classes
      # Parse a "@Section" out of the description if one is present
      sectionRegex = /Section: ?([\w ]*)(?:$|\n)/
      section = 'General'

      match = sectionRegex.exec(contents.description)
      if match
        contents.description = contents.description.replace(match[0], '')
        section = match[1].trim()

      # Replace superClass "React" with "React.Component". The Coffeescript Lexer
      # is so bad.
      if contents.superClass is "React"
        contents.superClass = "React.Component"

      classes.push({
        name: classname
        documentation: contents
        section: section
      })

    # Parse guide Markdown

    guides = []
    guidesPath = path.resolve(__dirname, '..', '..', 'docs', 'guides')
    fs.traverseTreeSync guidesPath, (file) ->
      if path.extname(file) is '.md'
        {html, meta} = marked(grunt.file.read(file))

        filename = path.basename(file)
        meta ||= {title: filename}
        for key, val of meta
          meta[key.toLowerCase()] = val

        guides.push({
          html: html
          meta: meta
          name: meta.title
          filename: filename
          link: relativePathForGuide(filename)
        })

    # Sort guides by the `Order` flag when present. Lower order, higher in list.
    guides.sort (a, b) ->
      (a.meta?.order ? 1000)/1 - (b.meta?.order ? 1000)/1

    # Build Sidebar metadata we can hand off to each of the templates to
    # generate the sidebar
    sidebar = {sections: []}
    sidebar.sections.push
      name: 'Getting Started'
      items: guides.filter ({meta}) -> meta.section is 'Getting Started'

    sidebar.sections.push
      name: 'Guides'
      items: guides.filter ({meta}) -> meta.section is 'Guides'

    sidebar.sections.push
      name: 'Sample Code'
      items: [{
        name: 'Composer Translation'
        link: 'https://github.com/nylas/edgehill-plugins/tree/master/translate'
        external: true
        },{
        name: 'Github Sidebar'
        link: 'https://github.com/nylas/edgehill-plugins/tree/master/sidebar-github-profile'
        external: true
        }]

    referenceSections = {}
    for klass in classes
      section = referenceSections[klass.section]
      if not section
        section = {name: klass.section, classes: []}
        referenceSections[klass.section] = section
      section.classes.push(klass)

    preferredSectionOrdering = ['General', 'Component Kit', 'Models', 'Stores', 'Database', 'Drafts', 'Atom']
    sorted = []
    for key in preferredSectionOrdering
      if referenceSections[key]
        sorted.push(referenceSections[key])
        delete referenceSections[key]
    for key, val of referenceSections
      sorted.push(val)

    sidebar.sections.push
      name: 'API Reference'
      items: sorted.map ({name, classes}) ->
        name: name
        items: classes.map ({name}) -> {name: name, link: relativePathForClass(name) }

    # Prepare to render by loading handlebars partials

    templatesPath = path.resolve(__dirname, '..', '..', 'docs', 'templates')
    grunt.file.recurse templatesPath, (abspath, root, subdir, filename) ->
      if filename[0] is '_' and path.extname(filename) is '.html'
        Handlebars.registerPartial(filename[0..-6], grunt.file.read(abspath))

    # Render Helpers

    knownClassnames = {}
    for classname, val of apiJSON.classes
      knownClassnames[classname.toLowerCase()] = val

    knownGuides = {}
    for guide in guides
      knownGuides[guide.filename.toLowerCase()] = guide

    expandTypeReferences = (val) ->
      refRegex = /{([\w.]*)}/g
      while (match = refRegex.exec(val)) isnt null
        term = match[1].toLowerCase()
        label = match[1]
        url = false
        if term in standardClasses
          url = standardClassURLRoot+term
        else if thirdPartyClasses[term]
          url = thirdPartyClasses[term]
        else if knownClassnames[term]
          url = relativePathForClass(term)
        else if knownGuides[term]
          label = knownGuides[term].meta.title
          url = relativePathForGuide(knownGuides[term].filename)
        else
          console.warn("Cannot find class named #{term}")

        if url
          val = val.replace(match[0], "<a href='#{url}'>#{label}</a>")
      val

    expandFuncReferences = (val) ->
      refRegex = /{([\w]*)?::([\w]*)}/g
      while (match = refRegex.exec(val)) isnt null
        [text, a, b] = match
        url = false
        if a and b
          url = "#{relativePathForClass(a)}##{b}"
          label = "#{a}::#{b}"
        else
          url = "##{b}"
          label = "#{b}"
        if url
          val = val.replace(text, "<a href='#{url}'>#{label}</a>")
      val

    # Copy non-documentation assets

    docsPath = path.resolve(__dirname, '..', '..', 'docs')
    assets = []
    grunt.file.recurse docsPath, (abspath, root, subdir = "", filename) ->
      if path.extname(filename) in ['.png', '.jpg', '.ico', '.css']
        return if abspath.indexOf('/output/') isnt -1
        return if abspath.indexOf('/templates/') isnt -1
        destpath = path.join(docsOutputDir, subdir, filename)
        assets.push({abspath, destpath})

    for asset in assets
      cp(asset.abspath, asset.destpath)

    pages = []
    grunt.file.recurse docsPath, (abspath, root, subdir = "", filename) ->
      if path.extname(filename) in ['.html']
        return if abspath.indexOf('/output/') isnt -1
        return if abspath.indexOf('/templates/') isnt -1
        html = fs.readFileSync(abspath)
        destpath = path.join(docsOutputDir, subdir, filename)
        pages.push({html, destpath})

    # Render Class Pages

    classTemplatePath = path.join(templatesPath, 'class.html')
    classTemplate = Handlebars.compile(grunt.file.read(classTemplatePath))

    for {name, documentation, section} in classes
      # Recursively process `description` and `type` fields to process markdown,
      # expand references to types, functions and other files.
      processFields(documentation, ['description'], [marked.noMeta, expandTypeReferences, expandFuncReferences])
      processFields(documentation, ['type'], [expandTypeReferences])

      result = classTemplate({name, documentation, section, sidebar})
      grunt.file.write(outputPathFor(relativePathForClass(name)), result)

    # Render Guide Pages

    guideTemplatePath = path.join(templatesPath, 'guide.html')
    guideTemplate = Handlebars.compile(grunt.file.read(guideTemplatePath))

    for {name, meta, html, filename} in guides
      # Process the guide content to expand references to types, functions
      for task in [expandTypeReferences, expandFuncReferences]
        html = task(html)

      result = guideTemplate({name, meta, html, sidebar})
      grunt.file.write(outputPathFor(relativePathForGuide(filename)), result)

    # Render main pages

    pageTemplatePath = path.join(templatesPath, 'page.html')
    pageTemplate = Handlebars.compile(grunt.file.read(pageTemplatePath))
    for {html, destpath} in pages
      grunt.file.write(destpath, pageTemplate({html}))

    # Remove temp cjsx output
    rm(outputPathFor("temp-cjsx"))
