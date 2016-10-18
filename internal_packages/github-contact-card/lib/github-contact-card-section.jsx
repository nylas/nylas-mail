import _ from 'underscore';
import {React} from 'nylas-exports';
import GithubUserStore from "./github-user-store";

// Small React component that renders a single Github repository
const GithubRepo = function GithubRepo(props) {
  const {repo} = props;

  return (
    <div className="repo">
      <div className="stars">{repo.stargazers_count}</div>
      <a href={repo.html_url}>{repo.full_name}</a>
    </div>
  );
}
GithubRepo.propTypes = {
  // This component takes a `repo` object as a prop. Listing props is optional
  // but enables nice React warnings when our expectations aren't met
  repo: React.PropTypes.object.isRequired,
};

// Small React component that renders the user's Github profile.
const GithubProfile = function GithubProfile(props) {
  const {profile} = props;

  // Transform the profile's array of repos into an array of React <GithubRepo> elements
  const repoElements = _.map(profile.repos, (repo) => {
    return <GithubRepo key={repo.id} repo={repo} />
  });

  // Remember - this looks like HTML, but it's actually CJSX, which is converted into
  // Coffeescript at transpile-time. We're actually creating a nested tree of Javascript
  // objects here that *represent* the DOM we want.
  return (
    <div className="profile">
      <img className="logo" alt="github logo" src="nylas://github-contact-card/assets/github.png" />
      <a href={profile.html_url}>{profile.login}</a>
      <div>{repoElements}</div>
    </div>
  );
}
GithubProfile.propTypes = {
  // This component takes a `profile` object as a prop. Listing props is optional
  // but enables nice React warnings when our expectations aren't met.
  profile: React.PropTypes.object.isRequired,
}

export default class GithubContactCardSection extends React.Component {
  static displayName = 'GithubContactCardSection';

  static containerStyles = {
    order: 10,
  }

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

  _getStateFromStores = () => {
    return {
      profile: GithubUserStore.profileForFocusedContact(),
      loading: GithubUserStore.loading(),
    };
  }

  // The data vended by the GithubUserStore has changed. Calling `setState:`
  // will cause React to re-render our view to reflect the new values.
  _onChange = () => {
    this.setState(this._getStateFromStores())
  }

  _renderInner() {
    // Handle various loading states by returning early
    if (this.state.loading) {
      return (<div className="pending">Loading...</div>);
    }

    if (!this.state.profile) {
      return (<div className="pending">No Matching Profile</div>);
    }

    return (
      <GithubProfile profile={this.state.profile} />
    );
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
