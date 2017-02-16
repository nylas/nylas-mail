import React from 'react';

import {DisclosureTriangle,
  Flexbox,
  RetinaImg} from 'nylas-component-kit';
import {DateUtils} from 'nylas-exports';
import ActivityListStore from './activity-list-store';
import {pluginFor} from './plugin-helpers';


class ActivityListItemContainer extends React.Component {

  static displayName = 'ActivityListItemContainer';

  static propTypes = {
    group: React.PropTypes.array,
  };

  constructor(props) {
    super(props);
    this.state = {
      collapsed: true,
    };
  }

  _onClick(threadId) {
    ActivityListStore.focusThread(threadId);
  }

  _onCollapseToggled = (event) => {
    event.stopPropagation();
    this.setState({collapsed: !this.state.collapsed});
  }

  _getText() {
    const text = {
      recipient: "Someone",
      title: "(No Subject)",
      date: new Date(0),
    };
    const lastAction = this.props.group[0];
    if (this.props.group.length === 1 && lastAction.recipient) {
      text.recipient = lastAction.recipient.displayName();
    } else if (this.props.group.length > 1 && lastAction.recipient) {
      const people = [];
      for (const action of this.props.group) {
        if (!people.includes(action.recipient)) {
          people.push(action.recipient);
        }
      }
      if (people.length === 1) text.recipient = people[0].displayName();
      else if (people.length === 2) text.recipient = `${people[0].displayName()} and 1 other`;
      else text.recipient = `${people[0].displayName()} and ${people.length - 1} others`;
    }
    if (lastAction.title) text.title = lastAction.title;
    text.date.setUTCSeconds(lastAction.timestamp);
    return text;
  }

  renderActivityContainer() {
    if (this.props.group.length === 1) return null;
    const actions = [];
    for (const action of this.props.group) {
      const date = new Date(0);
      date.setUTCSeconds(action.timestamp);
      actions.push(
        <div
          key={`${action.messageId}-${action.timestamp}`}
          className="activity-list-toggle-item"
        >
          <Flexbox direction="row">
            <div className="action-message">
              {action.recipient ? action.recipient.displayName() : "Someone"}
            </div>
            <div className="spacer" />
            <div className="timestamp">
              {DateUtils.shortTimeString(date)}
            </div>
          </Flexbox>
        </div>
      );
    }
    return (
      <div
        key={`activity-toggle-container`}
        className={`activity-toggle-container ${this.state.collapsed ? "hidden" : ""}`}
      >
        {actions}
      </div>
    );
  }

  render() {
    const lastAction = this.props.group[0];
    let className = "activity-list-item";
    if (!ActivityListStore.hasBeenViewed(lastAction)) className += " unread";
    const text = this._getText();
    let disclosureTriangle = (<div style={{width: "7px"}} />);
    if (this.props.group.length > 1) {
      disclosureTriangle = (
        <DisclosureTriangle
          visible
          collapsed={this.state.collapsed}
          onCollapseToggled={this._onCollapseToggled}
        />
      );
    }
    return (
      <div onClick={() => { this._onClick(lastAction.threadId) }}>
        <Flexbox direction="column" className={className}>
          <Flexbox
            direction="row"
          >
            <div className="activity-icon-container">
              <RetinaImg
                className="activity-icon"
                name={pluginFor(lastAction.pluginId).iconName}
                mode={RetinaImg.Mode.ContentPreserve}
              />
            </div>
            {disclosureTriangle}
            <div className="action-message">
              {text.recipient} {pluginFor(lastAction.pluginId).predicate}:
            </div>
            <div className="spacer" />
            <div className="timestamp">
              {DateUtils.shortTimeString(text.date)}
            </div>
          </Flexbox>
          <div className="title">
            {text.title}
          </div>
        </Flexbox>
        {this.renderActivityContainer()}
      </div>
    );
  }

}

export default ActivityListItemContainer;
