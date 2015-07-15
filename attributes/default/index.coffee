module.exports = ->
  @default mongodb:
    bind_ip: '127.0.0.1'
    journaling: true
    dbpath: '/var/lib/mongodb'
