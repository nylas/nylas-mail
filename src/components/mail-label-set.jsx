import React from 'react';
import FocusedPerspectiveStore from '../flux/stores/focused-perspective-store';
import CategoryStore from '../flux/stores/category-store';
import MessageStore from '../flux/stores/message-store';
import AccountStore from '../flux/stores/account-store';
import {MailLabel} from './mail-label';
import Actions from '../flux/actions';
import ChangeLabelsTask from '../flux/tasks/change-labels-task';
import InjectedComponentSet from './injected-component-set';

const LabelComponentCache = {};

export default class MailLabelSet extends React.Component {
  static displayName = 'MailLabelSet';

  static propTypes = {
    thread: React.PropTypes.object.isRequired,
    includeCurrentCategories: React.PropTypes.bool,
  };

  _onRemoveLabel(label) {
    const task = new ChangeLabelsTask({
      thread: this.props.thread,
      labelsToRemove: [label],
    });
    Actions.queueTask(task);
  }

  render() {
    const {thread, includeCurrentCategories} = this.props;
    const labels = [];

    if (AccountStore.accountForId(thread.accountId).usesLabels()) {
      const hidden = CategoryStore.hiddenCategories(thread.accountId);
      let current = FocusedPerspectiveStore.current().categories();

      if (includeCurrentCategories || !current) {
        current = [];
      }

      const ignoredIds = [].concat(hidden, current).map(l=> l.id);
      const ignoredNames = MessageStore.CategoryNamesHiddenByDefault;

      for (const label of thread.sortedCategories()) {
        if (ignoredNames.includes(label.name) || ignoredIds.includes(label.id)) {
          continue;
        }
        if (LabelComponentCache[label.id] === undefined) {
          LabelComponentCache[label.id] = (
            <MailLabel
              label={label}
              key={label.id}
              onRemove={()=> this._onRemoveLabel(label)}/>
          );
        }
        labels.push(LabelComponentCache[label.id]);
      }
    }
    return (
      <InjectedComponentSet
        inline
        containersRequired={false}
        children={labels}
        matching={{role: "Thread:MailLabel"}}
        className="thread-injected-mail-labels"
        exposedProps={{thread: thread}}/>
    );
  }
}
