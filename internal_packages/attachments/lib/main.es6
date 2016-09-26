import {
  ComponentRegistry,
} from 'nylas-exports';

import AttachmentComponent from "./attachment-component";
import ImageAttachmentComponent from "./image-attachment-component";

export function activate() {
  ComponentRegistry.register(AttachmentComponent, {role: 'Attachment'})
  ComponentRegistry.register(ImageAttachmentComponent, {role: 'Attachment:Image'})
}

export function deactivate() {
  ComponentRegistry.unregister(AttachmentComponent);
  ComponentRegistry.unregister(ImageAttachmentComponent);
}
