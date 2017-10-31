import { React, PropTypes, Actions, SendActionsStore, SoundRegistry } from 'mailspring-exports';
import { Menu, RetinaImg, ButtonDropdown, ListensToFluxStore } from 'mailspring-component-kit';

class SendActionButton extends React.Component {
  static displayName = 'SendActionButton';

  static containerRequired = false;

  static propTypes = {
    draft: PropTypes.object,
    isValidDraft: PropTypes.func,
    sendActions: PropTypes.array,
    orderedSendActions: PropTypes.object,
  };

  primarySend() {
    this._onPrimaryClick();
  }

  _onPrimaryClick = () => {
    const { orderedSendActions } = this.props;
    const { preferred } = orderedSendActions;
    this._onSendWithAction(preferred);
  };

  _onSendWithAction = sendAction => {
    const { isValidDraft, draft } = this.props;
    if (isValidDraft()) {
      if (AppEnv.config.get('core.sending.sounds')) {
        SoundRegistry.playSound('hit-send');
      }
      Actions.sendDraft(draft.headerMessageId, sendAction.configKey);
    }
  };

  _renderSendActionItem = ({ iconUrl }) => {
    let plusHTML = '';
    let additionalImg = false;

    if (iconUrl) {
      plusHTML = <span>&nbsp;+&nbsp;</span>;
      additionalImg = <RetinaImg url={iconUrl} mode={RetinaImg.Mode.ContentIsMask} />;
    }

    return (
      <span>
        <RetinaImg name="icon-composer-send.png" mode={RetinaImg.Mode.ContentIsMask} />
        <span className="text">Send{plusHTML}</span>
        {additionalImg}
      </span>
    );
  };

  _renderSingleButton() {
    const { sendActions } = this.props;
    return (
      <button
        tabIndex={-1}
        className={'btn btn-toolbar btn-normal btn-emphasis btn-text btn-send'}
        style={{ order: -100 }}
        onClick={this._onPrimaryClick}
      >
        {this._renderSendActionItem(sendActions[0])}
      </button>
    );
  }

  _renderButtonDropdown() {
    const { orderedSendActions } = this.props;
    const { preferred, rest } = orderedSendActions;

    const menu = (
      <Menu
        items={rest}
        itemKey={actionConfig => actionConfig.configKey}
        itemContent={this._renderSendActionItem}
        onSelect={this._onSendWithAction}
      />
    );

    return (
      <ButtonDropdown
        className={'btn-send btn-emphasis btn-text'}
        style={{ order: -100 }}
        primaryItem={this._renderSendActionItem(preferred)}
        primaryTitle={preferred.title}
        primaryClick={this._onPrimaryClick}
        closeOnMenuClick
        menu={menu}
      />
    );
  }

  render() {
    const { sendActions } = this.props;
    if (sendActions.length === 1) {
      return this._renderSingleButton();
    }
    return this._renderButtonDropdown();
  }
}

const EnhancedSendActionButton = ListensToFluxStore(SendActionButton, {
  stores: [SendActionsStore],
  getStateFromStores(props) {
    const { draft } = props;
    return {
      sendActions: SendActionsStore.availableSendActionsForDraft(draft),
      orderedSendActions: SendActionsStore.orderedSendActionsForDraft(draft),
    };
  },
});
// TODO this is a hack so that the send button can still expose
// the `primarySend` method required by the ComposerView. Ideally, this
// decorator mechanism should expose whatever instance methods are exposed
// by the component its wrapping.
// However, I think the better fix will happen when mail merge lives in its
// own window and doesn't need to override the Composer's send button, which
// is already a bit of a hack.
Object.assign(EnhancedSendActionButton.prototype, {
  primarySend() {
    if (this._composedComponent) {
      this._composedComponent.primarySend();
    }
  },
});

EnhancedSendActionButton.UndecoratedSendActionButton = SendActionButton;

export default EnhancedSendActionButton;
