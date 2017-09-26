import React, { Component } from 'react';
import PropTypes from 'prop-types';
import moment from 'moment';
import { DateUtils, Actions, SyncbackMetadataTask, TaskQueue, SendDraftTask } from 'nylas-exports';
import { RetinaImg } from 'nylas-component-kit';
import { PLUGIN_ID } from './send-later-constants';

const { DATE_FORMAT_SHORT } = DateUtils;

export default class SendLaterStatus extends Component {
  static displayName = 'SendLaterStatus';

  static propTypes = {
    draft: PropTypes.object,
  };

  constructor(props) {
    super(props);
    this.state = this.getStateFromStores(props);
  }

  componentDidMount() {
    this._unlisten = TaskQueue.listen(() => {
      this.setState(this.getStateFromStores(this.props));
    });
  }

  componentWillReceiveProps(nextProps) {
    this.setState(this.getStateFromStores(nextProps));
  }

  componentWillUnmount() {
    if (this._unlisten) {
      this._unlisten();
    }
  }

  onCancelSendLater = () => {
    Actions.queueTask(
      new SyncbackMetadataTask({
        model: this.props.draft,
        accountId: this.props.draft.accountId,
        pluginId: PLUGIN_ID,
        value: { expiration: null },
      })
    );
  };

  getStateFromStores({ draft }) {
    return {
      task: TaskQueue.findTasks(
        SendDraftTask,
        { headerMessageId: draft.headerMessageId },
        { includeCompleted: true }
      ).pop(),
    };
  }

  render() {
    const metadata = this.props.draft.metadataForPluginId(PLUGIN_ID);
    if (!metadata || !metadata.expiration) {
      return <span />;
    }

    const { expiration } = metadata;

    let label = null;
    if (expiration > new Date(Date.now() + 60 * 1000)) {
      label = `Scheduled for ${DateUtils.format(moment(expiration), DATE_FORMAT_SHORT)}`;
    } else {
      label = `Sending in a few seconds...`;
      if (this.state.task) {
        label = `Sending now...`;
      }
    }

    return (
      <div className="send-later-status">
        <span className="time">{label}</span>
        <RetinaImg
          name="image-cancel-button.png"
          title="Cancel Send Later"
          onClick={this.onCancelSendLater}
          mode={RetinaImg.Mode.ContentPreserve}
        />
      </div>
    );
  }
}
