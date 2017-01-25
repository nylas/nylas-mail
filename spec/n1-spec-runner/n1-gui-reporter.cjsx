path = require 'path'
_ = require 'underscore'
_str = require 'underscore.string'
{convertStackTrace} = require 'coffeestack'
React = require 'react'
ReactDOM = require 'react-dom'
marked = require 'marked'

sourceMaps = {}
formatStackTrace = (spec, message='', stackTrace, indent="") ->
  return stackTrace unless stackTrace

  jasminePattern = /^\s*at\s+.*\(?.*[/\\]jasmine(-[^/\\]*)?\.js:\d+:\d+\)?\s*$/
  firstJasmineLinePattern = /^\s*at [/\\].*[/\\]jasmine(-[^/\\]*)?\.js:\d+:\d+\)?\s*$/
  convertedLines = []
  for line in stackTrace.split('\n')
    convertedLines.push(line) unless jasminePattern.test(line)
    break if firstJasmineLinePattern.test(line)

  stackTrace = convertStackTrace(convertedLines.join('\n'), sourceMaps)
  lines = stackTrace.split('\n')

  # Remove first line of stack when it is the same as the error message
  errorMatch = lines[0]?.match(/^Error: (.*)/)
  lines.shift() if message.trim() is errorMatch?[1]?.trim()

  for line, index in lines
    # Remove prefix of lines matching: at [object Object].<anonymous> (path:1:2)
    prefixMatch = line.match(/at \[object Object\]\.<anonymous> \(([^)]+)\)/)
    line = "at #{prefixMatch[1]}" if prefixMatch

    # Relativize locations to spec directory
    lines[index] = line.replace("at #{spec.specDirectory}#{path.sep}", 'at ')

  lines = lines.map (line) -> indent + line.trim()
  lines.join('\n')


indentationString: (suite, plus=0) ->
  rootSuite = suite
  indentLevel = 0 + plus
  while rootSuite.parentSuite
    rootSuite = rootSuite.parentSuite
    indentLevel += 1
  return [0...indentLevel].map(-> "  ").join("")


suiteString: (spec) ->
  descriptions = [spec.suite.description]

  rootSuite = spec.suite
  while rootSuite.parentSuite
    indent = indentationString(rootSuite)
    descriptions.unshift(indent + rootSuite.description)
    rootSuite = rootSuite.parentSuite

  descriptions.join("\n")


class N1GuiReporter extends React.Component
  constructor: (@props) ->

  render: ->
    <div className="spec-reporter">
      <div className="padded pull-right">
        <button className="btn reload-button" onClick={@onReloadSpecs}>Reload Specs</button>
      </div>
      <div className="symbol-area">
        <div className="symbol-header">Core</div>
        <div className="symbol-summary list-unstyled">{@_renderSpecsOfType('core')}</div>
      </div>
      <div className="symbol-area">
        <div className="symbol-header">Bundled</div>
        <div className="symbol-summary list-unstyled">{@_renderSpecsOfType('bundled')}</div>
      </div>
      <div className="symbol-area">
        <div className="symbol-header">User</div>
        <div className="symbol-summary list-unstyled">{@_renderSpecsOfType('user')}</div>
      </div>
      {@_renderStatus()}
      <div className="results">
        {@_renderFailures()}
      </div>
      <div className="plain-text-output">
        {@props.plainTextOutput}
      </div>
    </div>

  _renderSpecsOfType: (type) =>
    items = []
    @props.specs.forEach (spec, idx) =>
      return unless spec.specType is type
      statusClass = "pending"
      title = undefined
      results = spec.results()
      if results
        if results.skipped
          statusClass = "skipped"
        else if results.failedCount > 0
          statusClass = "failed"
          title = spec.getFullName()
        else if spec.endedAt
          statusClass = "passed"

      items.push <li key={idx} title={title} className="spec-summary #{statusClass}"/>

    items

  _renderFailures: =>
    # We have an array of specs with `suite` and potentially N `parentSuite` from there.
    # Create a tree instead.
    topLevelSuites = []

    failedSpecs = @props.specs.filter (spec) ->
      spec.endedAt and spec.results().failedCount > 0

    for spec in failedSpecs
      suite = spec.suite
      suite = suite.parentSuite while suite.parentSuite
      if topLevelSuites.indexOf(suite) is -1
        topLevelSuites.push(suite)

    topLevelSuites.map (suite, idx) =>
      <SuiteResultView suite={suite} key={idx} allSpecs={failedSpecs} />

  _renderStatus: =>
    failedCount = 0
    skippedCount = 0
    completeCount = 0
    for spec in @props.specs
      results = spec.results()
      continue unless spec.endedAt
      failedCount += 1 if results.failedCount > 0
      skippedCount += 1 if results.skipped
      completeCount += 1 if results.passedCount > 0 and results.failedCount is 0

    if failedCount is 1
      message = "#{failedCount} failure"
    else
      message = "#{failedCount} failures"

    if skippedCount
      specCount = "#{completeCount - skippedCount}/#{@props.specs.length - skippedCount} (#{skippedCount} skipped)"
    else
      specCount = "#{completeCount}/#{@props.specs.length}"

    <div className="status alert alert-info">
      <div className="time"></div>
      <div className="spec-count">{specCount}</div>
      <div className="message">{message}</div>
    </div>

  onReloadSpecs: =>
    require('electron').remote.getCurrentWindow().reload()


