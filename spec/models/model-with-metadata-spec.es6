import ModelWithMetadata from '../../src/flux/models/model-with-metadata'

class TestModel extends ModelWithMetadata {

};

describe("ModelWithMetadata", ()=>{
  it("should initialize pluginMetadata to an empty array", ()=> {
    model = new TestModel();
    expect(model.pluginMetadata).toEqual([]);
  });

  describe("metadataForPluginId", ()=> {
    beforeEach(()=> {
      this.model = new TestModel();
      this.model.applyPluginMetadata('plugin-id-a', {a: true});
      this.model.applyPluginMetadata('plugin-id-b', {b: false});
    })
    it("returns the metadata value for the provided pluginId", ()=> {
      expect(this.model.metadataForPluginId('plugin-id-b')).toEqual({b: false});
    });
    it("returns null if no value is found", ()=> {
      expect(this.model.metadataForPluginId('plugin-id-c')).toEqual(null);
    });
  });

  describe("metadataObjectForPluginId", ()=> {
    it("returns the metadata object for the provided pluginId", ()=> {
      model = new TestModel();
      model.applyPluginMetadata('plugin-id-a', {a: true});
      model.applyPluginMetadata('plugin-id-b', {b: false});
      expect(model.metadataObjectForPluginId('plugin-id-a')).toEqual(model.pluginMetadata[0]);
      expect(model.metadataObjectForPluginId('plugin-id-b')).toEqual(model.pluginMetadata[1]);
      expect(model.metadataObjectForPluginId('plugin-id-c')).toEqual(undefined);
    });
  });

  describe("applyPluginMetadata", ()=> {
    it("creates or updates the appropriate metadata object", ()=> {
      model = new TestModel();
      expect(model.pluginMetadata.length).toEqual(0);

      // create new metadata object with correct value
      model.applyPluginMetadata('plugin-id-a', {a: true});
      obj = model.metadataObjectForPluginId('plugin-id-a');
      expect(model.pluginMetadata.length).toEqual(1);
      expect(obj.pluginId).toBe('plugin-id-a');
      expect(obj.id).toBe('plugin-id-a');
      expect(obj.version).toBe(0);
      expect(obj.value.a).toBe(true);

      // update existing metadata object
      model.applyPluginMetadata('plugin-id-a', {a: false});
      expect(obj.value.a).toBe(false);
    });
  });

  describe("clonePluginMetadataFrom", ()=> {
    it("applies the pluginMetadata from the other model, copying values but resetting versions", ()=> {
      model = new TestModel();
      model.applyPluginMetadata('plugin-id-a', {a: true});
      model.applyPluginMetadata('plugin-id-b', {b: false});
      model.metadataObjectForPluginId('plugin-id-a').version = 2;
      model.metadataObjectForPluginId('plugin-id-b').version = 3;

      created = new TestModel();
      created.clonePluginMetadataFrom(model);
      aMetadatum = created.metadataObjectForPluginId('plugin-id-a');
      bMetadatum = created.metadataObjectForPluginId('plugin-id-b');
      expect(aMetadatum.version).toEqual(0);
      expect(aMetadatum.value).toEqual({a: true});
      expect(bMetadatum.version).toEqual(0);
      expect(bMetadatum.value).toEqual({b: false});
    });
  });
});
