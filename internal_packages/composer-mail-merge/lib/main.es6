import {ExtensionRegistry, ComponentRegistry} from 'nylas-exports'
import MailMergeButton from './mail-merge-button'
import MailMergeSendButton from './mail-merge-send-button'
import MailMergeParticipantsTextField from './mail-merge-participants-text-field'
import MailMergeContainer from './mail-merge-container'
import * as ComposerExtension from './mail-merge-composer-extension'


export function activate() {
  ComponentRegistry.register(MailMergeContainer,
    {role: 'Composer:Footer'});

  ComponentRegistry.register(MailMergeButton,
    {role: 'Composer:ActionButton'});

  ComponentRegistry.register(MailMergeSendButton,
    {role: 'Composer:SendActionButton'});

  ComponentRegistry.register(MailMergeParticipantsTextField,
    {role: 'Composer:ParticipantsTextField'});

  ExtensionRegistry.Composer.register(ComposerExtension)
}

export function deactivate() {
  ComponentRegistry.unregister(MailMergeContainer)
  ComponentRegistry.unregister(MailMergeButton)
  ComponentRegistry.unregister(MailMergeSendButton)
  ComponentRegistry.unregister(MailMergeParticipantsTextField)
  ExtensionRegistry.Composer.unregister(ComposerExtension)
}

export function serialize() {

}