class SuiteResultView extends React.Component
  @propTypes: ->
    suite: React.PropTypes.object
    allSpecs: React.PropTypes.array

  render: ->
    items = []
    subsuites = []

    @props.allSpecs.forEach (spec) =>
      if spec.suite is @props.suite
        items.push(spec)
      else
        suite = spec.suite
        while suite.parentSuite
          if suite.parentSuite is @props.suite
            subsuites.push(suite)
            return
          suite = suite.parentSuite

    items = items.map (spec, idx) =>
      <SpecResultView key={idx} spec={spec} />

    subsuites = subsuites.map (suite, idx) =>
      <SuiteResultView key={idx} suite={suite} allSpecs={@props.allSpecs} />

    <div className="suite">
      <div className="description">{@props.suite.description}</div>
      <div className="results">
        {items}
        {subsuites}
      </div>
    </div>

class SpecResultView extends React.Component
  @propTypes: ->
    spec: React.PropTypes.object

  render: ->
    description = @props.spec.description
    resultItems = @props.spec.results().getItems()
    description = "it #{description}" if description.indexOf('it ') isnt 0

    failures = []
    for result, idx in resultItems
      continue if result.passed()
      stackTrace = formatStackTrace(@props.spec, result.message, result.trace.stack)
      failures.push(
        <div key={idx}>
          <div className="result-message fail">{result.message}</div>
          <div className="stack-trace padded">{stackTrace}</div>
        </div>
      )

    <div className="spec">
      <div className="description">{description}</div>
      <div className="spec-failures">{failures}</div>
    </div>



el = document.createElement('div')
document.body.appendChild(el)

startedAt = null
specs = []
plainTextOutput = ""

update = =>
  component = <N1GuiReporter
    startedAt={startedAt}
    specs={specs}
  />
  ReactDOM.render(component, el)

updateSoon = _.debounce(update, 125)

module.exports =
  reportRunnerStarting: (runner) ->
    specs = runner.specs()
    startedAt = Date.now()
    updateSoon()

  reportRunnerResults: (runner) ->
    updateSoon()

  reportSuiteResults: (suite) ->

  reportSpecResults: (spec) ->
    spec.endedAt = Date.now()
    updateSoon()

  reportPlainTextSpecResult: (spec) ->
    str = ""
    if spec.results().failedCount > 0
      str += suiteString(spec) + "\n"
      indent = indentationString(spec.suite, 1)
      stackIndent = indentationString(spec.suite, 2)

      description = spec.description
      description = "it #{description}" if description.indexOf('it ') isnt 0
      str += indent + description + "\n"

      for result in spec.results().getItems()
        continue if result.passed()
        str += indent + result.message + "\n"
        stackTrace = formatStackTrace(spec, result.message, result.trace.stack, stackIndent)
        str += stackTrace + "\n"
      str += "\n\n"

    plainTextOutput = plainTextOutput + str
    updateSoon()

  reportSpecStarting: (spec) ->
    updateSoon()
