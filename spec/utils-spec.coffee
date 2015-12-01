_ = require('underscore')
Utils = require '../src/flux/models/utils'
Thread = require '../src/flux/models/thread'
Contact = require '../src/flux/models/contact'

class Foo
  constructor: (@instanceVar) ->
  field:
    a: 1
    b: 2
  method: (@stuff) ->

class Bar extends Foo
  subMethod: (stuff) ->
    @moreStuff = stuff
    @method(stuff)

describe "modelFreeze", ->
  it "should freeze the object", ->
    o =
      a: 1
      b: 2
    Utils.modelFreeze(o)
    expect(Object.isFrozen(o)).toBe(true)

  it "should not throw an exception when nulls appear in strange places", ->
    t = new Thread(participants: [new Contact(email: 'ben@nylas.com'), null], subject: '123')
    Utils.modelFreeze(t)
    expect(Object.isFrozen(t)).toBe(true)
    expect(Object.isFrozen(t.participants[0])).toBe(true)

describe "deepClone", ->
  beforeEach ->
    @v1 = [1,2,3]
    @v2 = [4,5,6]
    @foo = new Foo(@v1)
    @bar = new Bar(@v2)
    @o2 = [
      @foo,
      {v1: @v1, v2: @v2, foo: @foo, bar: @bar, baz: "baz", fn: Foo},
      "abc"
    ]
    @o2.circular = @o2
    @o2Clone = Utils.deepClone(@o2)

  it "makes a deep clone", ->
    @v1.push(4)
    @v2.push(7)
    @foo.stuff = "stuff"
    @bar.subMethod("stuff")
    expect(@o2Clone[0].stuff).toBeUndefined()
    expect(@o2Clone[1].foo.stuff).toBeUndefined()
    expect(@o2Clone[1].bar.stuff).toBeUndefined()
    expect(@o2Clone[1].v1.length).toBe 3
    expect(@o2Clone[1].v2.length).toBe 3
    expect(@o2Clone[2]).toBe "abc"

  it "does not deep clone the prototype", ->
    @foo.field.a = "changed under the hood"
    expect(@o2Clone[0].field.a).toBe "changed under the hood"

  it "clones constructors properly", ->
    expect((new @o2Clone[1].fn) instanceof Foo).toBe true

  it "clones prototypes properly", ->
    expect(@o2Clone[1].foo instanceof Foo).toBe true
    expect(@o2Clone[1].bar instanceof Bar).toBe true

  it "can take a customizer to edit values as we clone", ->
    clone = Utils.deepClone @o2, (key, clonedValue) ->
      if key is "v2"
        clonedValue.push("custom value")
        return clonedValue
      else return clonedValue
    @v2.push(7)
    expect(clone[1].v2.length).toBe 4
    expect(clone[1].v2[3]).toBe "custom value"

