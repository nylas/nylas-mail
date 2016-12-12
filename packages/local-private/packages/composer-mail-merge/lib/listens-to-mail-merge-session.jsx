/* eslint no-prototype-builtins: 0 */
import React, {Component, PropTypes} from 'react';
import {mailMergeSessionForDraft} from './mail-merge-draft-editing-session'


export default function ListensToMailMergeSession(ComposedComponent) {
  return class extends Component {
    static displayName = ComposedComponent.displayName

    static containerRequired = false

    static propTypes = {
      session: PropTypes.object,
      draftClientId: PropTypes.string,
      ...ComposedComponent.propTypes,
    }

    constructor(props) {
      super(props)
      this.unlisten = () => {}
      this.state = {
        mailMergeSession: mailMergeSessionForDraft(props.draftClientId, props.session),
      };
    }

    componentDidMount() {
      const {mailMergeSession} = this.state;
      if (mailMergeSession) {
        this.unlisten = mailMergeSession.listen(() => {
          this.setState({mailMergeSession})
        });
      }
    }

    componentWillUnmount() {
      this.unlisten();
    }

    focus() {
      if (this.refs.composed) {
        this.refs.composed.focus()
      }
    }

    render() {
      const {mailMergeSession} = this.state;

      if (!mailMergeSession) {
        return <ComposedComponent {...this.props} sessionState={{}} />
      }
      const componentProps = {
        ...this.props,
        mailMergeSession: mailMergeSession,
        sessionState: mailMergeSession.state,
      }
      if (Component.isPrototypeOf(ComposedComponent)) {
        componentProps.ref = 'composed'
      }
      return (
        <ComposedComponent {...componentProps} />
      )
    }
  }
}
