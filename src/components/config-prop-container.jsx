import React from 'react';

export default class ConfigPropContainer extends React.Component {
  static displayName = 'ConfigPropContainer'

  constructor(props) {
    super(props);
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this.subscription = NylasEnv.config.onDidChange(null, () => {
      this.setState(this.getStateFromStores());
    });
  }

  componentWillUnmount() {
    if (this.subscription) {
      this.subscription.dispose();
    }
  }

  getStateFromStores() {
    return {
      config: this.getConfigWithMutators(),
    };
  }

  getConfigWithMutators() {
    return Object.assign(NylasEnv.config.get(), {
      get: (key) => {
        return NylasEnv.config.get(key);
      },
      set: (key, value) => {
        NylasEnv.config.set(key, value);
      },
      toggle: (key) => {
        NylasEnv.config.set(key, !NylasEnv.config.get(key));
      },
      contains: (key, val) => {
        const vals = NylasEnv.config.get(key);
        return (vals && vals instanceof Array) ? vals.includes(val) : false;
      },
      toggleContains: (key, val) => {
        let vals = NylasEnv.config.get(key);
        if (!vals || !(vals instanceof Array)) {
          vals = [];
        }
        if (vals.includes(val)) {
          NylasEnv.config.set(key, vals.filter((v) => v !== val));
        } else {
          NylasEnv.config.set(key, vals.concat([val]));
        }
      },
    });
  }

  render() {
    return React.cloneElement(this.props.children, {
      config: this.state.config,
      configSchema: NylasEnv.config.getSchema('core'),
    });
  }
}
