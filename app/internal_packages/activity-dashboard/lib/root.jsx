import React from 'react';
import PropTypes from 'prop-types';
import { Message, DatabaseStore, FocusedPerspectiveStore } from 'mailspring-exports';
import { ScrollRegion, ListensToFluxStore, RetinaImg } from 'mailspring-component-kit';

import { MetricContainer, MetricStat, MetricGraph, MetricHistogram } from './metrics-components';
import { getTimespanStartEnd } from './timespan';
import TimespanSelector from './timespan-selector';
import LoadingCover from './loading-cover';

const CHUNK_SIZE = 500;
const MINIMUM_THINKING_TIME = 2000;

class RootWithTimespan extends React.Component {
  static displayName = 'ActivityDashboardRootWithTimespan';

  static propTypes = {
    timespan: PropTypes.object,
    accountIds: PropTypes.arrayOf(PropTypes.string),
  };

  constructor(props) {
    super(props);
    this.state = this.getLoadingState(props);
  }

  componentWillReceiveProps(nextProps) {
    this.setState(this.getLoadingState(nextProps), () => this._onComputeMetrics());
  }

  getLoadingState({ timespan }) {
    return {
      version: 0,
      loading: true,
      metrics: {
        receivedByDay: Array(timespan.days).fill(0),
        receivedTimeOfDay: Array(24).fill(0),
        sentByDay: Array(timespan.days).fill(0),
        percentUsingTracking: 0,
        percentOpened: 0,
        percentLinkClicked: 0,
        percentReplied: 0,
      },
    };
  }

  componentDidMount() {
    setTimeout(this._onComputeMetrics, 10);
    this._mounted = true;
  }

  componentWillUnmount() {
    this._mounted = false;
  }

  _onComputeMetrics = async () => {
    const metricsComputeStarted = Date.now();

    const { timespan: { startDate, endDate, days }, accountIds } = this.props;
    const dayUnix = 24 * 60 * 60;
    const startUnix = startDate.unix();
    const endUnix = endDate.unix();

    const sentByDay = Array(days).fill(0);
    const receivedByDay = Array(days).fill(0);
    const receivedTimeOfDay = Array(24).fill(0);
    let sentTotal = 0;
    let openTrackingEnabled = 0;
    let openTrackingTriggered = 0;
    let linkTrackingEnabled = 0;
    let linkTrackingTriggered = 0;
    let threadStarted = 0;
    let threadStartedGotReply = 0;
    const threadHasNoReply = {};

    let chunkStartUnix = startUnix;
    while (true) {
      const messages = await this._onFetchChunk(accountIds, chunkStartUnix, endUnix);
      if (!this._mounted) {
        return;
      }
      for (const message of messages) {
        if (message.draft) {
          continue;
        }
        const messageUnix = message.date.getTime() / 1000;
        chunkStartUnix = Math.max(chunkStartUnix, messageUnix);

        const dayIdx = Math.floor((messageUnix - startUnix) / dayUnix);
        if (dayIdx > days - 1) {
          continue;
        }

        // Received and Sent
        if (message.isFromMe()) {
          sentTotal += 1;
          sentByDay[dayIdx] += 1;
          if (threadHasNoReply[message.threadId] === undefined) {
            threadStarted += 1;
            threadHasNoReply[message.threadId] = true;
          }
        } else {
          receivedByDay[dayIdx] += 1;
          if (threadHasNoReply[message.threadId]) {
            threadStartedGotReply += 1;
          }
          threadHasNoReply[message.threadId] = false;
        }

        const hourIdx = message.date.getHours();
        receivedTimeOfDay[hourIdx] += 1;

        // Link and Open Tracking
        const openM = message.metadataForPluginId('open-tracking');
        if (openM) {
          openTrackingEnabled += 1;
          if (openM.open_count > 0) {
            openTrackingTriggered += 1;
          }
        }
        const linkM = message.metadataForPluginId('link-tracking');
        if (linkM && linkM.tracked && linkM.links instanceof Array) {
          linkTrackingEnabled += 1;
          if (linkM.links.some(l => l.click_count > 0)) {
            linkTrackingTriggered += 1;
          }
        }
      }

      if (messages.length < CHUNK_SIZE) {
        break;
      }
    }

    const animationDelay = Math.max(0, metricsComputeStarted + MINIMUM_THINKING_TIME - Date.now());

    setTimeout(() => {
      if (!this._mounted) {
        return;
      }
      this.setState({
        loading: false,
        version: this.state.version + 1,
        metrics: {
          receivedByDay,
          receivedTimeOfDay,
          sentByDay,
          percentUsingTracking: Math.ceil(
            Math.max(openTrackingEnabled, linkTrackingEnabled) / (sentTotal || 1) * 100
          ),
          percentOpened: Math.ceil(openTrackingTriggered / (openTrackingEnabled || 1) * 100),
          percentLinkClicked: Math.ceil(linkTrackingTriggered / (linkTrackingEnabled || 1) * 100),
          percentReplied: Math.ceil(threadStartedGotReply / (threadStarted || 1) * 100),
        },
      });
    }, animationDelay);
  };

