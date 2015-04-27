```
    DraftStore.registerExtension(Extension)

```

```

module.exports =
  warningsForSending: (draft) ->
    warnings = []
    if draft.body.search(/<code[^>]*empty[^>]*>/i) > 0
      warnings.push("with an empty template area")
    warnings
  
  finalizeSessionBeforeSending: (session) ->
    body = session.draft().body
    clean = body.replace(/<\/?code[^>]*>/g, '')
    if body != clean
      session.changes.add(body: clean)

```