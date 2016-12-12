import {
  TaskRegistry,
  ExtensionRegistry,
  ComponentRegistry,
  CustomContenteditableComponents,
} from 'nylas-exports'

import MailMergeButton from './mail-merge-button'
import MailMergeContainer from './mail-merge-container'
import SendManyDraftsTask from './send-many-drafts-task'
import MailMergeSendButton from './mail-merge-send-button'
import * as ComposerExtension from './mail-merge-composer-extension'
import MailMergeSubjectTextField from './mail-merge-subject-text-field'
import MailMergeBodyToken from './mail-merge-body-token'
import MailMergeParticipantsTextField from './mail-merge-participants-text-field'

export function activate() {
  TaskRegistry.register('SendManyDraftsTask', () => SendManyDraftsTask)

  ComponentRegistry.register(MailMergeContainer,
    {role: 'Composer:ActionBarWorkspace'});

  ComponentRegistry.register(MailMergeButton,
    {role: 'Composer:ActionButton'});

  ComponentRegistry.register(MailMergeSendButton,
    {role: 'Composer:SendActionButton'});

  ComponentRegistry.register(MailMergeParticipantsTextField,
    {role: 'Composer:ParticipantsTextField'});

  ComponentRegistry.register(MailMergeSubjectTextField,
    {role: 'Composer:SubjectTextField'});

  CustomContenteditableComponents.register('MailMergeBodyToken', MailMergeBodyToken)

  ExtensionRegistry.Composer.register(ComposerExtension)
}

export function deactivate() {
  TaskRegistry.unregister('SendManyDraftsTask')
  ComponentRegistry.unregister(MailMergeContainer)
  ComponentRegistry.unregister(MailMergeButton)
  ComponentRegistry.unregister(MailMergeSendButton)
  ComponentRegistry.unregister(MailMergeParticipantsTextField)
  ComponentRegistry.unregister(MailMergeSubjectTextField)
  CustomContenteditableComponents.unregister('MailMergeBodyToken');
  ExtensionRegistry.Composer.unregister(ComposerExtension)
}

export function serialize() {

}
