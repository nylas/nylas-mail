import React from 'react';

import {DisclosureTriangle,
  Flexbox,
  RetinaImg} from 'nylas-component-kit';
import {Utils} from 'nylas-exports';

const plugins = {
  "1hnytbkg4wd1ahodatwxdqlb5": {
    name: "open",
    predicate: "opened",
    iconName: "icon-activity-mailopen.png",
  },
  "a1ec1s3ieddpik6lpob74hmcq": {
    name: "link",
    predicate: "clicked",
    iconName: "icon-activity-linkopen.png",
  },
};


class ActivityListItemContainer extends React.Component {

  static displayName = 'ActivityListItemContainer';

  static propTypes = {
    group: React.PropTypes.array,
  };

  constructor() {
    super();
    this.state = {
      collapsed: true,
    };
  }

  _getText() {
    const text = {
      recipient: "Someone",
      title: "(No Subject)",
      date: new Date(0),
    };
    const lastAction = this.props.group[0];
    if (this.props.group.length === 1 && lastAction.recipients.length === 1) {
      text.recipient = lastAction.recipients[0].name;
    } else if (this.props.group.length > 1) {
      const people = [];
      for (const action of this.props.group) {
        for (const person of action.recipients) {
          if (people.indexOf(person) === -1) {
            people.push(person);
          }
        }
      }
      if (people.length === 1) text.recipient = people[0].name;
      else if (people.length === 2) text.recipient = `${people[0].name} and 1 other`;
      else text.recipient = `${people[0].name} and ${people.length - 1} others`;
    }
    if (lastAction.title) text.title = lastAction.title;
    text.date.setUTCSeconds(lastAction.timestamp);
    return text;
  }

  _hasBeenViewed(action) {
    if (!NylasEnv.savedState.activityListViewed) return false;
    return action.timestamp > NylasEnv.savedState.activityListViewed;
  }

  renderActivityContainer() {
    if (this.props.group.length === 1) return null;
    const actions = [];
    for (const action of this.props.group) {
      const date = new Date(0);
      date.setUTCSeconds(action.timestamp);
      actions.push(
        <div key={`${action.messageId}-${action.timestamp}`}
          className="activity-list-toggle-item">
          <Flexbox direction="row">
            <div className="action-message">
              {action.recipients.length === 1 ? action.recipients[0].name : "Someone"}
            </div>
            <div className="spacer"></div>
            <div className="timestamp">
              {Utils.shortTimeString(date)}
            </div>
          </Flexbox>
        </div>
      );
    }
    return (
      <div
        key={`activity-toggle-container`}
        className={`activity-toggle-container ${this.state.collapsed ? "hidden" : ""}`}>
        {actions}
      </div>
    );
  }

  render() {
    const lastAction = this.props.group[0];
    let className = "activity-list-item";
    if (this._hasBeenViewed(lastAction)) className += " unread";
    const text = this._getText();
    let disclosureTriangle = (<div style={{width: "7px"}}></div>);
    if (this.props.group.length > 1) {
      disclosureTriangle = (<DisclosureTriangle
                              visible
                              collapsed={this.state.collapsed}
                              onCollapseToggled={() => {this.setState({collapsed: !this.state.collapsed})}} />);
    }
    return (
      <div>
        <Flexbox direction="column" className={className}>
          <Flexbox
            direction="row">
            <RetinaImg
              name={plugins[lastAction.pluginId].iconName}
              className="activity-icon"
              mode={RetinaImg.Mode.ContentDark} />
            {disclosureTriangle}
            <div className="action-message">
              {text.recipient} {plugins[lastAction.pluginId].predicate}:
            </div>
            <div className="spacer"></div>
            <div className="timestamp">
              {Utils.shortTimeString(text.date)}
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
