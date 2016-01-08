
class CategoryHelpers

  @categoryLabel: (account) ->
    return "Unknown" unless account

    if account.usesFolders()
      return "Folders"
    else if account.usesLabels()
      return "Labels"
    else
      return "Unknown"

  @categoryIconName: (account) ->
    return "folder.png" unless account

    if account.usesFolders()
      return "folder.png"
    else if account.usesLabels()
      return "tag.png"
    else
      return null

module.exports = CategoryHelpers
