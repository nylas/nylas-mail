const path = require('path');
const Handlebars = require('handlebars');
const marked = require('meta-marked');
const fs = require('fs-plus');
const _ = require('underscore');

marked.setOptions({
  highlight(code) {
    return require('highlight.js').highlightAuto(code).value;
  }
});

let standardClassURLRoot = 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/';

let standardClasses = [
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
];

let thirdPartyClasses = {
  'react.component': 'https://facebook.github.io/react/docs/component-api.html',
  'promise': 'https://github.com/petkaantonov/bluebird/blob/master/API.md',
  'range': 'https://developer.mozilla.org/en-US/docs/Web/API/Range',
  'selection': 'https://developer.mozilla.org/en-US/docs/Web/API/Selection',
  'node': 'https://developer.mozilla.org/en-US/docs/Web/API/Node',
};

module.exports = function(grunt) {

  let {cp, mkdir, rm} = require('./task-helpers')(grunt);

  let relativePathForClass = classname => classname+'.html';

  let outputPathFor = function(relativePath) {
    let classDocsOutputDir = grunt.config.get('classDocsOutputDir');
    return path.join(classDocsOutputDir, relativePath);
  };

  var processFields = function(json, fields, tasks) {
    let val;
    if (fields == null) { fields = []; }
    if (tasks == null) { tasks = []; }
    if (json instanceof Array) {
      return (() => {
        let result = [];
        for (val of Array.from(json)) {
          result.push(processFields(val, fields, tasks));
        }
        return result;
      })();
    } else {
      return (() => {
        let result1 = [];
        for (let key in json) {
          val = json[key];
          let item;
          if (Array.from(fields).includes(key)) {
            for (let task of Array.from(tasks)) {
              val = task(val);
            }
            json[key] = val;
          }
          if (_.isObject(val)) {
            item = processFields(val, fields, tasks);
          }
          result1.push(item);
        }
        return result1;
      })();
    }
  };

  return grunt.registerTask('docs-render', 'Builds html from the API docs', function() {

    let documentation, filename, html, match, meta, name, result, section, val;
    let classDocsOutputDir = grunt.config.get('classDocsOutputDir');

    // Parse API reference Markdown

    let classes = [];
    let apiJsonPath = path.join(classDocsOutputDir, 'api.json');
    let apiJSON = JSON.parse(grunt.file.read(apiJsonPath));


    for (var classname in apiJSON.classes) {
      // Parse a "@Section" out of the description if one is present
      let contents = apiJSON.classes[classname];
      let sectionRegex = /Section: ?([\w ]*)(?:$|\n)/;
      section = 'General';

      match = sectionRegex.exec(contents.description);
      if (match) {
        contents.description = contents.description.replace(match[0], '');
        section = match[1].trim();
      }

      // Replace superClass "React" with "React.Component". The Coffeescript Lexer
      // is so bad.
      if (contents.superClass === "React") {
        contents.superClass = "React.Component";
      }

      classes.push({
        name: classname,
        documentation: contents,
        section
      });
    }


    // Build Sidebar metadata we can hand off to each of the templates to
    // generate the sidebar
    let sidebar = {};
    for (var i = 0; i < classes.length; i++) {
        var current_class = classes[i];
        console.log(current_class.name + ' ' + current_class.section)

        if (!(current_class.section in sidebar)) {
          sidebar[current_class.section] = []
        }
        sidebar[current_class.section].push(current_class.name)
    }


    // Prepare to render by loading handlebars partials
    let templatesPath = path.resolve(__dirname, '..', '..', 'build', 'docs_templates');
    grunt.file.recurse(templatesPath, function(abspath, root, subdir, filename) {
      if ((filename[0] === '_') && (path.extname(filename) === '.html')) {
        return Handlebars.registerPartial(filename, grunt.file.read(abspath));
      }
    });

    // Render Helpers

    let knownClassnames = {};
    for (classname in apiJSON.classes) {
      val = apiJSON.classes[classname];
      knownClassnames[classname.toLowerCase()] = val;
    }


    let expandTypeReferences = function(val) {
      let refRegex = /{([\w.]*)}/g;
      while ((match = refRegex.exec(val)) !== null) {
        let term = match[1].toLowerCase();
        let label = match[1];
        let url = false;
        if (Array.from(standardClasses).includes(term)) {
          url = standardClassURLRoot+term;
        } else if (thirdPartyClasses[term]) {
          url = thirdPartyClasses[term];
        } else if (knownClassnames[term]) {
          url = relativePathForClass(knownClassnames[term].name);
          grunt.log.ok("Found: " + term)
        } else {
          console.warn(`Cannot find class named ${term}`);
        }

        if (url) {
          val = val.replace(match[0], `<a href='${url}'>${label}</a>`);
        }
      }
      return val;
    };

    let expandFuncReferences = function(val) {
      let refRegex = /{([\w]*)?::([\w]*)}/g;
      while ((match = refRegex.exec(val)) !== null) {
        var label;
        let [text, a, b] = Array.from(match);
        let url = false;
        if (a && b) {
          url = `${relativePathForClass(a)}#${b}`;
          label = `${a}::${b}`;
        } else {
          url = `#${b}`;
          label = `${b}`;
        }
        if (url) {
          val = val.replace(text, `<a href='${url}'>${label}</a>`);
        }
      }
      return val;
    };

    // DEBUG Render sidebar json
    // grunt.file.write(outputPathFor('sidebar.json'), JSON.stringify(sidebar, null, 2));

    // Render Class Pages
    let classTemplatePath = path.join(templatesPath, 'class.md');
    let classTemplate = Handlebars.compile(grunt.file.read(classTemplatePath));

    for ({name, documentation, section} of Array.from(classes)) {
      // Recursively process `description` and `type` fields to process markdown,
      // expand references to types, functions and other files.
      processFields(documentation, ['description'], [expandFuncReferences]);
      processFields(documentation, ['type'], [expandTypeReferences]);

      result = classTemplate({name, documentation, section});
      grunt.file.write(outputPathFor(name + '.md'), result);
    }

    let sidebarTemplatePath = path.join(templatesPath, 'sidebar.md');
    let sidebarTemplate = Handlebars.compile(grunt.file.read(sidebarTemplatePath));

    grunt.file.write(outputPathFor('Sidebar.md'),
                     sidebarTemplate({sidebar}));


    // Remove temp cjsx output
    return fs.removeSync(outputPathFor("temp-cjsx"));
  });
};

function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}
