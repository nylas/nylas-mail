_ = require('underscore')
fs = require('fs')
path = require 'path'
QuotedHTMLParser = require('../src/services/quoted-html-parser')

describe "QuotedHTMLParser", ->

  readFile = (fname) ->
    emailPath = path.resolve(__dirname, 'fixtures', 'emails', fname)
    return fs.readFileSync(emailPath, 'utf8')

  hideQuotedHTML = (fname) ->
    return QuotedHTMLParser.hideQuotedHTML(readFile(fname))

  removeQuotedHTML = (fname) ->
    return QuotedHTMLParser.removeQuotedHTML(readFile(fname))

  numQuotes = (html) ->
    re = new RegExp(QuotedHTMLParser.annotationClass, 'g')
    html.match(re)?.length ? 0

  [1..15].forEach (n) ->
    it "properly parses email_#{n}", ->
      expect(removeQuotedHTML("email_#{n}.html")).toEqual readFile("email_#{n}_stripped.html")



  # We have a little utility method that you can manually uncomment to
  # generate what the current iteration of the QuotedHTMLParser things the
  # `removeQuotedHTML` should look like. These can be manually inspected in
  # a browser before getting their filename changed to
  # `email_#{n}_stripped.html". The actually tests will run the current
  # iteration of the `removeQuotedHTML` against these files to catch if
  # anything has changed in the parser.
  #
  # It's inside of the specs here instaed of its own script because the
  # `QuotedHTMLParser` needs Electron booted up in order to work because
  # of the DOMParser.
  xit "Run this simple funciton to generate output files", ->
    [1..15].forEach (n) ->
      newHTML = QuotedHTMLParser.removeQuotedHTML(readFile("email_#{n}.html"))
      outPath = path.resolve(__dirname, 'fixtures', 'emails', "email_#{n}_raw_stripped.html")
      fs.writeFileSync(outPath, newHTML)
