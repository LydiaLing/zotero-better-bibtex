Exporter = require('./exporter.coffee')
debug = require('./debug.coffee')

scrub = (item) ->
  delete item.__citekey__
  delete item.libraryID
  delete item.key
  delete item.uniqueFields
  delete item.dateAdded
  delete item.dateModified
  delete item.uri
  delete item.attachmentIDs

  delete item.collections

  item.attachments = ({ path: attachment.localPath, title: attachment.title, mimeType: attachment.mimeType, url: attachment.url } for attachment in item.attachments || [])
  item.notes = (note.note.trim() for note in item.notes || [])

  item.tags = (tag.tag for tag in item.tags || [])
  item.tags.sort()

  for own attr, val of item
    continue if typeof val is 'number'
    continue if Array.isArray(val) and val.length != 0

    switch typeof val
      when 'string'
        delete item[attr] if val.trim() == ''
      when 'undefined'
        delete item[attr]

  citekeys = Zotero.BetterBibTeX.keymanager.alternates(item)
  switch
    when !citekeys or citekeys.length == 0 then
    when citekeys.length == 1
      item.__citekey__ = citekeys[0]
    else
      item.__citekeys__ = citekeys

  return item

Translator.detectImport = ->
  debug('BetterBibTeX JSON.detect: start')
  json = ''
  while (str = Zotero.read(0x100000)) != false
    json += str
    throw 'Unlikely to be JSON' if json[0] != '{'

  # a failure to parse will throw an error which a) is actually logged, and b) will count as "false"
  data = JSON.parse(json)

  throw 'No config section' unless data.config
  throw "ID mismatch: got #{data.config.id}, expected #{Translator.header.translatorID}" unless data.config.id == Translator.header.translatorID
  throw 'No items' unless data.items && data.items.length
  return true

Translator.doImport = ->
  json = ''
  while (str = Zotero.read(0x100000)) != false
    json += str

  data = JSON.parse(json)

  for i in data.items
    ### works around https://github.com/Juris-M/zotero/issues/20 ###
    delete i.multi.main if i.multi

    item = new Zotero.Item()
    for own prop, value of i
      item[prop] = value
    for att in item.attachments || []
      delete att.path if att.url
    item.complete()

Translator.doExport = ->
  Exporter = new Exporter()

  data = {
    config: {
      id: Translator.header.translatorID
      label: Translator.header.label
      release: Translator.release
      preferences: Translator.preferences
      options: Translator.options
    }
    collections: Exporter.collections
    items: []
    cache: {
      # no idea why this doesn't work anymore. The security manager won't let me call toJSON on this anymore
      # activity: Zotero.BetterBibTeX.cache.stats()
    }
  }

  while item = Zotero.nextItem()
    data.items.push(scrub(item))

  if Translator.preferences.debug
    data.keymanager = Zotero.BetterBibTeX.keymanager.cache()
    data.cache.items = Zotero.BetterBibTeX.cache.dump((item.itemID for item in data.items))

  Zotero.write(JSON.stringify(data, null, '  '))
  return
