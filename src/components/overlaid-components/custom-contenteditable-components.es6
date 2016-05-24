class CustomContenteditableComponents {
  constructor() {
    this._components = {}
  }

  get(componentKey) {
    return this._components[componentKey]
  }

  register(componentKey, components = {}) {
    if (!components.main) {
      throw new Error("Must register a `main` component and optionally a `serialized` component.")
    }
    this._components[componentKey] = components
  }

  unregister(componentKey) {
    delete this._components[componentKey]
  }
}

const store = new CustomContenteditableComponents();
export default store
