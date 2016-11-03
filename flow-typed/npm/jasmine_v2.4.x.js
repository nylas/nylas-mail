// flow-typed signature: 3ca7176a59bf097ebbc671b0a514dffd
// flow-typed version: ed54a89c37/jasmine_v2.4.x/flow_vx.x.x

type JasmineExpectType = {
  not: JasmineExpectType;
  toBe(value: mixed): void;
  toBeCloseTo(num: number, delta: mixed): void;
  toBeDefined(): void;
  toBeFalsy(): void;
  toBeGreaterThan(number: number): void;
  toBeLessThan(number: number): void;
  toBeNull(): void;
  toBeTruthy(): void;
  toBeUndefined(): void;
  toContain(str: string): void;
  toEqual(value: mixed): void;
  toHaveBeenCalled(): void;
  toHaveBeenCalledTimes(number: number): void;
  toHaveBeenCalledWith(...args: Array<any>): void;
  toMatch(regexp: RegExp): void;
  toThrow(message?: string): void;
  toThrowError(val: mixed): void;
};

declare function describe(name: string, fn: Function): void;
declare function fdescribe(name: string, fn: Function): void;
declare function xdescribe(name: string, fn: Function): void;

declare function beforeEach(fn: Function): void;
declare function afterEach(fn: Function): void;
declare function beforeAll(fn: Function): void;
declare function afterAll(fn: Function): void;

declare function it(name: string, fn: Function): void;
declare function fit(name: string, fn: Function): void;
declare function xit(name: string, fn: Function): void;

declare function expect(value: mixed): JasmineExpectType;
declare function fail(err?: Error | string): void;

// TODO handle return type
// http://jasmine.github.io/2.4/introduction.html#section-Spies
declare function spyOn(value: mixed, method: string): Object;

type JasmineCallsType = {
  allArgs(): mixed;
  all(): mixed;
  mostRecent(): mixed;
  first(): mixed;
  any(): boolean;
  count(): number;
  reset(): void;
}

type JasmineSpyType = {
  calls: JasmineCallsType;
}

type JasmineClockType = {
  install(): void;
  uninstall(): void;
  tick(): void;
  mockDate(date: Date): void;
}

declare var jasmine: {
  createSpy(name: string): JasmineSpyType;
  any(val: mixed): void;
  anything(): void;
  objectContaining(val: Object): void;
  arrayContaining(val: mixed[]): void;
  stringMatching(val: string): void;
  clock(): JasmineClockType;
}
