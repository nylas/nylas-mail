import _ from 'underscore';

export class Comparator {
  constructor(name, fn) {
    this.name = name;
    this.fn = fn;
  }

  evaluate({actual, desired}) {
    if (actual instanceof Array) {
      return actual.some((item) => this.fn({actual: item, desired}));
    }
    return this.fn({actual, desired});
  }
}

Comparator.Default = new Comparator('Default', ({actual, desired}) =>
  _.isEqual(actual, desired)
);

const Types = {
  None: 'None',
  Enum: 'Enum',
  String: 'String',
};

export const Comparators = {
  String: {
    contains: new Comparator('contains', ({actual, desired}) => {
      if (!actual || !desired) { return false; }
      return actual.toLowerCase().includes(desired.toLowerCase());
    }),

    doesNotContain: new Comparator('does not contain', ({actual, desired}) => {
      if (!actual || !desired) { return false; }
      return !actual.toLowerCase().includes(desired.toLowerCase());
    }),

    beginsWith: new Comparator('begins with', ({actual, desired}) => {
      if (!actual || !desired) { return false; }
      return actual.toLowerCase().startsWith(desired.toLowerCase());
    }),

    endsWith: new Comparator('ends with', ({actual, desired}) => {
      if (!actual || !desired) { return false; }
      return actual.toLowerCase().endsWith(desired.toLowerCase());
    }),

    equals: new Comparator('equals', ({actual, desired}) =>
      actual === desired
    ),

    matchesExpression: new Comparator('matches expression', ({actual, desired}) => {
      if (!actual || !desired) { return false; }
      return new RegExp(desired, "gi").test(actual);
    }),
  },
};

export class Template {
  static Type = Types;
  static Comparator = Comparator;
  static Comparators = Comparators;

  constructor(key, type, options = {}) {
    this.key = key;
    this.type = type;

    const defaults = {
      name: this.key,
      values: undefined,
      valueLabel: undefined,
      comparators: Comparators[this.type] || {},
    };

    Object.assign(this, defaults, options);

    if (!this.key) {
      throw new Error("You must provide a valid key.");
    }
    if (!(this.type in Types)) {
      throw new Error("You must provide a valid type.");
    }
    if (this.type === Types.Enum && !this.values) {
      throw new Error("You must provide `values` when creating an enum.");
    }
  }

  createDefaultInstance() {
    return {
      templateKey: this.key,
      comparatorKey: Object.keys(this.comparators)[0],
      value: undefined,
    };
  }

  coerceInstance(instance) {
    instance.templateKey = this.key;
    if (!this.comparators) {
      instance.comparatorKey = undefined;
    } else if (!Object.keys(this.comparators).includes(instance.comparatorKey)) {
      instance.comparatorKey = Object.keys(this.comparators)[0];
    }
    return instance;
  }

  evaluate(instance, value) {
    let comparator = this.comparators[instance.comparatorKey];
    if (typeof comparator === 'undefined' || comparator === null) {
      comparator = Comparator.Default;
    }
    return comparator.evaluate({
      actual: value,
      desired: instance.value,
    });
  }
}
