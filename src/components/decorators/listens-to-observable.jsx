import React from 'react'

function ListensToObservable(ComposedComponent, {getObservable, getStateFromObservable}) {
  return class extends ComposedComponent {
    static displayName = ComposedComponent.displayName;

    static containerRequired = ComposedComponent.containerRequired;

    constructor() {
      super()
      this.state = getStateFromObservable()
      this.observable = getObservable()
    }

    componentDidMount() {
      this.unmounted = false
      this.disposable = this.observable.subscribe(this.onObservableChanged)
    }

    componentWillUnmount() {
      this.unmounted = true
      this.disposable.dispose()
    }

    onObservableChanged = (data) => {
      if (this.unmounted) return;
      this.setState(getStateFromObservable(data))
    };

    render() {
      return (
        <ComposedComponent {...this.state} {...this.props} />
      )
    }
  }
}

export default ListensToObservable
