import React from 'react';
import OnboardingActions from './onboarding-actions';

const Steps = [
  {
    seen: false,
    id: 'people',
    title: 'Compose with context',
    image: 'feature-people@2x.png',
    description: "N1 shows you everything about your contacts right inside your inbox. See LinkedIn profiles, Twitter bios, and more.",
    x: 97,
    y: -1.9,
    xDot: 93,
    yDot: 4.9,
  },
  {
    seen: false,
    id: 'read-receipts',
    title: 'Track activity',
    image: 'feature-snooze@2x.png',
    description: "With activity tracking, you'll know as soon as someone reads your message. Sending to a group? We'll show which recipients opened your email, so you can follow up with precision.",
    x: 10,
    y: -1.9,
    xDot: 14.6,
    yDot: 4.9,
  },
  {
    seen: false,
    id: 'snooze',
    title: 'Time is everything',
    image: 'feature-activity@2x.png',
    description: "Snooze emails to any time that suits you. Schedule emails to be sent at the ideal time. N1 makes it easy to control the fabric of spacetime.",
    x: 22,
    y: 39.9,
    xDot: 25,
    yDot: 39.9,
  },
  {
    seen: false,
    id: 'composer-power',
    title: 'Composer Power',
    image: 'feature-composer@2x.png',
    description: "Use N1's powerful composer to embed calendar invitations, propose times to meet with recipients, insert templates, and more.",
    x: 82.5,
    y: 93,
    xDot: 78.7,
    yDot: 82.5,
  },
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
      OnboardingActions.moveToPage('authenticate');
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
                  >
                  </div>
                </div>
              )}
            </div>
          </div>
          <div className="right">
            <img src={`nylas://onboarding/assets/${current.image}`} style={{zoom: 0.6, margin: 'auto'}} role="presentation" />
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
