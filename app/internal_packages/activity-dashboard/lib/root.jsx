import React from 'react';
import PropTypes from 'prop-types';
import moment from 'moment';
import { Message, DatabaseStore, FocusedPerspectiveStore } from 'mailspring-exports';
import { DropdownMenu, Menu, ListensToFluxStore } from 'mailspring-component-kit';

import { MetricContainer, MetricStat, MetricGraph, MetricHistogram } from './metrics-components';
import LoadingCover from './loading-cover';

const CHUNK_SIZE = 500;
const MINIMUM_THINKING_TIME = 2000;

function getTimespanOptions() {
  return [
    { id: '0', name: 'Today' },
    { id: '6', name: 'Last 7 Days' },
    { id: '13', name: 'Last 2 Weeks' },
    { id: '27', name: 'Last 4 Weeks' },
    { id: '-', name: '-', divider: true },
    ...[0, 1, 2].map(n => {
      return {
        id: `month-${n}`,
        name: moment()
          .subtract(n, 'month')
          .format('MMMM YYYY'),
      };
    }),
  ];
}

function getTimespanStartEnd(id) {
  if (id.startsWith('month-')) {
    const n = id.split('-').pop() / 1;
    const current = n === 0;
    return [
      moment()
        .startOf('month')
        .subtract(n, 'month')
        .add(1, 'minute'),
      current
        ? moment()
        : moment()
            .startOf('month')
            .subtract(n - 1, 'month')
            .subtract(1, 'minute'),
    ];
  }
  return [
    moment()
      .startOf('day')
      .subtract(id / 1, 'day')
      .add(1, 'minute'),
    moment(),
  ];
}

class TimespanSelector extends React.Component {
  static propTypes = {
    timespan: PropTypes.object,
    onChange: PropTypes.func,
  };

  render() {
    const { id, startDate, endDate } = this.props.timespan;

    const options = getTimespanOptions();
    const itemIdx = options.findIndex(item => item.id === id);

    const longFormat = id.startsWith('month') ? 'MMMM Do, h:mmA' : 'dddd MMMM Do, h:mmA';
    const endFormat = endDate.diff(moment(), 'days') === 0 ? 'Now' : endDate.format(longFormat);
    return (
      <div className="timespan-selector">
        <div className="timespan-text">{`${startDate.format(longFormat)} - ${endFormat}`}</div>
        <DropdownMenu
          attachment={DropdownMenu.Attachment.RightEdge}
          intitialSelectionItem={options[itemIdx]}
          defaultSelectedIndex={itemIdx}
          headerComponents={[]}
          footerComponents={[]}
          items={options}
          itemKey={item => item.id}
          itemContent={item => (item.divider ? <Menu.Item key="divider" divider /> : item.name)}
          onSelect={item => this.props.onChange(item.id)}
        />
      </div>
    );
  }
}

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
          <div>Link and Open Tracking</div>
        </div>
        <div className="section" style={{ display: 'flex' }}>
          <MetricContainer name="Of your emails are opened">
            <MetricStat key={version} value={metrics.percentOpened} units="%" loading={loading} />
          </MetricContainer>
          <MetricContainer name="Of recipients click a link">
            <MetricStat
              key={version}
              value={metrics.percentLinkClicked}
              units="%"
              loading={loading}
            />
          </MetricContainer>
          <MetricContainer name="Of threads you start get a reply">
            <MetricStat key={version} value={metrics.percentReplied} units="%" loading={loading} />
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
      <div className="activity-dashboard">
        <div className="header">
          <h2>Activity</h2>
          <TimespanSelector timespan={this.state.timespan} onChange={this._onChangeTimespan} />
        </div>
        <RootWithTimespan accountIds={this.props.accountIds} timespan={this.state.timespan} />
      </div>
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
