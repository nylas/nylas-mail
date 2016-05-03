_ = require 'underscore'
path = require 'path'
LessCache = require 'less-cache'

fileCacheImportPaths = null

# {LessCache} wrapper used by {ThemeManager} to read stylesheets.
module.exports =
class LessCompileCache
  constructor: ({configDirPath, resourcePath, importPaths}) ->
    @lessSearchPaths = [
      path.join(resourcePath, 'static', 'variables')
      path.join(resourcePath, 'static')
    ]

    if importPaths?
      importPaths = importPaths.concat(@lessSearchPaths)
    else
      importPaths = @lessSearchPaths

    @cache = new LessCache
      cacheDir: path.join(configDirPath, 'compile-cache', 'less')
      importPaths: importPaths
      resourcePath: resourcePath
      fallbackDir: path.join(resourcePath, 'less-compile-cache')

  # Setting the import paths is a VERY expensive operation (200ms +)
  # because it walks the entire file tree and does a file state for each
  # and every importPath. If we already have the imports, then load it
  # from our backend FileListCache.
  setImportPaths: (importPaths=[]) ->
    fileCache = NylasEnv.fileListCache()
    fileCacheImportPaths = fileCache.lessCacheImportPaths ? []
    fullImportPaths = importPaths.concat(@lessSearchPaths)
    if not _.isEqual(fullImportPaths, fileCacheImportPaths)
      @cache.setImportPaths(fullImportPaths)
      fileCache.lessCacheImportPaths = fullImportPaths

  read: (stylesheetPath) ->
    @cache.readFileSync(stylesheetPath)

  cssForFile: (stylesheetPath, lessContent) ->
    @cache.cssForFile(stylesheetPath, lessContent)
