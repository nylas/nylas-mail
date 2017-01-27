const path = require('path');
const cjsxtransform = require('coffee-react-transform');
const rimraf = require('rimraf');

const fs = require('fs-plus');
const _ = require('underscore');

const donna = require('donna');
const joanna = require('joanna');
const tello = require('tello');

module.exports = function(grunt) {

  let {cp, mkdir, rm} = require('./task-helpers')(grunt);

  let getClassesToInclude = function() {
    let modulesPath = path.resolve(__dirname, '..', '..', 'internal_packages');
    let classes = {};
    fs.traverseTreeSync(modulesPath, function(modulePath) {
      // Don't traverse inside dependencies
      if (modulePath.match(/node_modules/g)) { return false; }

      // Don't traverse blacklisted packages (that have docs, but we don't want to include)
      if (path.basename(modulePath) !== 'package.json') { return true; }
      if (!fs.isFileSync(modulePath)) { return true; }

      let apiPath = path.join(path.dirname(modulePath), 'api.json');
      if (fs.isFileSync(apiPath)) {
        _.extend(classes, grunt.file.readJSON(apiPath).classes);
      }
      return true;
    });
    return classes;
  };

  let sortClasses = function(classes) {
    let sortedClasses = {};
    for (let className of Array.from(Object.keys(classes).sort())) {
      sortedClasses[className] = classes[className];
    }
    return sortedClasses;
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

  return grunt.registerTask('docs', 'Builds the API docs in src', function() {

     grunt.log.writeln("Time to build the docs!")

    let done = this.async();

    // Convert CJSX into coffeescript that can be read by Donna

    // let classDocsOutputDir = grunt.config.get('classDocsOutputDir');

    let classDocsOutputDir = '~/Desktop/Nylas Mail Docs/'
    let cjsxOutputDir = path.join(classDocsOutputDir, 'temp-cjsx');

    return rimraf(cjsxOutputDir, function() {
      let api;
      fs.mkdir(cjsxOutputDir);

      let srcPath = path.resolve(__dirname, '..', '..', 'src');

      fs.traverseTreeSync(srcPath, function(file) {

        if (file.indexOf('/K2/') > 0) {
          // Skip K2
        }
        else if (path.extname(file) === '.cjsx') {  // Should also look for jsx and es6
          let transformed = cjsxtransform(grunt.file.read(file));

          // Only attempt to parse this file as documentation if it contains
          // real Coffeescript classes.
          if (transformed.indexOf('\nclass ') > 0) {

            grunt.log.writeln("Found class in file: " + file)

            grunt.file.write(path.join(cjsxOutputDir, path.basename(file).slice(0, -5 + 1 || undefined)+'coffee'), transformed);
          }
        }
        else if (path.extname(file) === '.jsx') {
          console.log('Transforming ' + file)

          let fileStr = grunt.file.read(file);

          let transformed = require("babel-core").transform(fileStr, {
            plugins: ["transform-react-jsx",
                      "transform-class-properties"],
            presets: ['react', 'stage-2']
          });


          if (transformed.code.indexOf('class ') > 0) {
            grunt.log.writeln("Found class in file: " + file)

            grunt.file.write(path.join(cjsxOutputDir, path.basename(file).slice(0, -3 || undefined)+'js'), transformed.code);
          }
        }
        return true;
      });

      grunt.log.ok('Done transforming, starting donna extraction')
      grunt.log.writeln('cjsxOutputDir: ' + cjsxOutputDir)

      // Process coffeescript source
      let metadata = donna.generateMetadata([cjsxOutputDir]);
      grunt.log.ok('---- Done with Donna (cjsx metadata)----');

      console.log(js_files);

      var js_files = []
      fs.traverseTreeSync(cjsxOutputDir, function(file) {
        if (path.extname(file) === '.js') {
          js_files.push(file.toString())
        }
      });

      console.log(js_files);
      let jsx_metadata = joanna(js_files);
      grunt.log.ok('---- Done with Joanna (jsx metadata)----');

      Object.assign(metadata, jsx_metadata);

      console.log(metadata);

      try {
        api = tello.digest(metadata);
      } catch (e) {
        console.log(e.stack);
      }

      console.log('---- Done with Tello ----');
      _.extend(api.classes, getClassesToInclude());
      api.classes = sortClasses(api.classes);

      let apiJson = JSON.stringify(api, null, 2);
      let apiJsonPath = path.join(classDocsOutputDir, 'api.json');
      grunt.file.write(apiJsonPath, apiJson);
      return done();
    });
  });


};
