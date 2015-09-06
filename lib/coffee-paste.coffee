{CompositeDisposable} = require 'atom'
js2coffee = require 'js2coffee'
{spawn} = require 'child_process'
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
      if process.plateform is 'win32'
        @reportError {
          description: 'Configure node path'
        }
      else
        # try this for unix
        @nodePath = [@nodePath, '/usr/local/bin', '/usr/local/sbin' ].join(path.delimiter)
    else
      @nodePath = "#{atom.config.get('coffee-paste.nodePath')}#{path.delimiter}#{@nodePath}"

    # find node
    if process.plateform isnt 'win32'
      type = spawn 'type', ['node'], { env: { PATH: @nodePath }}
      type.stderr.on 'data', (data) ->
        @reportError {
          description: 'Configure node path'
        }
        type.stdin.end()


  deactivate: ->
    @subscriptions.dispose()

  asCoffee: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless content = @readClipboard()

    try
      {code} = js2coffee.build content, { indent: editor.getTabLength() || 2 }
      editor.setTextInBufferRange editor.getSelectedBufferRange(), code
    catch e
      @reportError e

  asJs: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless content = @readClipboard()

    child = spawn @coffeeExe, ['-sc'], {
      env: {
        PATH: "#{@nodePath}"
      }
    }

    child.stdin.resume
    child.stdin.write content

    child.stdout.on 'data', (code) =>
      editor.setTextInBufferRange editor.getSelectedBufferRange(), @coffeeExeOutputAsString(code)

    child.stderr.on 'data', (error) ->
      @reportError new Buffer(error.toJSON()).toString()

    child.stdin.end();


  js2Coffee: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless content = @readBuffer editor

    try
      {code} = js2coffee.build content, { indent: editor.getTabLength() || 2 }
      atom.clipboard.write code
    catch e
      @reportError e


  reportError: (e) ->
    atom.notifications.addError "[coffee-paste] #{e.description}"

  coffee2Js: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless content = @readBuffer editor

    child = spawn @coffeeExe, ['-sc'], {
      env: {
        PATH: "#{@nodePath}"
      }
    }

    child.stdin.resume
    child.stdin.write content

    child.stdout.on 'data', (code) =>
      atom.clipboard.write @coffeeExeOutputAsString code

    child.stderr.on 'data', (error) ->
      @reportError new Buffer(error.toJSON()).toString()

    child.stdin.end()


  coffeeExeOutputAsString: (buffer) ->
    output = new Buffer(buffer.toJSON()).toString()
    output.split(EOL).splice(1).join(EOL)


  readClipboard: ->
    atom.clipboard.read()

  readBuffer: (editor) ->
    editor.getSelectedText() || editor.getBuffer().cachedText
