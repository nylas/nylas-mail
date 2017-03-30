import {
  AccountStore,
  Category,
  DatabaseStore,
  NylasAPI,
  NylasAPIRequest,
  React,
} from 'nylas-exports'
import CategorySelection from './category-selection'


const ROLES = ['inbox', 'sent', 'drafts', 'spam', 'trash']

export default class PreferencesCategoryMapper extends React.Component {
  constructor() {
    super()
    this.state = {ready: false}
    this._mounted = false
    this._populateRoleAssignments()
  }

  componentDidMount() {
    this._mounted = true
    this._populateRoleAssignments()
  }

  componentWillUnmount() {
    this._mounted = false
  }

  async _populateRoleAssignments() {
    const roleAssignment = {}
    await Promise.all(ROLES.map(async (role) => {
      const existingAssignments = await DatabaseStore.findAll(Category).where([
        Category.attributes.name.equal(role),
      ])
      for (const category of existingAssignments) {
        const {accountId} = category;
        if (!roleAssignment[accountId]) {
          roleAssignment[accountId] = {}
        }
        roleAssignment[accountId][role] = category
      }
    }))

    if (this._mounted) {
      this.setState({ready: true, roleAssignment})
    }
  }

  _onCategorySelection = async (account, role, category) => {
    const {roleAssignment} = this.state;

    const originalRole = category.name
    category.name = role
    await DatabaseStore.inTransaction(t => t.persistModel(category))

    const originalCategory = roleAssignment[account.id][role]
    roleAssignment[account.id][role] = category
    this.setState({roleAssignment})

    try {
      const request = new NylasAPIRequest({
        api: NylasAPI,
        options: {
          path: `/${category.displayType()}s/${category.id}`,
          accountId: category.accountId,
          method: "PUT",
          body: {role},
        },
      })
      await request.run()
    } catch (err) {
      err.message = `Could not set ${category.displayName} as ${role} ${category.displayType()}: ${err.message}`
      NylasEnv.reportError(err)
      NylasEnv.showErrorDialog(err.message, {detail: err.stack})

      // Revert optimistic changes
      category.name = originalRole
      await DatabaseStore.inTransaction(t => t.persistModel(category))
      roleAssignment[account.id][role] = originalCategory
      this.setState({roleAssignment})
    }
  }

  _renderAccountSection = (account) => {
    const roleSections = ROLES.map(role => this._renderRoleSection(account, role))
    return (
      <div>
        <div className="account-section-title">{account.label}</div>
        {roleSections}
      </div>
    )
  }

  _renderRoleSection = (account, role) => {
    return (
      <div className="role-section">
        <div className="col-left">{role}:</div>
        <div className="col-right">
          <CategorySelection
            account={account}
            currentCategory={this.state.roleAssignment[account.id][role]}
            onSelect={category => this._onCategorySelection(account, role, category)}
          />
        </div>
      </div>
    )
  }

  render() {
    if (!this.state.ready) {
      return <span />
    }

    const accountSections = AccountStore.accounts().map(this._renderAccountSection)

    return (
      <div className="category-mapper-container">
        {accountSections}
      </div>
    )
  }
}
