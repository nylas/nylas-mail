import _ from 'underscore'
import _str from 'underscore.string'
import {React, Actions, ExtensionRegistry} from 'nylas-exports'
import {Menu, RetinaImg, ButtonDropdown} from 'nylas-component-kit'

const CONFIG_KEY = "core.sending.defaultSendType";

export default class SendActionButton extends React.Component {
  static displayName = "SendActionButton";

  static containerRequired = false

  static propTypes = {
    draft: React.PropTypes.object,
    isValidDraft: React.PropTypes.func,
  };

  constructor(props) {
    super(props)
    this.state = {
      actionConfigs: this._actionConfigs(this.props),
    };
  }

  componentDidMount() {
    this.unsub = ExtensionRegistry.Composer.listen(this._onExtensionsChanged);
  }

  componentWillReceiveProps(newProps) {
    this.setState({actionConfigs: this._actionConfigs(newProps)});
  }

  componentWillUnmount() {
    this.unsub();
  }

  primaryClick() {
    this._onPrimaryClick();
  }

  _configKeyFromTitle(title) {
    return _str.dasherize(title.toLowerCase());
  }

  _defaultActionConfig() {
    return ({
      title: "Send",
      iconUrl: null,
      onSend: ({draft}) => Actions.sendDraft(draft.clientId),
      configKey: "send",
    });
  }

  _actionConfigs(props) {
    const actionConfigs = [this._defaultActionConfig()]

    for (const extension of ExtensionRegistry.Composer.extensions()) {
      if (!extension.sendActionConfig) {
        continue;
      }

      try {
        const actionConfig = extension.sendActionConfig({draft: props.draft});
        if (actionConfig) {
          this._verifyConfig(actionConfig, extension);
          actionConfig.configKey = this._configKeyFromTitle(actionConfig.title);
          actionConfigs.push(actionConfig);
        }
      } catch (err) {
        NylasEnv.reportError(err);
      }
    }
    return actionConfigs;
  }

  _verifyConfig(config = {}, extension) {
    const name = extension.name;
    if (!_.isString(config.title)) {
      throw new Error(`${name}.sendActionConfig must return a string "title"`);
    }
    if (!_.isFunction(config.onSend)) {
      throw new Error(`${name}.sendActionConfig must return a "onSend" function that will be called when the action is selected`);
    }
    return true;
  }

  _onExtensionsChanged = () => {
    this.setState({actionConfigs: this._actionConfigs(this.props)});
  }

  _onPrimaryClick = () => {
    const {preferred} = this._orderedActionConfigs();
    this._onSendWithAction(preferred);
  }

  _onSendWithAction = ({onSend}) => {
    if (this.props.isValidDraft()) {
      try {
        onSend({draft: this.props.draft});
      } catch (err) {
        NylasEnv.reportError(err)
      }
    }
  }

  _orderedActionConfigs() {
    const configKeys = _.pluck(this.state.actionConfigs, "configKey");
    let preferredKey = NylasEnv.config.get(CONFIG_KEY);
    if (!preferredKey || !configKeys.includes(preferredKey)) {
      preferredKey = this._defaultActionConfig().configKey;
    }

    const preferred = _.findWhere(this.state.actionConfigs, {configKey: preferredKey});
    const rest = _.without(this.state.actionConfigs, preferred);

    return {preferred, rest};
  }

  _contentForAction = ({iconUrl}) => {
    let plusHTML = "";
    let additionalImg = false;

    if (iconUrl) {
      plusHTML = (<span>&nbsp;+&nbsp;</span>);
      additionalImg = (<RetinaImg url={iconUrl} mode={RetinaImg.Mode.ContentIsMask} />);
    }

    return (
      <span>
        <RetinaImg name="icon-composer-send.png" mode={RetinaImg.Mode.ContentIsMask} />
        <span className="text">Send{plusHTML}</span>{additionalImg}
      </span>
    );
  }

  _renderSingleButton() {
    return (
      <button
        tabIndex={-1}
        className={"btn btn-toolbar btn-normal btn-emphasis btn-text btn-send"}
        style={{order: -100}}
        onClick={this._onPrimaryClick}
      >
        {this._contentForAction(this.state.actionConfigs[0])}
      </button>
    );
  }

  _renderButtonDropdown() {
    const {preferred, rest} = this._orderedActionConfigs()

    const menu = (
      <Menu
        items={rest}
        itemKey={(actionConfig) => actionConfig.configKey}
        itemContent={this._contentForAction}
        onSelect={this._onSendWithAction}
      />
  );

    return (
      <ButtonDropdown
        className={"btn-send btn-emphasis btn-text"}
        style={{order: -100}}
        primaryItem={this._contentForAction(preferred)}
        primaryTitle={preferred.title}
        primaryClick={this._onPrimaryClick}
        closeOnMenuClick
        menu={menu}
      />
    );
  }

  render() {
    if (this.state.actionConfigs.length === 1) {
      return this._renderSingleButton();
    }
    return this._renderButtonDropdown();
  }

}
