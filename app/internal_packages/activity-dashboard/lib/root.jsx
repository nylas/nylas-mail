import React from 'react';
import PropTypes from 'prop-types';
import moment from 'moment';
import { Message, DatabaseStore } from 'mailspring-exports';
import { DropdownMenu, Menu } from 'mailspring-component-kit';

import { MetricContainer, MetricStat, MetricGraph, MetricHistogram } from './metrics-components';

const CHUNK_SIZE = 500;

function getTimespanOptions() {
  return [
    { id: '0', name: 'Today' },
    { id: '6', name: 'Last 7 Days' },
    { id: '13', name: 'Last 2 Weeks' },
    { id: '27', name: 'Last 4 Weeks' },
    { id: '-', name: '-', divider: true },
    { id: 'this-month', name: moment().format('MMMM YYYY') },
    {
      id: 'last-month',
      name: moment()
        .subtract(1, 'month')
        .format('MMMM YYYY'),
    },
  ];
}

function getTimespanStartEnd(id) {
  if (id === 'this-month') {
    return [moment().startOf('month'), moment()];
  }
  if (id === 'last-month') {
    return [
      moment()
        .startOf('month')
        .subtract(1, 'month'),
      moment().startOf('month'),
    ];
  }
  return [
    moment()
      .startOf('day')
      .subtract(id / 1, 'day'),
    moment(),
  ];
}

class TimespanSelector extends React.Component {
  static propTypes = {
    value: PropTypes.string,
    onChange: PropTypes.func,
  };

  render() {
    const options = getTimespanOptions();

    return (
      <DropdownMenu
        intitialSelectionItem={options.find(item => item.id === this.props.value)}
        headerComponents={[]}
        footerComponents={[]}
        items={options}
        itemKey={item => item.id}
        itemContent={item => (item.divider ? <Menu.Item divider /> : item.name)}
        defaultSelectedIndex={0}
        onSelect={item => this.props.onChange(item.id)}
      />
    );
  }
}

export default class Root extends React.Component {
  static displayName = 'ActivityDashboardRoot';

  constructor(props) {
    super(props);

    this.state = this.getLoadingStateFor('13');
  }

  getLoadingStateFor(timespanId) {
    const [startDate, endDate] = getTimespanStartEnd(timespanId);
    const days = Math.max(1, endDate.diff(startDate, 'days'));

    return {
      timespan: {
        id: timespanId,
        startDate,
        endDate,
        days,
      },
      version: 0,
      loading: true,
      metrics: {
        receivedByDay: Array(days).fill(0),
        receivedTimeOfDay: Array(24).fill(0),
        sentByDay: Array(days).fill(0),
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
    const { startDate, endDate, days } = this.state.timespan;
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
      const messages = await this._onFetchChunk(chunkStartUnix, endUnix);
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
  };

  _onFetchChunk(startUnix, endUnix) {
    return new Promise(resolve => {
      window.requestAnimationFrame(() => {
        DatabaseStore.findAll(Message)
          .where(Message.attributes.date.greaterThan(startUnix))
          .where(Message.attributes.date.lessThan(endUnix))
          .order(Message.attributes.date.ascending())
          .limit(CHUNK_SIZE)
          .then(resolve);
      });
    });
  }

  _onChangeTimespan = timespanId => {
    this.setState(this.getLoadingStateFor(timespanId), () => {
      this._onComputeMetrics();
    });
  };

  render() {
    const { metrics, version, loading, timespan } = this.state;

    return (
      <div className="activity-dashboard">
        <TimespanSelector value={timespan.id} onChange={this._onChangeTimespan} />
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
