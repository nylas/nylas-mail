class CustomContenteditableComponents {
  constructor() {
    this._components = {}
  }

  get(componentKey) {
    return this._components[componentKey]
  }

  register(componentKey, component) {
    if (!component) {
      throw new Error("Must register a component.")
    }
    this._components[componentKey] = component
  }

  unregister(componentKey) {
    delete this._components[componentKey]
  }
}

const store = new CustomContenteditableComponents();
export default store
