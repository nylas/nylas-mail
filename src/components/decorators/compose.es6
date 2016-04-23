
export default function compose(BaseComponent, ...decorators) {
  const ComposedComponent =
    decorators.reduce((comp, decorator) => decorator(comp), BaseComponent)
  ComposedComponent.propTypes = BaseComponent.propTypes
  ComposedComponent.displayName = BaseComponent.displayName
  return ComposedComponent
}
