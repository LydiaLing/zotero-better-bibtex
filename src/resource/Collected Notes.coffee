Exporter = require('./exporter.coffee')

HTMLEncode = (text) -> text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')

class Report
  constructor: ->
    @Exporter = new Exporter()

    @items = Object.create(null)
    while item = Zotero.nextItem()
      @items[item.itemID] = item if item.itemType == 'note' || item.notes?.length > 0

    @itemInCollection = Object.create(null)
    @collections = []
    @mark(@Exporter.collections)

    title = HTMLEncode(Zotero.getOption('exportFilename').replace(/\.[^\.]*$/i, ''))

    @html = "<html><head><title>#{title}</title></head><body>"
    notes = []
    for own id, item of @items
      continue if @itemInCollection[id]
      notes.push(item)
    @notes(notes, 1)

    @walk(@Exporter.collections, 1)
    @html += '</body></html>'

  walk: (collection, level) ->
    return unless collection?.notes

    @html += "<h#{ level }>#{ HTMLEncode(collection.name) }</h#{ level }>\n"
    notes = (@items[id] for id in collection.items when @items[id])
    @notes(notes, level)

    for coll in collection.collections
      @walk(coll, level + 1)

  notes: (items, level) ->
    for item in items
      continue if @itemInCollection[item.itemID]
      continue unless item.itemType == 'note'
      @note(item)
    for item in items
      continue if @itemInCollection[item.itemID]
      continue if item.itemType == 'note'
      @itemWithNotes(item, level + 1)

  note: (item) ->
    @html += "<div>#{ item.note }</div>\n"

  creator: (cr) ->
    return '' unless cr.firstName || cr.lastName
    return (name for name in [cr.lastName, cr.firstName] when name).join(', ')

  itemWithNotes: (item, level) ->
    title = item.title

    creators = (@creator(creator) for creator in item.creators)
    creators = (creator for creator in creators when creator)
    if creators.length > 0
      creators = creators.join(' and')
    else
      creators = null

    if item.date
      date = Zotero.Utilities.strToDate(item.date)
      if typeof date.year == 'undefined'
        date = item.date
      else
        date = Zotero.Utilities.strToISO(item.date)
    else
      date = null

    author = (str for str in [creators, date] when str)
    if author.length > 0
      author = "(#{author.join(', ')})"
    else
      author = null

    title = (str for str in [item.title || '', author] when str).join(' ')

    @html += "<h#{ level + 1}>#{ HTMLEncode(title) }</h#{ level + 1}>\n"

    for note in item.notes
      @html += "<div>#{ note.note }</div>\n"

  mark: (collection) ->
    return unless collection
    @collections.push(collection)

    notes = false
    for id in collection.items || []
      continue unless @items[id]
      @itemInCollection[id] = true
      notes = true
    if notes
      for coll in @collections
        coll.notes = true

    for coll in collection.collections || []
      mark(coll)

    @collections.pop()

Translator.doExport = ->
  report = new Report()

  Zotero.write(report.html)
