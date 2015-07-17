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

  if @server.mongodb.replication.enabled is true
    @then @log "Enable Replication"
    @then @replace_line_in_file '/etc/mongod.conf', sudo: true, find: 'replSet', replace: "replSet = \"#{@server.mongodb.replication.setname}\""
    @then @replace_line_in_file '/etc/mongod.conf', sudo: true, find: 'oplogSize', replace: "oplogSize=#{@server.mongodb.replication.oplogsize}"
    @then @execute 'service mongod start', sudo: true
    #wait for mongodb to finish initializing before trying to initiate the replica set
    @then @execute 'until mongo --eval "db.serverStatus()"; do echo "waiting for mongodb to listen" && sleep 10; done;'
    if @server.instance is '01'
      @then @execute 'mongo --eval "printjson(rs.initiate())"'
    else
      @map_servers
        types: @server.type, instances: '01', required: true, (o) =>
          @then @hostsfile_entry [o.hostname,o.fqdn], ip: o.private_ip
          @then @log "Add to cluster #{o.private_ip}"
          @then @execute "until mongo --host #{o.private_ip} --eval \"printjson(rs.add(\'#{@server.private_ip}\'))\"; do echo 'waiting for main node to listen' && sleep 10; done;"
    @then @execute 'mongo --eval \"printjson(rs.status())\"'
