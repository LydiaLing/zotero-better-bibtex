Exporter = require('./exporter.coffee')
debug = require('./debug.coffee')

Mode =
  gitbook: (items) ->
    citations = ("{{ \"#{item.__citekey__}\" | cite }}" for item in items)
    Zotero.write(citations.join(''))

  atom: (items) ->
    keys = (item.__citekey__ for item in items)
    if keys.length == 1
      Zotero.write("[](#@#{keys[0]})")
    else
      Zotero.write("[](?@#{keys.join(',')})")

  latex: (items) ->
    keys = (item.__citekey__ for item in items)

    cmd = "#{Translator.preferences.citeCommand}".trim()
    if cmd == ''
      Zotero.write(keys.join(','))
    else
      Zotero.write("\\#{cmd}{#{keys.join(',')}}")

  citekeys: (items) ->
    keys = (item.__citekey__ for item in items)
    Zotero.write(keys.join(','))

  pandoc: (items) ->
    keys = (item.__citekey__ for item in items)
    keys = keys.join('; ')
    keys = "[#{keys}]" if Translator.preferences.quickCopyPandocBrackets
    Zotero.write(keys)

  orgmode: (items) ->
    for item in items
      m = item.uri.match(/\/(users|groups)\/([0-9]+|(local\/[^\/]+))\/items\/([A-Z0-9]{8})$/)
      throw "Malformed item uri #{item.uri}" unless m

      type = m[1]
      groupID = m[2]
      key = m[4]

      switch type
        when 'users'
          debug("Link to synced item #{item.uri}") unless groupID.indexOf('local') == 0
          id = "0_#{key}"
        when 'groups'
          throw "Missing groupID in #{item.uri}" unless groupID
          id = "#{groupID}~#{key}"

      Zotero.write("[[zotero://select/items/#{id}][@#{item.__citekey__}]]")

Translator.doExport = ->
  Exporter = new Exporter()
  items = []
  while item = Exporter.nextItem()
    items.push(item)

  mode = Mode["#{Translator.options.quickCopyMode}"] || Mode["#{Translator.preferences.quickCopyMode}"]
  if mode
    mode.call(null, items)
  else
    throw "Unsupported Quick Copy format '#{Translator.options.quickCopyMode || Translator.preferences.quickCopyMode}'"
