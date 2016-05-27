import React from 'react';
import OnboardingActions from './onboarding-actions';

const Steps = [
  {
    seen: false,
    id: 'schedule',
    title: 'Time is everything',
    image: 'feature-people@2x.png',
    description: 'Snooze emails to any time that suits you. Schedule emails to be sent later. With Nylas Pro, you are in th control of email spacetime.',
    x: 80,
    y: 4.9,
  },
  {
    seen: false,
    id: 'read-receipts',
    title: 'Time is everything',
    image: 'feature-snooze@2x.png',
    description: 'Snooze emails to any time that suits you. Sechedule emails to be sent later. With Nylas Pro, you are in th control of email spacetime.',
    x: 91,
    y: 4.9,
  },
  {
    seen: false,
    id: 'activity',
    title: 'Track Activity',
    image: 'feature-activity@2x.png',
    description: 'Snooze emails to any time that suits you. Schedule emails to be sent later. With Nylas Pro, you are in th control of email spacetime.',
    x: 12.9,
    y: 17,
  },
  {
    seen: false,
    id: 'mail-merge',
    title: 'Composer Power',
    image: 'feature-composer@2x.png',
    description: 'Snooze emails to any time that suits you. Sechedule emails to be sent later. With Nylas Pro, you are in th control of email spacetime.',
    x: 57,
    y: 82,
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
                  style={{left: `${step.x}%`, top: `${step.y}%`}}
                  onMouseOver={this._onMouseOverOverlay}
                >
                  <div
                    className="overlay-content"
                    style={{backgroundPosition: `${step.x - 3.0}% ${step.y - 3.0}%`}}
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
