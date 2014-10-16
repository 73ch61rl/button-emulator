WebSocket = require('ws')
keypress = require('keypress')
Bacon = require('baconjs')
_ = require('lodash')

SERVER = process.env.HORSELIGHTS_SERVER || "ws://localhost:3000"
SITEKEY = process.env.HORSELIGHTS_SITEKEY || "devsite"
BUTTON_ADDRESS = process.env.HORSELIGHTS_BUTTON_ADDRESS || "ff:ff:ff:ff"
BUTTON_ADDRESS_ARRAY = BUTTON_ADDRESS.split(":").map (s) -> parseInt(s, 16)

keypress process.stdin
process.stdin.setRawMode(true)
process.stdin.resume()

charToKeyCode =
  '1':   0x30
  '2':   0x70
  '3':   0x10
  '4':   0x50
  '1+2': 0x37
  '3+4': 0x15

# buttonPressedData :: Int      -> [Int]           -> [Int]
#                      keyCode     enoceanAddress  -> data
#
# Enocean address must be an int array, length 4.
# Example: [0xfe, 0xfe, 0x80, 0xa8]
#
buttonPressedData = (keyCode, enoceanAddress) ->
  [0x55, 0x00, 0x07, 0x07, 0x01, 0x7a, 0xf6, keyCode].concat(enoceanAddress).concat([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])

stdinCharsBinder = (sink) ->
  process.stdin.on 'keypress', (ch, key) ->
    if (key && key.ctrl && key.name == 'c')
      sink(new Bacon.End())
    else
      sink ch
  return ( -> )

is1234 = (ch) -> _.contains _.keys(charToKeyCode), ch

toKeyPressedCommand = (keyCode) -> { command: "enoceandata", data: buttonPressedData(keyCode, BUTTON_ADDRESS_ARRAY) }

socket = new WebSocket(SERVER)
socket.on 'open', ->
  console.log "Connected to", SERVER
  publishMessage = JSON.stringify { command: "publish", data: { sitekey: SITEKEY, vendor: "enocean" } }
  socket.send publishMessage
  console.log "Sent publish message with sitekey", SITEKEY
  console.log "Press 1, 2, 3 or 4"
  chars = Bacon.fromBinder stdinCharsBinder
  chars.onEnd -> process.exit 0
  messages = chars
    .filter is1234
    .map (ch) -> charToKeyCode[ch]
    .map toKeyPressedCommand
    .map JSON.stringify
  messages.onValue (s) -> socket.send s
  messages.onValue (s) -> console.log "Sent message:", s

socket.on 'close', -> process.exit 1
