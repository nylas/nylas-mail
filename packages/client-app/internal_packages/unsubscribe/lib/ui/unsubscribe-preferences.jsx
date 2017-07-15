import {React} from 'nylas-exports';
import ConfigSchemaItem from '../../../preferences/lib/tabs/config-schema-item';
import CommandItem from '../../../preferences/lib/tabs/keymaps/command-item';

class UnsubscribePreferences extends React.Component {

  componentDidMount() {
    this._disposable = NylasEnv.keymaps.onDidReloadKeymap(() => {
      this.setState({binding: NylasEnv.keymaps.getBindingsForCommand('unsubscribe:unsubscribe')});
    });
  }

  componentWillUnmount() {
    this._disposable.dispose();
  }

  render() {
    return (
      <div className="container-unsubscribe" style={{maxWidth: 600, margin: "0 auto"}}>
        <ConfigSchemaItem
          configSchema={NylasEnv.config.getSchema('unsubscribe')}
          keyName="General"
          keyPath="unsubscribe"
          config={this.props.config}
        />
        <h6>Keymaps</h6>
        <div className="container-keymaps">
          <CommandItem
            key={'unsubscribe:unsubscribe'}
            command={'unsubscribe:unsubscribe'}
            label={'Unsubscribe'}
            bindings={NylasEnv.keymaps.getBindingsForCommand('unsubscribe:unsubscribe')}
          />
        </div>
      </div>
    );
  }
}

UnsubscribePreferences.displayName = 'UnsubscribePreferences';
UnsubscribePreferences.propTypes = {
  config: React.PropTypes.object,
  configSchema: React.PropTypes.object,
};

export default UnsubscribePreferences;
