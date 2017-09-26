import React from 'react';

export default class ConfigPropContainer extends React.Component {
  static displayName = 'ConfigPropContainer';

  constructor(props) {
    super(props);
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this.subscription = AppEnv.config.onDidChange(null, () => {
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
    return Object.assign(AppEnv.config.get(), {
      get: key => {
        return AppEnv.config.get(key);
      },
      set: (key, value) => {
        AppEnv.config.set(key, value);
      },
      toggle: key => {
        AppEnv.config.set(key, !AppEnv.config.get(key));
      },
      contains: (key, val) => {
        const vals = AppEnv.config.get(key);
        return vals && vals instanceof Array ? vals.includes(val) : false;
      },
      toggleContains: (key, val) => {
        let vals = AppEnv.config.get(key);
        if (!vals || !(vals instanceof Array)) {
          vals = [];
        }
        if (vals.includes(val)) {
          AppEnv.config.set(key, vals.filter(v => v !== val));
        } else {
          AppEnv.config.set(key, vals.concat([val]));
        }
      },
    });
  }

  render() {
    return React.cloneElement(this.props.children, {
      config: this.state.config,
      configSchema: AppEnv.config.getSchema('core'),
    });
  }
}
