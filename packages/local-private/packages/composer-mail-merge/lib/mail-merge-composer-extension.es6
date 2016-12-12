import * as Handlers from './mail-merge-token-dnd-handlers'

export const name = 'MailMergeComposerExtension'

export {
  onDragOver,
  shouldAcceptDrop,
} from './mail-merge-token-dnd-handlers'

export const onDrop = Handlers.onDrop.bind(null, 'body')
