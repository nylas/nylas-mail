/** @babel */
import {ComponentRegistry} from 'nylas-exports'
import ParticipantProfileStore from './participant-profile-store'
import SidebarParticipantProfile from './sidebar-participant-profile'
import SidebarRelatedThreads from './sidebar-related-threads'

export function activate() {
  ParticipantProfileStore.activate()
  ComponentRegistry.register(SidebarParticipantProfile, {role: 'MessageListSidebar:ContactCard'})
  ComponentRegistry.register(SidebarRelatedThreads, {role: 'MessageListSidebar:ContactCard'})
}

export function deactivate() {
  ComponentRegistry.unregister(SidebarParticipantProfile)
  ComponentRegistry.unregister(SidebarRelatedThreads)
  ParticipantProfileStore.deactivate()
}

export function serialize() {

}

