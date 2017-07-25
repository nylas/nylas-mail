import React from 'react';
import OnboardingActions from './onboarding-actions';

const Steps = [
  {
    seen: false,
    id: 'people',
    title: 'Compose with context',
    image: 'feature-people@2x.png',
    description: "Nylas Mail shows you everything about your contacts right inside your inbox. See LinkedIn profiles, Twitter bios, message history, and more.",
    x: 96.6,
    y: 1.3,
    xDot: 93.5,
    yDot: 5.4,
  },
  {
    seen: false,
    id: 'activity',
    title: 'Track opens and clicks',
    image: 'feature-activity@2x.png',
    description: "With activity tracking, you’ll know as soon as someone reads your message. Sending to a group? Nylas Mail shows you which recipients opened your email so you can follow up with precision.",
    x: 12.8,
    y: 1,
    xDot: 15,
    yDot: 5.1,
  },
  {
    seen: false,
    id: 'snooze',
    title: 'Send on your own schedule',
    image: 'feature-snooze@2x.png',
    description: "Snooze emails to return at any time that suits you. Schedule messages to send at the ideal time. Nylas Mail makes it easy to control the fabric of spacetime!",
    x: 5.5,
    y: 23.3,
    xDot: 10,
    yDot: 25.9,
  },
  // {
  //   seen: false,
  //   id: 'composer',
  //   title: 'Eliminate hacky extensions',
  //   image: 'feature-composer@2x.png',
  //   description: "Embed calendar invitations, propose meeting times, use quick reply templates, send mass emails with mail merge, and more—all directly from Nylas Mail’s powerful composer.",
  //   x: 60.95,
  //   y: 66,
  //   xDot: 60.3,
  //   yDot: 65.0,
  // },
];

export default class TutorialPage extends React.Component {
  static displayName = "TutorialPage";

  constructor(props) {
    super(props);

    this.state = {
      appeared: false,
      seen: [],
      current: Steps[0],
    }
  }

  componentDidMount() {
    this._timer = setTimeout(() => {
      this.setState({appeared: true})
    }, 200);
  }

  componentWillUnmount() {
    clearTimeout(this._timer);
  }

  _onBack = () => {
    const nextItem = this.state.seen.pop();
    if (!nextItem) {
      OnboardingActions.moveToPreviousPage();
    } else {
      this.setState({current: nextItem});
    }
  }

  _onNextUnseen = () => {
    const nextSeen = [].concat(this.state.seen, [this.state.current]);
    const nextItem = Steps.find(s => !nextSeen.includes(s));
    if (nextItem) {
      this.setState({current: nextItem, seen: nextSeen});
    } else {
      OnboardingActions.moveToPage('account-choose');
    }
  }

  _onMouseOverOverlay = (event) => {
    const item = Steps.find(i => i.id === event.target.id);
    if (item) {
      if (!this.state.seen.includes(item)) {
        this.state.seen.push(item);
      }
      this.setState({current: item});
    }
  }

  render() {
    const {current, seen, appeared} = this.state;

    return (
      <div className={`page tutorial appeared-${appeared}`}>
        <div className="tutorial-container">
          <div className="left">
            <div className="screenshot">
              {Steps.map((step) =>
                <div
                  key={step.id}
                  id={step.id}
                  className={`overlay ${seen.includes(step) ? 'seen' : ''} ${current === step ? 'expanded' : ''}`}
                  style={{left: `${step.xDot}%`, top: `${step.yDot}%`}}
                  onMouseOver={this._onMouseOverOverlay}
                >
                  <div
                    className="overlay-content"
                    style={{backgroundPosition: `${step.x}% ${step.y}%`}}
                  />
                </div>
              )}
            </div>
          </div>
          <div className="right">
            <img src={`nylas://onboarding/assets/${current.image}`} style={{zoom: 0.5, margin: 'auto'}} role="presentation" />
            <h2>{current.title}</h2>
            <p>{current.description}</p>
          </div>
        </div>
        <div className="footer">
          <button key="prev" className="btn btn-large btn-prev" onClick={this._onBack}>
            Back
          </button>
          <button key="next" className="btn btn-large btn-next" onClick={this._onNextUnseen}>
            {seen.length < Steps.length ? 'Next' : 'Get Started'}
          </button>
        </div>
      </div>
    );
  }
}
