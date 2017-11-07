import React from 'react';
import PropTypes from 'prop-types';
import { shell } from 'electron';
import { ScrollRegion, ListensToFluxStore, RetinaImg } from 'mailspring-component-kit';
import {
  AccountStore,
  Message,
  DatabaseStore,
  FocusedPerspectiveStore,
  Actions,
} from 'mailspring-exports';

import {
  MetricContainer,
  MetricStat,
  MetricGraph,
  MetricHistogram,
  MetricsBySubjectTable,
} from './metrics-components';

import ShareButton from './share-button';
import { DEFAULT_TIMESPAN_ID, getTimespanStartEnd } from './timespan';
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
      metricsBySubjectLine: [],
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
    const threadStats = {};

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

        // Received and Sent Metrics
        if (message.isFromMe()) {
          sentTotal += 1;
          sentByDay[dayIdx] += 1;

          if (threadStats[message.threadId] === undefined) {
            threadStats[message.threadId] = {
              outbound: true,
              subject: message.subject,
              tracked: false,
              hasReply: false,
              opened: false,
              clicked: false,
            };
          }
        } else {
          receivedByDay[dayIdx] += 1;
          if (threadStats[message.threadId]) {
            threadStats[message.threadId].hasReply = true;
          } else {
            threadStats[message.threadId] = {
              outbound: false,
            };
          }
        }

        // Time of Day Metrics
        const hourIdx = message.date.getHours();
        receivedTimeOfDay[hourIdx] += 1;

        // Link and Open Tracking Metrics
        const openM = message.metadataForPluginId('open-tracking');
        if (openM) {
          threadStats[message.threadId].tracked = true;
          openTrackingEnabled += 1;
          if (openM.open_count > 0) {
            threadStats[message.threadId].opened = true;
            openTrackingTriggered += 1;
          }
        }
        const linkM = message.metadataForPluginId('link-tracking');
        if (linkM && linkM.tracked && linkM.links instanceof Array) {
          threadStats[message.threadId].tracked = true;
          linkTrackingEnabled += 1;
          if (linkM.links.some(l => l.click_count > 0)) {
            threadStats[message.threadId].clicked = true;
            linkTrackingTriggered += 1;
          }
        }
      }

      if (messages.length < CHUNK_SIZE) {
        break;
      }
    }

    const outboundThreadStats = Object.values(threadStats).filter(stats => stats.outbound);

    // compute total reply rate for all sent messages
    let threadsOutbound = 0;
    let threadsOutboundGotReply = 0;
    for (const stats of outboundThreadStats) {
      threadsOutbound += 1;
      if (stats.hasReply) {
        threadsOutboundGotReply += 1;
      }
    }

    // Aggregate open/link tracking of outbound threads by subject line
    let bySubject = {};
    for (const stats of outboundThreadStats) {
      if (!stats.tracked) {
        continue;
      }
      bySubject[stats.subject] = bySubject[stats.subject] || {
        subject: stats.subject,
        count: 0,
        opens: 0,
        clicks: 0,
        replies: 0,
      };
      bySubject[stats.subject].count += 1;
      if (stats.hasReply) {
        bySubject[stats.subject].replies += 1;
      }
      if (stats.opened) {
        bySubject[stats.subject].opens += 1;
      }
      if (stats.clicked) {
        bySubject[stats.subject].clicks += 1;
      }
    }

    const bySubjectSorted = Object.values(bySubject)
      .filter(a => a.count > 1)
      .sort((a, b) => b.opens - a.opens);

    // Okay! Make sure we've taken at least 1500ms and then fade in the stats
    const animationDelay = Math.max(0, metricsComputeStarted + MINIMUM_THINKING_TIME - Date.now());

    setTimeout(() => {
      if (!this._mounted) {
        return;
      }
      this.setState({
        loading: false,
        version: this.state.version + 1,
        metricsBySubjectLine: bySubjectSorted,
        metrics: {
          receivedByDay,
          receivedTimeOfDay,
          sentByDay,
          percentUsingTracking: Math.ceil(
            Math.max(openTrackingEnabled, linkTrackingEnabled) / (sentTotal || 1) * 100
          ),
          percentOpened: Math.ceil(openTrackingTriggered / (openTrackingEnabled || 1) * 100),
          percentLinkClicked: Math.ceil(linkTrackingTriggered / (linkTrackingEnabled || 1) * 100),
          percentReplied: Math.ceil(threadsOutboundGotReply / (threadsOutbound || 1) * 100),
        },
      });
    }, animationDelay);
  };

  _onFetchChunk(accountIds, startUnix, endUnix) {
    return new Promise(resolve => {
      window.requestAnimationFrame(() => {
        DatabaseStore.findAll(Message)
          .background()
          .where(Message.attributes.accountId.in(accountIds))
          .where(Message.attributes.date.greaterThan(startUnix))
          .where(Message.attributes.date.lessThan(endUnix))
          .order(Message.attributes.date.ascending())
          .limit(CHUNK_SIZE)
          .then(resolve);
      });
    });
  }

  _onShowTemplates = () => {
    Actions.showTemplates();
  };

  _onLearnMore = () => {
    shell.openExternal('http://support.getmailspring.com/hc/en-us/articles/115002507891');
  };

  render() {
    const { metrics, metricsBySubjectLine, version, loading } = this.state;
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
            <RetinaImg
              name="icon-activity-mailopen.png"
              className="hidden-on-web"
              mode={RetinaImg.Mode.ContentDark}
            />
            {' or link tracking '}
            <RetinaImg
              name="icon-activity-linkopen.png"
              className="hidden-on-web"
              mode={RetinaImg.Mode.ContentDark}
            />
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

        <div className="section-divider">
          <div>Best Templates and Subject Lines</div>
        </div>
        <div className="section" style={{ display: 'flex' }}>
          {metricsBySubjectLine.length === 0 ? (
            <div className="empty-note">
              Send more than one message using the same{' '}
              <a onClick={this._onShowTemplates}>template</a> or subject line to compare open rates
              and reply rates.
            </div>
          ) : (
            <MetricsBySubjectTable data={metricsBySubjectLine} />
          )}
        </div>
        <div className="section hidden-on-web" style={{ display: 'flex', textAlign: 'center' }}>
          <div style={{ display: 'flex', margin: 'auto' }}>
            <div
              className="btn"
              onClick={this._onLearnMore}
              style={{ marginRight: 10, width: 115 }}
            >
              Learn More
            </div>
            <ShareButton key={version} />
          </div>
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

    this.state = this.getStateForTimespanId(DEFAULT_TIMESPAN_ID);
  }

  getStateForTimespanId(timespanId) {
    const [startDate, endDate] = getTimespanStartEnd(timespanId);
    // if the difference in days is 1, we need to display [0, 1] = 2 items
    const days = endDate.diff(startDate, 'days') + 1;
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
    const { accountIds } = this.props;

    return (
      <ScrollRegion className="activity-dashboard">
        <div className="header">
          <div style={{ flex: 1 }}>
            <h2>Activity</h2>
            <div className="accounts">
              {accountIds.length > 1
                ? 'All Accounts'
                : AccountStore.accountForId(accountIds[0]).label}
            </div>
          </div>
          <TimespanSelector timespan={this.state.timespan} onChange={this._onChangeTimespan} />
        </div>
        <RootWithTimespan accountIds={accountIds} timespan={this.state.timespan} />
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
