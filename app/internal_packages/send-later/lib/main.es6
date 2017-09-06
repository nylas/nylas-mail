import {ComponentRegistry} from 'nylas-exports';
import {HasTutorialTip} from 'nylas-component-kit';
import SendLaterButton from './send-later-button';
import SendLaterStatus from './send-later-status';

const SendLaterButtonWithTip = HasTutorialTip(SendLaterButton, {
  title: "Send on your own schedule",
  instructions: "Schedule this message to send at the ideal time. N1 makes it easy to control the fabric of spacetime!",
});

export function activate() {
  ComponentRegistry.register(SendLaterButtonWithTip, {role: 'Composer:ActionButton'})
  ComponentRegistry.register(SendLaterStatus, {role: 'DraftList:DraftStatus'})
}

export function deactivate() {
  ComponentRegistry.unregister(SendLaterButtonWithTip)
  ComponentRegistry.unregister(SendLaterStatus)
}

export function serialize() {

}
