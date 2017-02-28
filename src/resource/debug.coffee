inspect = require('util').inspect

module.exports = (msg...) ->
  return unless Translator.preferences.debug
  
  str = []
  for m in msg
    switch
      when m instanceof Error
        m = "<Exception: #{m.message || m.name}#{if m.stack then '\n' + m.stack else ''}>"
      when m instanceof String
        m = '' + m
      else
        m = inspect(m)
    str.push(m) if m
  str = str.join(' ')

  Zotero.debug("[better-bibtex:#{Translator.header.label}] " + str)
