module.exports = ->
  @import __dirname, 'attributes', 'default'

  #Use mongoDB packages instead of Ubuntu
  @then @log 'Loading key and package source for mongodb into apt'
  @then @execute 'sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10'
  @then @execute 'echo "deb http://repo.mongodb.org/apt/ubuntu "$(lsb_release -sc)"/mongodb-org/3.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.0.list'
  @then @package_update()

  #Install the latest version
  @then @log 'Install the latest mongodb package'
  @then @install 'mongodb-org'
  @then @execute 'service mongod stop', sudo: true

  @then @log 'Ensure data directory exists'
  @then @directory @server.mongodb.dbpath,
    sudo: true
    owner: 'mongodb'
    group: 'mongodb'
    recursive: true
    mode: '0755'
    ignore_errors: true

  #Listen on specified interfaces
  @then @replace_line_in_file '/etc/mongod.conf', sudo: true, find: 'bind_ip = 127.0.0.1', replace: "bind_ip = #{@server.mongodb.bind_ip}"
  @then @replace_line_in_file '/etc/mongod.conf', sudo: true, find: 'dbpath', replace: "dbpath = #{@server.mongodb.dbpath}"

  if @server.mongodb.journaling is false
    @then @replace_line_in_file '/etc/mongod.conf', sudo: true, find: 'nojournal', replace: "nojournal = true"
