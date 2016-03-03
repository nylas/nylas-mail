/** @babel */
import {ComponentRegistry} from 'nylas-exports'
import SendLaterPopover from './send-later-popover'
import SendLaterStore from './send-later-store'
import SendLaterStatus from './send-later-status'

export function activate() {
  this.store = new SendLaterStore()

  this.store.activate()
  ComponentRegistry.register(SendLaterPopover, {role: 'Composer:ActionButton'})
  ComponentRegistry.register(SendLaterStatus, {role: 'DraftList:DraftStatus'})
}

export function deactivate() {
  ComponentRegistry.unregister(SendLaterPopover)
  ComponentRegistry.unregister(SendLaterStatus)
  this.store.deactivate()
}

export function serialize() {

}

