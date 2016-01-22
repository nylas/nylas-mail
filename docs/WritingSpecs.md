---
Title:   Writing Specs
TitleHidden: True
Section: Guides
Order:   7
---

Nylas uses [Jasmine](http://jasmine.github.io/1.3/introduction.html) as its spec framework. As a package developer, you can write specs using Jasmine 1.3 and get some quick wins. Jasmine specs can be run in N1 directly from the Developer menu, and the test environment provides you with helpful stubs. You can also require your own test framework, or use Jasmine for integration tests and your own framework for your existing business logic.

This documentation describes using [Jasmine 1.3](http://jasmine.github.io/1.3/introduction.html) to write specs for a Nylas package.

### Running Specs

You can run your package specs from `Developer > Run Plugin Specs...`. Once you've opened the spec window, you can see output and re-run your specs by clicking `Reload Specs`.

### Writing Specs

To create specs, place `js`, `coffee`, or `cjsx` files in the `spec` directory of your package. Spec files must end with the `-spec` suffix.

Here's an annotated look at a typical Jasmine spec:

```coffee
# The `describe` method takes two arguments, a description and a function. If the description
# explains a behavior it typically begins with `when`; if it is more like a unit test it begins
# with the method name.
describe "when a test is written", ->

  # The `it` method also takes two arguments, a description and a function. Try and make the
  # description flow with the `it` method. For example, a description of `this should work`
  # doesn't read well as `it this should work`. But a description of `should work` sounds
  # great as `it should work`.
  it "has some expectations that should pass", ->

	# The best way to learn about expectations is to read the Jasmine documentation:
	# http://jasmine.github.io/1.3/introduction.html#section-Expectations
    # Below is a simple example.

	expect("apples").toEqual("apples")
    expect("oranges").not.toEqual("apples")

describe "Editor::moveUp", ->
	...

```

#### Asynchronous Spcs

Writing Asynchronous specs can be tricky at first, but a combination of spec helpers can make things easy. Here are a few quick examples:

##### Promises

You can use the global `waitsForPromise` function to make sure that the test does not complete until the returned promise has finished, and run your expectations in a chained promise.

```coffee
  describe "when requesting a Draft Session", ->
    it "a session with the correct ID is returned", ->
      waitsForPromise ->
        DraftStore.sessionForLocalId('123').then (session) ->
          expect(session.id).toBe('123')
```

This method can be used in the `describe`, `it`, `beforeEach` and `afterEach` functions.

```coffee
describe "when we open a file", ->
  beforeEach ->
    waitsForPromise ->
      NylasEnv.workspace.open 'c.coffee'

  it "should be opened in an editor", ->
    expect(NylasEnv.workspace.getActiveTextEditor().getPath()).toContain 'c.coffee'

```

If you need to wait for multiple promises use a new `waitsForPromise` function for each promise. (Caution: Without `beforeEach` this example will fail!)

```coffee
describe "waiting for the packages to load", ->

  beforeEach ->
    waitsForPromise ->
      NylasEnv.workspace.open('sample.js')
    waitsForPromise ->
      NylasEnv.packages.activatePackage('tabs')
    waitsForPromise ->
      NylasEnv.packages.activatePackage('tree-view')

  it 'should have waited long enough', ->
    expect(NylasEnv.packages.isPackageActive('tabs')).toBe true
    expect(NylasEnv.packages.isPackageActive('tree-view')).toBe true
```

#### Asynchronous functions with callbacks

Specs for asynchronous functions can be done using the `waitsFor` and `runs` functions. A simple example.

```coffee
describe "fs.readdir(path, cb)", ->
  it "is async", ->
    spy = jasmine.createSpy('fs.readdirSpy')

    fs.readdir('/tmp/example', spy)
    waitsFor ->
      spy.callCount > 0
    runs ->
      exp = [null, ['example.coffee']]
      expect(spy.mostRecentCall.args).toEqual exp
      expect(spy).toHaveBeenCalledWith(null, ['example.coffee'])
```

For a more detailed documentation on asynchronous tests please visit the [Jasmine documentation](http://jasmine.github.io/1.3/introduction.html#section-Asynchronous_Support).


#### Tips for Debugging Specs

To run a limited subset of specs use the `fdescribe` or `fit` methods. You can use those to focus a single spec or several specs. In the example above, focusing an individual spec looks like this:

```coffee
describe "when a test is written", ->
  fit "has some expectations that should pass", ->
    expect("apples").toEqual("apples")
    expect("oranges").not.toEqual("apples")
```
