/* eslint quote-props: 0 */
import _ from 'underscore';
import Model from '../src/flux/models/model';
import Attributes from '../src/flux/attributes';
import DatabaseObjectRegistry from '../src/registries/database-object-registry';

class GoodTest extends Model {
  static attributes = Object.assign({}, Model.attributes, {
    foo: Attributes.String({
      modelKey: 'foo',
      jsonKey: 'foo',
    }),
  });
}

describe('DatabaseObjectRegistry', function DatabaseObjectRegistrySpecs() {
  beforeEach(() => DatabaseObjectRegistry.unregister('GoodTest'));

  it('can register constructors', () => {
    const testFn = () => GoodTest;
    expect(() => DatabaseObjectRegistry.register('GoodTest', testFn)).not.toThrow();
    expect(DatabaseObjectRegistry.get('GoodTest')).toBe(GoodTest);
  });

  it('Tests if a constructor is in the registry', () => {
    DatabaseObjectRegistry.register('GoodTest', () => GoodTest);
    expect(DatabaseObjectRegistry.isInRegistry('GoodTest')).toBe(true);
  });

  it('deserializes the objects for a constructor', () => {
    DatabaseObjectRegistry.register('GoodTest', () => GoodTest);
    const obj = DatabaseObjectRegistry.deserialize('GoodTest', { foo: 'bar' });
    expect(obj instanceof GoodTest).toBe(true);
    expect(obj.foo).toBe('bar');
  });

  it("throws an error if the object can't be deserialized", () =>
    expect(() => DatabaseObjectRegistry.deserialize('GoodTest', { foo: 'bar' })).toThrow());
});
