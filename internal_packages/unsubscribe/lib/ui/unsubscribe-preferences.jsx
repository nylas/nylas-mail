import {React} from 'nylas-exports';
import ConfigSchemaItem from '../../../preferences/lib/tabs/config-schema-item';

const UnsubscribePreferences = ({config}) => {
  return (
    <div className="container-unsubscribe" style={{maxWidth: 600, margin: "0 auto"}}>
      <ConfigSchemaItem
        configSchema={NylasEnv.config.getSchema('unsubscribe')}
        keyName="Unsubscribe"
        keyPath="unsubscribe"
        config={config}
      />
    </div>
  );
}

UnsubscribePreferences.displayName = 'UnsubscribePreferences';
UnsubscribePreferences.propTypes = {
  config: React.PropTypes.object,
  configSchema: React.PropTypes.object,
};

export default UnsubscribePreferences;
