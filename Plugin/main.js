const net = require('net')
const socketPath = '/tmp/iinacord.sock'

function sendMessage(obj) {
    const client = net.createConnection({ path: socketPath }, () => {
        client.write(JSON.stringify(obj))
        client.end()
    })
    client.on('error', (err) => {
        console.error('IINAcord socket error', err)
    })
}

module.exports = {
    init: function() {},
    deinit: function() {},
    onPlaybackStateChanged: function(state) {
        const msg = {
            type: 'playback',
            title: state.title || state.filename || 'Unknown',
            url: state.url || null,
            position: state.position || 0,
            duration: state.duration || 0,
            paused: !!state.paused,
            idle: !!state.idle
        }
        sendMessage(msg)
    }
}
