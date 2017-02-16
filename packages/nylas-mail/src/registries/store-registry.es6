import SerializableRegistry from './serializable-registry'

class StoreRegistry extends SerializableRegistry {
  /**
   * Most of the core Flux stores construct themselves on require. That
   * construction initialize the stores, sets up listeners, and may access
   * the database.
   *
   * It also kicks off a fairly large tree of require statements that
   * takes considerable time to process.
   */
  async activateAllStores() {
    for (const name of Object.keys(this._constructorFactories)) {
      // All we need to do is hit `require` on the store. This will
      // construct the object an initialize the require cache. The
      // stores are now available in nylas-exports or from the node
      // require cache.
      const store = this.get(name);

      /**
       * Some stores may have extra activation work to do. This work may
       * be asynchronous. We detect that here and call the store's
       * activate methods.
       */
      if (store.activate) {
        await store.activate()
      }
    }
  }
}

const registry = new StoreRegistry()
export default registry
