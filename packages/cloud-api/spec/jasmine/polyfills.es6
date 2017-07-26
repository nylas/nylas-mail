// We use Jasmine 1 in the client tests and Jasmine 2 in the cloud tests,
// but isomorphic-core tests need to be run in both environments. Tests in
// isomorphic-core should use Jasmine 1 syntax, and then we can add polyfills
// here to make sure that they exist when we run in a Jasmine 2 environment.

export default function applyPolyfills() {
  const origSpyOn = global.spyOn;
  // There's no prototype to modify, so we have to modify the return
  // values of spyOn as they're created.
  global.spyOn = (object, methodName) => {
    const originalValue = object[methodName]
    const spy = origSpyOn(object, methodName)
    object[methodName].originalValue = originalValue;
    spy.andReturn = spy.and.returnValue;
    spy.andCallFake = spy.and.callFake;
    Object.defineProperty(spy.calls, 'length', {get: function getLength() { return this.count(); }})
    return spy;
  }
}
