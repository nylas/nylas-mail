import {PreferencesUIStore, ComponentRegistry, DraftStore} from 'nylas-exports';
import TemplatePicker from './template-picker';
import TemplateStatusBar from './template-status-bar';
import Extension from './template-draft-extension';

module.exports = {
  item: null, // The DOM item the main React component renders into

  activate(state = {}) {
    this.state = state;
    this.preferencesTab = new PreferencesUIStore.TabItem({
      tabId: "Quick Replies",
      displayName: "Quick Replies",
      component: require("./preferences-templates"),
    });
    ComponentRegistry.register(TemplatePicker, {role: 'Composer:ActionButton'});
    ComponentRegistry.register(TemplateStatusBar, {role: 'Composer:Footer'});
    PreferencesUIStore.registerPreferencesTab(this.preferencesTab);
    return DraftStore.registerExtension(Extension);
  },

  deactivate() {
    ComponentRegistry.unregister(TemplatePicker);
    ComponentRegistry.unregister(TemplateStatusBar);
    PreferencesUIStore.unregisterPreferencesTab(this.preferencesTab.sectionId);
    return DraftStore.unregisterExtension(Extension);
  },

  serialize() { return this.state; },
};
