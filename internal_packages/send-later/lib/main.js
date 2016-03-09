/** @babel */
import {ComponentRegistry} from 'nylas-exports'
import SendLaterButton from './send-later-button'
import SendLaterStore from './send-later-store'
import SendLaterStatus from './send-later-status'

export function activate() {
  this.store = new SendLaterStore()

  this.store.activate()
  ComponentRegistry.register(SendLaterButton, {role: 'Composer:ActionButton'})
  ComponentRegistry.register(SendLaterStatus, {role: 'DraftList:DraftStatus'})
}

export function deactivate() {
  ComponentRegistry.unregister(SendLaterButton)
  ComponentRegistry.unregister(SendLaterStatus)
  this.store.deactivate()
}

export function serialize() {

}

