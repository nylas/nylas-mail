import { ComponentRegistry } from 'mailspring-exports';
import SidebarParticipantProfile from './sidebar-participant-profile';
import SidebarRelatedThreads from './sidebar-related-threads';

export function activate() {
  ComponentRegistry.register(SidebarParticipantProfile, { role: 'MessageListSidebar:ContactCard' });
  ComponentRegistry.register(SidebarRelatedThreads, { role: 'MessageListSidebar:ContactCard' });
}

export function deactivate() {
  ComponentRegistry.unregister(SidebarParticipantProfile);
  ComponentRegistry.unregister(SidebarRelatedThreads);
}

export function serialize() {}
