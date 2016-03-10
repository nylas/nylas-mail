import _ from 'underscore';
import GithubUserStore from "./github-user-store";
import {React} from 'nylas-exports';

// Small React component that renders a single Github repository
class GithubRepo extends React.Component {
  static displayName = 'GithubRepo';

  static propTypes = {
    // This component takes a `repo` object as a prop. Listing props is optional
    // but enables nice React warnings when our expectations aren't met
    repo: React.PropTypes.object.isRequired,
  };

  render() {
    const {repo} = this.props;

    return (
      <div className="repo">
        <div className="stars">{repo.stargazers_count}</div>
        <a href={repo.html_url}>{repo.full_name}</a>
      </div>
    );
  }
}

// Small React component that renders the user's Github profile.
class GithubProfile extends React.Component {
  static displayName = 'GithubProfile';

  static propTypes = {
    // This component takes a `profile` object as a prop. Listing props is optional
    // but enables nice React warnings when our expectations aren't met.
    profile: React.PropTypes.object.isRequired,
  }

  render() {
    const {profile} = this.props;

    // Transform the profile's array of repos into an array of React <GithubRepo> elements
    const repoElements = _.map(profile.repos, (repo)=> {
      return <GithubRepo key={repo.id} repo={repo} />
    });

    // Remember - this looks like HTML, but it's actually CJSX, which is converted into
    // Coffeescript at transpile-time. We're actually creating a nested tree of Javascript
    // objects here that *represent* the DOM we want.
    return (
      <div className="profile">
        <img className="logo" src="nylas://github-contact-card/assets/github.png"/>
        <a href={profile.html_url}>{profile.login}</a>
        <div>{repoElements}</div>
      </div>
    );
  }
}

export default class GithubContactCardSection extends React.Component {
  static displayName = 'GithubContactCardSection';

  constructor(props) {
    super(props);
    this.state = this._getStateFromStores();
  }

  componentDidMount() {
    // When our component mounts, start listening to the GithubUserStore.
    // When the store `triggers`, our `_onChange` method will fire and allow
    // us to replace our state.
    this._unsubscribe = GithubUserStore.listen(this._onChange);
  }

  componentWillUnmount() {
    this._unsubscribe();
  }

  _getStateFromStores = ()=> {
    return {
      profile: GithubUserStore.profileForFocusedContact(),
      loading: GithubUserStore.loading(),
    };
  }

  // The data vended by the GithubUserStore has changed. Calling `setState:`
  // will cause React to re-render our view to reflect the new values.
  _onChange = ()=> {
    this.setState(this._getStateFromStores())
  }

  _renderInner() {
    // Handle various loading states by returning early
    if (this.state.loading) {
      return (<div>Loading...</div>);
    }

    if (!this.state.profile) {
      return (<div>No Matching Profile</div>);
    }

    return (
      <GithubProfile profile={this.state.profile} />
    );
  }

  static containerStyles = {
    order: 10,
  }

  render() {
    return (
      <div className="sidebar-github-profile">
        <h2>Github</h2>
        {this._renderInner()}
      </div>
    );
  }
}