  _onFetchChunk(accountIds, startUnix, endUnix) {
    return new Promise(resolve => {
      window.requestAnimationFrame(() => {
        DatabaseStore.findAll(Message)
          .where(Message.attributes.accountId.equal(accountIds))
          .where(Message.attributes.date.greaterThan(startUnix))
          .where(Message.attributes.date.lessThan(endUnix))
          .order(Message.attributes.date.ascending())
          .limit(CHUNK_SIZE)
          .then(resolve);
      });
    });
  }

  render() {
    const { metrics, version, loading } = this.state;
    const lowTrackingUsage = !loading && metrics.percentUsingTracking < 75;
    let lowTrackingPhrase = `only enabled on ${metrics.percentUsingTracking}%`;
    if (metrics.percentUsingTracking <= 1) {
      lowTrackingPhrase = `not enabled on any`;
    }

    return (
      <div style={{ position: 'relative' }}>
        <LoadingCover active={loading} />
        <div className="section-divider">
          <div>Mailbox Summary</div>
        </div>
        <div className="section" style={{ display: 'flex' }}>
          <MetricContainer name="Messages Received">
            <MetricGraph key={version} values={metrics.receivedByDay} loading={loading} />
          </MetricContainer>
          <MetricContainer name="Messages Sent">
            <MetricGraph key={version} values={metrics.sentByDay} loading={loading} />
          </MetricContainer>
          <MetricContainer name="Messages Time of Day">
            <MetricHistogram
              key={version}
              left="12AM"
              right="11PM"
              loading={loading}
              values={metrics.receivedTimeOfDay}
            />
          </MetricContainer>
        </div>
        <div className="section-divider">
          <div>Read Receipts and Link Tracking</div>
        </div>
        {lowTrackingUsage && (
          <div className="usage-note">
            {`These features were ${lowTrackingPhrase} of the messages you sent
            in this time period, so these numbers do not reflect all of your activity. To enable
            read receipts and link tracking on emails you send, click the 
            `}
            <RetinaImg name="icon-activity-mailopen.png" mode={RetinaImg.Mode.ContentDark} />
            {' or link tracking '}
            <RetinaImg name="icon-activity-linkopen.png" mode={RetinaImg.Mode.ContentDark} />
            {' icons in the composer.'}
          </div>
        )}
        <div className="section" style={{ display: 'flex' }}>
          <MetricContainer name="Of your emails are opened">
            <MetricStat
              key={version}
              value={metrics.percentOpened}
              units="%"
              loading={loading}
              name={'read-receipts'}
            />
          </MetricContainer>
          <MetricContainer name="Of recipients click a link">
            <MetricStat
              key={version}
              value={metrics.percentLinkClicked}
              units="%"
              loading={loading}
              name={'link-tracking'}
            />
          </MetricContainer>
          <MetricContainer name="Of threads you start get a reply">
            <MetricStat
              key={version}
              value={metrics.percentReplied}
              units="%"
              loading={loading}
              name={'replies'}
            />
          </MetricContainer>
        </div>
      </div>
    );
  }
}

class Root extends React.Component {
  static displayName = 'ActivityDashboardRoot';

  static propTypes = {
    accountIds: PropTypes.arrayOf(PropTypes.string),
  };

  constructor(props) {
    super(props);

    this.state = this.getStateForTimespanId('13');
  }

  getStateForTimespanId(timespanId) {
    const [startDate, endDate] = getTimespanStartEnd(timespanId);
    const days = Math.max(1, endDate.diff(startDate, 'days'));
    return {
      timespan: {
        id: timespanId,
        startDate,
        endDate,
        days,
      },
    };
  }

  _onChangeTimespan = timespanId => {
    this.setState(this.getStateForTimespanId(timespanId));
  };

  render() {
    return (
      <ScrollRegion className="activity-dashboard">
        <div className="header">
          <h2>Activity</h2>
          <TimespanSelector timespan={this.state.timespan} onChange={this._onChangeTimespan} />
        </div>
        <RootWithTimespan accountIds={this.props.accountIds} timespan={this.state.timespan} />
      </ScrollRegion>
    );
  }
}
export default ListensToFluxStore(Root, {
  stores: [FocusedPerspectiveStore],
  getStateFromStores: props => {
    return Object.assign({}, props, {
      accountIds: FocusedPerspectiveStore.current().accountIds,
    });
  },
});
