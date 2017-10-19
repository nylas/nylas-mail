import {
  AccountStore,
  CategoryStore,
  React,
  Actions,
  ChangeRoleMappingTask,
} from 'mailspring-exports';

import CategorySelection from './category-selection';

const SELECTABLE_ROLES = ['inbox', 'sent', 'drafts', 'spam', 'archive', 'trash'];

export default class PreferencesCategoryMapper extends React.Component {
  constructor() {
    super();
    this.state = this._getStateFromStores();
  }

  componentDidMount() {
    this._unlisten = CategoryStore.listen(() => {
      this.setState(this._getStateFromStores());
    });
  }

  componentWillUnmount() {
    if (this._unlisten) {
      this._unlisten();
    }
  }

  _getStateFromStores() {
    const assignments = {};
    const all = {};

    for (const cat of CategoryStore.categories()) {
      all[cat.accountId] = all[cat.accountId] || [];
      all[cat.accountId].push(cat);
      if (SELECTABLE_ROLES.includes(cat.role)) {
        assignments[cat.accountId] = assignments[cat.accountId] || {};
        assignments[cat.accountId][cat.role] = cat;
      }
    }
    return { assignments, all };
  }

  _onCategorySelection = async (account, role, category) => {
    // our state will be updated as soon as the sync worker commits the change
    Actions.queueTask(
      new ChangeRoleMappingTask({
        role: role,
        path: category.path,
        accountId: account.id,
      })
    );
  };

  _renderRoleSection = (account, role) => {
    if (account.provider === 'gmail' && role === 'archive') {
      return false;
    }
    return (
      <div className="role-section" key={`${account.id}-${role}`}>
        <div className="col-left">{`${role[0].toUpperCase()}${role.substr(1)}`}:</div>
        <div className="col-right">
          <CategorySelection
            all={this.state.all[account.id]}
            current={this.state.assignments[account.id][role]}
            onSelect={category => this._onCategorySelection(account, role, category)}
            accountUsesLabels={account.usesLabels()}
          />
        </div>
      </div>
    );
  };

  render() {
    return (
      <div className="category-mapper-container">
        {AccountStore.accounts().map(account => (
          <div key={account.id}>
            <div className="account-section-title">{account.label}</div>
            {SELECTABLE_ROLES.map(role => this._renderRoleSection(account, role))}
          </div>
        ))}
      </div>
    );
  }
}
