{CompositeDisposable} = require 'atom'
js2coffee = require 'js2coffee'
{spawn, exec} = require 'child_process'
path = require 'path'
{EOL} = require 'os'

module.exports =
  config:
    nodePath:
      type: 'string'
      default: ''
  subscriptions: null
  coffeeExe: null
  nodePath: ''
  noNodeMessage:
    detail:"""
      "coffee-paste":
        nodePath: "installed-node-path-here"
      """
  hasPathSet: false

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    # Register command
    @subscriptions.add atom.commands.add 'atom-workspace', 'coffee-paste:js2Coffee': => @js2Coffee()
    @subscriptions.add atom.commands.add 'atom-workspace', 'coffee-paste:coffee2Js': => @coffee2Js()
    @subscriptions.add atom.commands.add 'atom-workspace', 'coffee-paste:asCoffee': => @asCoffee()
    @subscriptions.add atom.commands.add 'atom-workspace', 'coffee-paste:asJs': => @asJs()

    @coffeeExe = [
      "#{atom.packages.packageDirPaths[0]}"
      "coffee-paste"
      "node_modules"
      "coffee-script"
      "bin"
      "coffee"
    ].join "#{path.sep}"

    @nodePath = "#{process.env.PATH}"
    if not atom.config.get('coffee-paste.nodePath')
      if process.platform isnt 'win32'
        # try this for unix
        @nodePath = [@nodePath, '/usr/local/bin', '/usr/local/sbin' ].join(path.delimiter)
    else
      @hasPathSet = true
      @nodePath = "#{atom.config.get('coffee-paste.nodePath')}#{path.delimiter}#{@nodePath}"

    # find node
    if process.platform isnt 'win32'
      type = exec 'type node', { env: { PATH: @nodePath }} , (error, stdout, stderr) =>
        @hasPathSet = if error then false else true


  deactivate: ->
    @subscriptions.dispose()

  asCoffee: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless content = @readClipboard()

    try
      {code} = js2coffee.build content, { indent: editor.getTabLength() || 2 }
      editor.setTextInBufferRange editor.getSelectedBufferRange(), code
    catch e
      @reportError { description: 'Paste Error' }, { detail: e.message }

  asJs: ->
    return unless @pathSet()
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless content = @readClipboard()

    child = spawn 'node', [@coffeeExe, '-sc'], {
      env: {
        PATH: "#{@nodePath}"
      }
    }

    child.stdin.resume
    child.stdin.write content

    child.stdout.on 'data', (code) =>
      editor.setTextInBufferRange editor.getSelectedBufferRange(), @coffeeExeOutputAsString(code)

    child.stderr.on 'data', (error) =>
      @reportError { description: 'Paste Error' }, { detail: new Buffer(error.toJSON()).toString() }

    child.stdin.end();


  js2Coffee: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless content = @readBuffer editor

    try
      {code} = js2coffee.build content, { indent: editor.getTabLength() || 2 }
      atom.clipboard.write code
    catch e
      @reportError { description: 'Copy Error' }, { detail: e.message }


  reportError: (e, options) ->
    atom.notifications.addError "[coffee-paste] #{e.description}", options

  coffee2Js: ->
    return unless @pathSet()
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless content = @readBuffer editor

    child = spawn 'node', [@coffeeExe, '-sc'], {
      env: {
        PATH: "#{@nodePath}"
      }
    }

    child.stdin.resume
    child.stdin.write content

    child.stdout.on 'data', (code) =>
      atom.clipboard.write @coffeeExeOutputAsString code

    child.stderr.on 'data', (error) =>
      @reportError { description: 'Copy Error' }, { detail: new Buffer(error.toJSON()).toString() }

    child.stdin.end()


  coffeeExeOutputAsString: (buffer) ->
    output = new Buffer(buffer.toJSON()).toString()
    output.split(EOL).splice(1).join(EOL)

  pathSet: ->
    if not atom.config.get('coffee-paste.nodePath') and not @hasPathSet
      @reportError {
        description: 'Configure node path'
      }, @noNodeMessage
    else
      @nodePath = "#{atom.config.get('coffee-paste.nodePath')}#{path.delimiter}#{@nodePath}"
      @hasPathSet = true

    @hasPathSet

  readClipboard: ->
    atom.clipboard.read()

  readBuffer: (editor) ->
    editor.getSelectedText() || editor.getBuffer().cachedText
