zotero_config = require('../zotero-config.coffee')
getAddons = require('../addons.coffee')
Prefs = require('../preferences.coffee')
Translators = require('../translators.coffee')
debug = require('../debug.coffee')

class ErrorReport
  constructor: (@global) ->

  init: Zotero.Promise.coroutine(->
    @params = @global.window.arguments[0].wrappedJSObject

    wizard = @global.document.getElementById('better-bibtex-error-report')
    continueButton = wizard.getButton('next')
    continueButton.disabled = true

    @form = JSON.parse(Zotero.File.getContentsFromURL('https://github.com/retorquere/zotero-better-bibtex/releases/download/static-files/error-report.json'))
    @key = Zotero.Utilities.generateObjectKey()
    @timestamp = (new Date()).toISOString().replace(/\..*/, '').replace(/:/g, '.')

    @errorlog = {
      info: yield @info()
      errors: Zotero.getErrors(true).join('\n')
      full: yield Zotero.Debug.get()
    }
    @errorlog.truncated = @errorlog.full.split("\n")
    @errorlog.truncated = @errorlog.truncated.slice(0, 5000) # max 5k lines
    @errorlog.truncated = (Zotero.Utilities.ellipsize(line, 80, true) for line in @errorlog.truncated) # trim lines
    @errorlog.truncated = @errorlog.truncated.join("\n")

    if @params.items
      debug('ErrorReport::init items', @params.items)
      yield Zotero.BetterBibTeX.ready # because we need the translators to have been loaded
      @errorlog.references = yield Translators.translate(Translators.byLabel.BetterBibTeXJSON.translatorID, {exportNotes: true}, @params.items)
      debug('ErrorReport::init references', @errorlog.references)

    debug('ErrorReport.init:', Object.keys(@errorlog))
    @global.document.getElementById('better-bibtex-error-context').value = @errorlog.info
    @global.document.getElementById('better-bibtex-error-errors').value = @errorlog.errors
    @global.document.getElementById('better-bibtex-error-log').value = @errorlog.truncated
    @global.document.getElementById('better-bibtex-error-references').value = @errorlog.references.substring(0, 5000) if @errorlog.references
    @global.document.getElementById('better-bibtex-error-tab-references').hidden = !@errorlog.references

    continueButton.focus()
    continueButton.disabled = false
    return
  )

  # general state of Zotero
  info: Zotero.Promise.coroutine(->
    info = ''

    appInfo = Components.classes['@mozilla.org/xre/app-info;1'].getService(Components.interfaces.nsIXULAppInfo)
    info += "Application: #{appInfo.name} #{appInfo.version} #{Zotero.locale}\n"
    info += "Platform: #{Zotero.platform} #{Zotero.oscpu}\n"

    addons = yield getAddons()
    if addons.active.length
      info += "Active addons:\n"
      for addon in addons.active
        info += "  #{addon.info}\n"
    if addons.inactive.length
      info += "Inactive addons:\n"
      for addon in addons.inactive
        info += "  #{addon.info}\n"

    info += "Settings:\n"
    prefs = []
    for key in Prefs.branch.getChildList('')
      prefs.push(key)
    prefs.sort()
    for key in prefs
      info += "  #{key} = #{JSON.stringify(Prefs.get(key))}\n"

    return info
  )

  submit: (filename, data) ->
    return new Zotero.Promise((resolve, reject) =>
      fd = new FormData()
      for own name, value of @form.fields
        fd.append(name, value)

      file = new Blob([data], { type: 'text/plain'})
      fd.append('file', file, "#{@timestamp}-#{@key}-#{filename}")

      request = Components.classes["@mozilla.org/xmlextras/xmlhttprequest;1"].createInstance()
      request.open('POST', @form.action, true)

      request.onload = =>
        switch
          when !request.status || request.status > 1000
            return reject(Zotero.getString('errorReport.noNetworkConnection') + ': ' + request.status)
          when request.status != parseInt(@form.fields.success_action_status)
            return reject(Zotero.getString('errorReport.invalidResponseRepository') + ": #{request.status}, expected #{@form.fields.success_action_status}\n#{request.responseText}")
          else
            return resolve()

      request.onerror = -> reject(Zotero.getString('errorReport.noNetworkConnection') + ': ' + request.statusText)

      request.send(fd)
      return
    )

  sendErrorReport: Zotero.Promise.coroutine(->
    wizard = @global.document.getElementById('better-bibtex-error-report')
    continueButton = wizard.getButton('next')
    continueButton.disabled = true

    errorlog = [@errorlog.info, @errorlog.errors, @errorlog.full].join("\n\n")

    try
      yield @submit('errorlog.txt', errorlog)
      yield @submit('references.json', @errorlog.references) if @errorlog.references
      wizard.advance()
      wizard.getButton('cancel').disabled = true
      wizard.canRewind = false

      @global.document.getElementById('better-bibtex-report-id').setAttribute('value', @key)
      @global.document.getElementById('better-bibtex-report-result').hidden = false
    catch err
      ps = Components.classes['@mozilla.org/embedcomp/prompt-service;1'].getService(Components.interfaces.nsIPromptService)
      ps.alert(null, Zotero.getString('general.error'), err)
      wizard.rewind() if wizard.rewind
    return
  )

  start: Zotero.Promise.coroutine((includeReferences) ->
    debug('ErrorReport::start', includeReferences)
    items = null

    pane = Zotero.getActiveZoteroPane()

    switch includeReferences
      when 'collection'
        collectionsView = pane?.collectionsView
        itemGroup = collectionsView?._getItemAtRow(collectionsView.selection?.currentIndex)
        switch itemGroup?.type
          when 'collection'
            items = {collection: collectionsView.getSelectedCollection() }
          when 'library'
            items = { }
          when 'group'
            items = { collection: Zotero.Groups.get(collectionsView.getSelectedLibraryID()) }

      when 'items'
        items = { items: pane.getSelectedItems() }

    items = null if items && items.items && items.items.length == 0
    params = {wrappedJSObject: { items }}

    debug('ErrorReport::start popup', params)
    ww = Components.classes['@mozilla.org/embedcomp/window-watcher;1'].getService(Components.interfaces.nsIWindowWatcher)
    ww.openWindow(null, 'chrome://zotero-better-bibtex/content/error-report/error-report.xul', 'better-bibtex-error-report', 'chrome,centerscreen,modal', params)
    debug('ErrorReport::start done')

    return
  )

module.exports = ErrorReport
