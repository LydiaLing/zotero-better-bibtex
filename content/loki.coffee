Ajv = require('ajv')
Loki = require('lokijs')
createFile = require('./create-file.coffee')
debug = require('./debug.coffee')
flash = require('./flash.coffee')

validator = new Ajv({ useDefaults: true, coerceTypes: true })

validator.addKeyword('coerce', {
  modifying: true,
  compile: (type) ->
    validateCoerced = validator.compile({ type })
    return (data, dataPath, parentData, parentDataProperty) ->
      msg = "Unable to coerce #{typeof data} '#{data}' to #{type}"

      switch type
        when 'float', 'number'
          data = parseFloat(data || 0)
          throw new Error(msg) if isNaN(data) || !isFinite(data)

        when 'integer'
          data = parseInt(data || 0)
          throw new Error(msg) if isNaN(data) || !isFinite(data)

        when 'boolean'
          data = !!data

        when 'string'
          data = if data? then '' + data else ''

        when 'date'
          if data then data = new Date(data) else data = null

        else
          throw new Error(msg)

      parentData[parentDataProperty] = data

      return !data || !isNaN(data.getTime()) if type == 'date'
      return validateCoerced(data)
})

Loki::schemaCollection = (name, options) ->
  coll = @getCollection(name) || @addCollection(name, options)
  coll.validate = validator.compile(options.schema)
  return coll

Loki.Collection::insert = ((original) ->
  return (doc) ->
    throw @validate.errors if @validate && !@validate(doc)
    return original.apply(@, arguments)
)(Loki.Collection::insert)

Loki.Collection::update = ((original) ->
  return (doc) ->
    throw @validate.errors if @validate && !@validate(doc)
    return original.apply(@, arguments)
)(Loki.Collection::update)

class _FileStore
  backups: 3

  versioned: (name, id) ->
    return name unless id
    return "#{name}.#{id}"

  saveDatabase: (name, serialized, callback) ->
    debug('Loki: saving', name)

    try
      db = createFile(name)
      if db.exists()
        for id in [@backups..0]
          db = createFile(@versioned(name, id))
          continue unless db.exists()
          debug("DBStore: backing up #{db.path}")
          db.moveTo(null, name + ".#{id + 1}")
    catch err
      debug('LokiJS.FileStore.saveDatabase: backup failed', err)

    try
      db = createFile(name + '.saving')
      Zotero.File.putContents(db, serialized)
      db.moveTo(null, name)
      callback(null)
    catch err
      callback(err)
    return

  tryDatabase: (name) ->
    debug("LokiJS.FileStore.tryDatabase: trying #{name}")
    file = createFile(name)
    throw {name: 'NoSuchFile', message: "#{file.path} not found", toString: -> "#{@name}: #{@message}"} unless file.exists()

    data = Zotero.File.getContents(file)

    # will throw an error if not valid JSON -- too bad we're doing this twice, but better safe than sorry, and only
    # happens at startup
    JSON.parse(data)

    return data

  loadDatabase: (name, callback) ->
    data = null
    error = null
    for id in [0..@backups]
      try
        data = @tryDatabase(@versioned(name, id))
        error = null
        break
      catch err
        error = err unless err.name == 'NoSuchFile'
        data = null

    if error
      debug("LokiJS.FileStore.loadDatabase: failed to load #{name}", error)
      flash("failed to load #{name} (#{error})")
      return callback(error)

    return callback(data || '{}')

class FileStore
  mode: 'reference'

  _load: (name) ->
    file = createFile(name)
    throw {name: 'NoSuchFile', message: "#{file.path} not found", toString: -> "#{@name}: #{@message}"} unless file.exists()
    return Zotero.File.getContents(file)

  _save: (file, obj) ->
    debug.log("saving #{file.path}")
    Zotero.File.putContents(file, JSON.stringify(obj, null, 2))
    return

  exportDatabase: (dbname, dbref, callback) ->
    header = {}
    for k, v of dbref
      if k == 'collections'
        for coll in v
          collfile = "#{dbref.filename}.#{coll.name}.json"
          f = createFile(collfile)
          if coll.dirty || !f.exists()
            @_save(f, coll)
        header[k] = v.map((coll) -> coll.name)
      else
        header[k] = v

    Zotero.File.putContents(createFile("#{dbref.filename}.json"), JSON.stringify(header, null, 2))
    callback(null)
    return true

  loadDatabase: (dbname, callback) ->
    try
      db = JSON.parse(@_load("#{dbname}.json"))
    catch err
      throw err unless err.name == 'NoSuchFile'
      db = new Loki(dbname)

    for coll, i in db.collections
      continue unless typeof coll == 'string'
      db.collections[i] = JSON.parse(@_load("#{dbname}.#{coll}.json"))

    callback(db)
    return

module.exports = (name, options = {}) ->
  if options.autosave
    # options.adapter = new Loki.LokiPartitioningAdapter(new FileStore())
    options.adapter = new FileStore()
    options.autosaveInterval ||= 5000
    delete options.persistenceMethod
  else
    delete options.adapter
    options.persistenceMethod = null
  options.env = 'BROWSER'
  return new Loki(name, options)
