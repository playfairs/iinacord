const net = require('net')
const socketPath = '/tmp/iinacord.sock'

function normalizeTitle(value) {
    if (!value) return 'Unknown'
    const raw = String(value)
    const withoutExtension = raw.replace(/\.[^/.]+$/, '')
    const cleaned = withoutExtension
        .replace(/[_-]+/g, ' ')
        .replace(/\s+/g, ' ')
        .trim()
    return cleaned || 'Unknown'
}

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
    init: function() {
        console.log('[IINAcord][Plugin] loaded')
    },
    deinit: function() {},
    onPlaybackStateChanged: function(state) {
        console.log('[IINAcord][Plugin] callback fired', JSON.stringify(state))
        const title = normalizeTitle(state.title || state.filename || state.file || state.url)
        const msg = {
            type: 'playback',
            title,
            url: state.url || null,
            position: state.position || 0,
            duration: state.duration || 0,
            paused: !!state.paused,
            idle: !!state.idle
        }
        console.log('[IINAcord][Plugin] sending playback title:', title)
        console.log('[IINAcord][Plugin] payload:', JSON.stringify(msg))
        sendMessage(msg)
    }
}