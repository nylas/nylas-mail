{ComposerExtension, AccountStore, DOMUtils} = require 'nylas-exports'
_ = require 'underscore'
spellchecker = require('spellchecker')
remote = require('remote')
MenuItem = remote.require('menu-item')

SpellcheckCache = {}

class SpellcheckComposerExtension extends ComposerExtension

  @isMisspelled: (word) ->
    SpellcheckCache[word] ?= spellchecker.isMisspelled(word)
    SpellcheckCache[word]

  @onInput: (editableNode) =>
    @walkTree(editableNode)

  @onShowContextMenu: (editableNode, selection, event, menu) =>
    range = DOMUtils.Mutating.getRangeAtAndSelectWord(selection, 0)
    word = range.toString()
    if @isMisspelled(word)
      corrections = spellchecker.getCorrectionsForMisspelling(word)
      if corrections.length > 0
        corrections.forEach (correction) =>
          menu.append(new MenuItem({
            label: correction,
            click: @applyCorrection.bind(@, editableNode, range, selection, correction)
          }))
      else
        menu.append(new MenuItem({ label: 'No Guesses Found', enabled: false}))

      menu.append(new MenuItem({ type: 'separator' }))
      menu.append(new MenuItem({
        label: 'Learn Spelling',
        click: @learnSpelling.bind(@, editableNode, word)
      }))
      menu.append(new MenuItem({ type: 'separator' }))

  @applyCorrection: (editableNode, range, selection, correction) =>
    DOMUtils.Mutating.applyTextInRange(range, selection, correction)
    @walkTree(editableNode)

  @learnSpelling: (editableNode, word) =>
    spellchecker.add(word)
    delete SpellcheckCache[word]
    @walkTree(editableNode)

  @walkTree: (editableNode) =>
    treeWalker = document.createTreeWalker(editableNode, NodeFilter.SHOW_TEXT)

    nodeList = []
    selection = document.getSelection()
    selectionSnapshot =
      anchorNode: selection.anchorNode
      anchorOffset: selection.anchorOffset
      focusNode: selection.focusNode
      focusOffset: selection.focusOffset
    selectionImpacted = false

    while (treeWalker.nextNode())
      nodeList.push(treeWalker.currentNode)

    while (node = nodeList.pop())
      str = node.textContent

      # https://regex101.com/r/bG5yC4/1
      wordRegexp = /(\w[\w'’-]*\w|\w)/g

      while ((match = wordRegexp.exec(str)) isnt null)
        spellingSpan = null
        if node.parentNode and node.parentNode.nodeName is 'SPELLING'
          if match[0] is str
            spellingSpan = node.parentNode
          else
            node.parentNode.classList.remove('misspelled')

        misspelled = @isMisspelled(match[0])
        markedAsMisspelled = spellingSpan?.classList.contains('misspelled')

        if misspelled and not markedAsMisspelled
          # The insertion point is currently at the end of this misspelled word.
          # Do not mark it until the user types a space or leaves.
          if selectionSnapshot.focusNode is node and selectionSnapshot.focusOffset is match.index + match[0].length
            continue

          if spellingSpan
            spellingSpan.classList.add('misspelled')
          else
            if match.index is 0
              matchNode = node
            else
              matchNode = node.splitText(match.index)
            afterMatchNode = matchNode.splitText(match[0].length)

            spellingSpan = document.createElement('spelling')
            spellingSpan.classList.add('misspelled')
            spellingSpan.innerText = match[0]
            matchNode.parentNode.replaceChild(spellingSpan, matchNode)

            for prop in ['anchor', 'focus']
              if selectionSnapshot["#{prop}Node"] is node
                if selectionSnapshot["#{prop}Offset"] > match.index + match[0].length
                  selectionImpacted = true
                  selectionSnapshot["#{prop}Node"] = afterMatchNode
                  selectionSnapshot["#{prop}Offset"] -= match.index + match[0].length
                else if selectionSnapshot["#{prop}Offset"] > match.index
                  selectionImpacted = true
                  selectionSnapshot["#{prop}Node"] = spellingSpan.childNodes[0]
                  selectionSnapshot["#{prop}Offset"] -= match.index

            nodeList.unshift(afterMatchNode)
            break

        else if not misspelled and markedAsMisspelled
          spellingSpan.classList.remove('misspelled')

    if selectionImpacted
      selection.setBaseAndExtent(selectionSnapshot.anchorNode, selectionSnapshot.anchorOffset, selectionSnapshot.focusNode, selectionSnapshot.focusOffset)

  @finalizeSessionBeforeSending: (session) ->
    body = session.draft().body
    clean = body.replace(/<\/?spelling[^>]*>/g, '')
    if body != clean
      session.changes.add(body: clean)

SpellcheckComposerExtension.SpellcheckCache = SpellcheckCache

module.exports = SpellcheckComposerExtension