# Pulled equality tests from underscore
# https://github.com/jashkenas/underscore/blob/master/test/objects.js
describe "isEqual", ->
  describe "custom behavior", ->
    it "makes functions always equal", ->
      f1 = ->
      f2 = ->
      expect(Utils.isEqual(f1, f2)).toBe false
      expect(Utils.isEqual(f1, f2, functionsAreEqual: true)).toBe true

    it "can ignore keys in objects", ->
      o1 =
        foo: "bar"
        arr: [1,2,3]
        nest: {a: "b", c: 1, ignoreMe: 5}
        ignoreMe: 123
      o2 =
        foo: "bar"
        arr: [1,2,3]
        nest: {a: "b", c: 1, ignoreMe: 10}
        ignoreMe: 456

      expect(Utils.isEqual(o1, o2)).toBe false
      expect(Utils.isEqual(o1, o2, ignoreKeys: ["ignoreMe"])).toBe true

  it "passes all underscore equality tests", ->
    First = ->
      @value = 1
    First.prototype.value = 1

    Second = ->
      @value = 1
    Second.prototype.value = 2

    ok = (val) -> expect(val).toBe true

    # Basic equality and identity comparisons.
    ok(Utils.isEqual(null, null), '`null` is equal to `null`')
    ok(Utils.isEqual(), '`undefined` is equal to `undefined`')

    ok(!Utils.isEqual(0, -0), '`0` is not equal to `-0`')
    ok(!Utils.isEqual(-0, 0), 'Commutative equality is implemented for `0` and `-0`')
    ok(!Utils.isEqual(null, undefined), '`null` is not equal to `undefined`')
    ok(!Utils.isEqual(undefined, null), 'Commutative equality is implemented for `null` and `undefined`')

    # String object and primitive comparisons.
    ok(Utils.isEqual('Curly', 'Curly'), 'Identical string primitives are equal')
    ok(Utils.isEqual(new String('Curly'), new String('Curly')), 'String objects with identical primitive values are equal')
    ok(Utils.isEqual(new String('Curly'), 'Curly'), 'String primitives and their corresponding object wrappers are equal')
    ok(Utils.isEqual('Curly', new String('Curly')), 'Commutative equality is implemented for string objects and primitives')

    ok(!Utils.isEqual('Curly', 'Larry'), 'String primitives with different values are not equal')
    ok(!Utils.isEqual(new String('Curly'), new String('Larry')), 'String objects with different primitive values are not equal')
    ok(!Utils.isEqual(new String('Curly'), {toString: -> 'Curly'}), 'String objects and objects with a custom `toString` method are not equal')

    # Number object and primitive comparisons.
    ok(Utils.isEqual(75, 75), 'Identical number primitives are equal')
    ok(Utils.isEqual(new Number(75), new Number(75)), 'Number objects with identical primitive values are equal')
    ok(Utils.isEqual(75, new Number(75)), 'Number primitives and their corresponding object wrappers are equal')
    ok(Utils.isEqual(new Number(75), 75), 'Commutative equality is implemented for number objects and primitives')
    ok(!Utils.isEqual(new Number(0), -0), '`new Number(0)` and `-0` are not equal')
    ok(!Utils.isEqual(0, new Number(-0)), 'Commutative equality is implemented for `new Number(0)` and `-0`')

    ok(!Utils.isEqual(new Number(75), new Number(63)), 'Number objects with different primitive values are not equal')
    ok(!Utils.isEqual(new Number(63), {valueOf: -> 63 }), 'Number objects and objects with a `valueOf` method are not equal')

    # Comparisons involving `NaN`.
    ok(Utils.isEqual(NaN, NaN), '`NaN` is equal to `NaN`')
    ok(Utils.isEqual(new Object(NaN), NaN), 'Object(`NaN`) is equal to `NaN`')
    ok(!Utils.isEqual(61, NaN), 'A number primitive is not equal to `NaN`')
    ok(!Utils.isEqual(new Number(79), NaN), 'A number object is not equal to `NaN`')
    ok(!Utils.isEqual(Infinity, NaN), '`Infinity` is not equal to `NaN`')

    # Boolean object and primitive comparisons.
    ok(Utils.isEqual(true, true), 'Identical boolean primitives are equal')
    ok(Utils.isEqual(new Boolean, new Boolean), 'Boolean objects with identical primitive values are equal')
    ok(Utils.isEqual(true, new Boolean(true)), 'Boolean primitives and their corresponding object wrappers are equal')
    ok(Utils.isEqual(new Boolean(true), true), 'Commutative equality is implemented for booleans')
    ok(!Utils.isEqual(new Boolean(true), new Boolean), 'Boolean objects with different primitive values are not equal')

    # Common type coercions.
    ok(!Utils.isEqual(new Boolean(false), true), '`new Boolean(false)` is not equal to `true`')
    ok(!Utils.isEqual('75', 75), 'String and number primitives with like values are not equal')
    ok(!Utils.isEqual(new Number(63), new String(63)), 'String and number objects with like values are not equal')
    ok(!Utils.isEqual(75, '75'), 'Commutative equality is implemented for like string and number values')
    ok(!Utils.isEqual(0, ''), 'Number and string primitives with like values are not equal')
    ok(!Utils.isEqual(1, true), 'Number and boolean primitives with like values are not equal')
    ok(!Utils.isEqual(new Boolean(false), new Number(0)), 'Boolean and number objects with like values are not equal')
    ok(!Utils.isEqual(false, new String('')), 'Boolean primitives and string objects with like values are not equal')
    ok(!Utils.isEqual(12564504e5, new Date(2009, 9, 25)), 'Dates and their corresponding numeric primitive values are not equal')

    # Dates.
    ok(Utils.isEqual(new Date(2009, 9, 25), new Date(2009, 9, 25)), 'Date objects referencing identical times are equal')
    ok(!Utils.isEqual(new Date(2009, 9, 25), new Date(2009, 11, 13)), 'Date objects referencing different times are not equal')
    ok(!Utils.isEqual(new Date(2009, 11, 13), {
      getTime: -> 12606876e5
    }), 'Date objects and objects with a `getTime` method are not equal')
    ok(!Utils.isEqual(new Date('Curly'), new Date('Curly')), 'Invalid dates are not equal')

    # Functions.
    ok(!Utils.isEqual(First, Second), 'Different functions with identical bodies and source code representations are not equal')

    # RegExps.
    ok(Utils.isEqual(/(?:)/gim, /(?:)/gim), 'RegExps with equivalent patterns and flags are equal')
    ok(Utils.isEqual(/(?:)/gi, /(?:)/ig), 'Flag order is not significant')
    ok(!Utils.isEqual(/(?:)/g, /(?:)/gi), 'RegExps with equivalent patterns and different flags are not equal')
    ok(!Utils.isEqual(/Moe/gim, /Curly/gim), 'RegExps with different patterns and equivalent flags are not equal')
    ok(!Utils.isEqual(/(?:)/gi, /(?:)/g), 'Commutative equality is implemented for RegExps')
    ok(!Utils.isEqual(/Curly/g, {source: 'Larry', global: true, ignoreCase: false, multiline: false}), 'RegExps and RegExp-like objects are not equal')

    # Empty arrays, array-like objects, and object literals.
    ok(Utils.isEqual({}, {}), 'Empty object literals are equal')
    ok(Utils.isEqual([], []), 'Empty array literals are equal')
    ok(Utils.isEqual([{}], [{}]), 'Empty nested arrays and objects are equal')
    ok(!Utils.isEqual({length: 0}, []), 'Array-like objects and arrays are not equal.')
    ok(!Utils.isEqual([], {length: 0}), 'Commutative equality is implemented for array-like objects')

    ok(!Utils.isEqual({}, []), 'Object literals and array literals are not equal')
    ok(!Utils.isEqual([], {}), 'Commutative equality is implemented for objects and arrays')

    # Arrays with primitive and object values.
    ok(Utils.isEqual([1, 'Larry', true], [1, 'Larry', true]), 'Arrays containing identical primitives are equal')
    ok(Utils.isEqual([/Moe/g, new Date(2009, 9, 25)], [/Moe/g, new Date(2009, 9, 25)]), 'Arrays containing equivalent elements are equal')

    # Multi-dimensional arrays.
    a = [new Number(47), false, 'Larry', /Moe/, new Date(2009, 11, 13), ['running', 'biking', new String('programming')], {a: 47}]
    b = [new Number(47), false, 'Larry', /Moe/, new Date(2009, 11, 13), ['running', 'biking', new String('programming')], {a: 47}]
    ok(Utils.isEqual(a, b), 'Arrays containing nested arrays and objects are recursively compared')

    # Overwrite the methods defined in ES 5.1 section 15.4.4.
    a.forEach = a.map = a.filter = a.every = a.indexOf = a.lastIndexOf = a.some = a.reduce = a.reduceRight = null
    b.join = b.pop = b.reverse = b.shift = b.slice = b.splice = b.concat = b.sort = b.unshift = null

    # Array elements and properties.
    ok(Utils.isEqual(a, b), 'Arrays containing equivalent elements and different non-numeric properties are equal')
    a.push('White Rocks')
    ok(!Utils.isEqual(a, b), 'Arrays of different lengths are not equal')
    a.push('East Boulder')
    b.push('Gunbarrel Ranch', 'Teller Farm')
    ok(!Utils.isEqual(a, b), 'Arrays of identical lengths containing different elements are not equal')

    # Sparse arrays.
    ok(Utils.isEqual(Array(3), Array(3)), 'Sparse arrays of identical lengths are equal')
    ok(!Utils.isEqual(Array(3), Array(6)), 'Sparse arrays of different lengths are not equal when both are empty')

    sparse = []
    sparse[1] = 5
    ok(Utils.isEqual(sparse, [undefined, 5]), 'Handles sparse arrays as dense')

    # Simple objects.
    ok(Utils.isEqual({a: 'Curly', b: 1, c: true}, {a: 'Curly', b: 1, c: true}), 'Objects containing identical primitives are equal')
    ok(Utils.isEqual({a: /Curly/g, b: new Date(2009, 11, 13)}, {a: /Curly/g, b: new Date(2009, 11, 13)}), 'Objects containing equivalent members are equal')
    ok(!Utils.isEqual({a: 63, b: 75}, {a: 61, b: 55}), 'Objects of identical sizes with different values are not equal')
    ok(!Utils.isEqual({a: 63, b: 75}, {a: 61, c: 55}), 'Objects of identical sizes with different property names are not equal')
    ok(!Utils.isEqual({a: 1, b: 2}, {a: 1}), 'Objects of different sizes are not equal')
    ok(!Utils.isEqual({a: 1}, {a: 1, b: 2}), 'Commutative equality is implemented for objects')
    ok(!Utils.isEqual({x: 1, y: undefined}, {x: 1, z: 2}), 'Objects with identical keys and different values are not equivalent')

    # `A` contains nested objects and arrays.
    a = {
      name: new String('Moe Howard'),
      age: new Number(77),
      stooge: true,
      hobbies: ['acting'],
      film: {
        name: 'Sing a Song of Six Pants',
        release: new Date(1947, 9, 30),
        stars: [new String('Larry Fine'), 'Shemp Howard'],
        minutes: new Number(16),
        seconds: 54
      }
    }

    # `B` contains equivalent nested objects and arrays.
    b = {
      name: new String('Moe Howard'),
      age: new Number(77),
      stooge: true,
      hobbies: ['acting'],
      film: {
        name: 'Sing a Song of Six Pants',
        release: new Date(1947, 9, 30),
        stars: [new String('Larry Fine'), 'Shemp Howard'],
        minutes: new Number(16),
        seconds: 54
      }
    }
    ok(Utils.isEqual(a, b), 'Objects with nested equivalent members are recursively compared')

    # Instances.
    ok(Utils.isEqual(new First, new First), 'Object instances are equal')
    ok(!Utils.isEqual(new First, new Second), 'Objects with different constructors and identical own properties are not equal')
    ok(!Utils.isEqual({value: 1}, new First), 'Object instances and objects sharing equivalent properties are not equal')
    ok(!Utils.isEqual({value: 2}, new Second), 'The prototype chain of objects should not be examined')

    # Circular Arrays.
    (a = []).push(a)
    (b = []).push(b)
    ok(Utils.isEqual(a, b), 'Arrays containing circular references are equal')
    a.push(new String('Larry'))
    b.push(new String('Larry'))
    ok(Utils.isEqual(a, b), 'Arrays containing circular references and equivalent properties are equal')
    a.push('Shemp')
    b.push('Curly')
    ok(!Utils.isEqual(a, b), 'Arrays containing circular references and different properties are not equal')

    # More circular arrays #767.
    a = ['everything is checked but', 'this', 'is not']
    a[1] = a
    b = ['everything is checked but', ['this', 'array'], 'is not']
    ok(!Utils.isEqual(a, b), 'Comparison of circular references with non-circular references are not equal')

    # Circular Objects.
    a = {abc: null}
    b = {abc: null}
    a.abc = a
    b.abc = b
    ok(Utils.isEqual(a, b), 'Objects containing circular references are equal')
    a.def = 75
    b.def = 75
    ok(Utils.isEqual(a, b), 'Objects containing circular references and equivalent properties are equal')
    a.def = new Number(75)
    b.def = new Number(63)
    ok(!Utils.isEqual(a, b), 'Objects containing circular references and different properties are not equal')

    # More circular objects #767.
    a = {everything: 'is checked', but: 'this', is: 'not'}
    a.but = a
    b = {everything: 'is checked', but: {that: 'object'}, is: 'not'}
    ok(!Utils.isEqual(a, b), 'Comparison of circular references with non-circular object references are not equal')

    # Cyclic Structures.
    a = [{abc: null}]
    b = [{abc: null}]
    (a[0].abc = a).push(a)
    (b[0].abc = b).push(b)
    ok(Utils.isEqual(a, b), 'Cyclic structures are equal')
    a[0].def = 'Larry'
    b[0].def = 'Larry'
    ok(Utils.isEqual(a, b), 'Cyclic structures containing equivalent properties are equal')
    a[0].def = new String('Larry')
    b[0].def = new String('Curly')
    ok(!Utils.isEqual(a, b), 'Cyclic structures containing different properties are not equal')

    # Complex Circular References.
    a = {foo: {b: {foo: {c: {foo: null}}}}}
    b = {foo: {b: {foo: {c: {foo: null}}}}}
    a.foo.b.foo.c.foo = a
    b.foo.b.foo.c.foo = b
    ok(Utils.isEqual(a, b), 'Cyclic structures with nested and identically-named properties are equal')

    # Chaining.
    # NOTE: underscore doesn't support chaining
    #
    # ok(!Utils.isEqual(_({x: 1, y: undefined}).chain(), _({x: 1, z: 2}).chain()), 'Chained objects containing different values are not equal')
    #
    # a = _({x: 1, y: 2}).chain()
    # b = _({x: 1, y: 2}).chain()
    # equal(Utils.isEqual(a.isEqual(b), _(true)), true, '`isEqual` can be chained')

    # Objects without a `constructor` property
    if Object.create
      a = Object.create(null, {x: {value: 1, enumerable: true}})
      b = {x: 1}
      ok(Utils.isEqual(a, b), 'Handles objects without a constructor (e.g. from Object.create')

    Foo = -> @a = 1
    Foo.prototype.constructor = null

    other = {a: 1}
    ok(!Utils.isEqual(new Foo, other))

describe "subjectWithPrefix", ->
  it "should replace an existing Re:", ->
    expect(Utils.subjectWithPrefix("Re: Test Case", "Fwd:")).toEqual("Fwd: Test Case")

  it "should replace an existing re:", ->
    expect(Utils.subjectWithPrefix("re: Test Case", "Fwd:")).toEqual("Fwd: Test Case")

  it "should replace an existing Fwd:", ->
    expect(Utils.subjectWithPrefix("Fwd: Test Case", "Re:")).toEqual("Re: Test Case")

  it "should replace an existing fwd:", ->
    expect(Utils.subjectWithPrefix("fwd: Test Case", "Re:")).toEqual("Re: Test Case")

  it "should not replace Re: or Fwd: found embedded in the subject", ->
    expect(Utils.subjectWithPrefix("My questions are: 123", "Fwd:")).toEqual("Fwd: My questions are: 123")
    expect(Utils.subjectWithPrefix("My questions fwd: 123", "Fwd:")).toEqual("Fwd: My questions fwd: 123")

  it "should work if no existing prefix is present", ->
    expect(Utils.subjectWithPrefix("My questions", "Fwd:")).toEqual("Fwd: My questions")
