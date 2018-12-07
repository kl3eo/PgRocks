// add timestamps in front of log messages
require('console-stamp')(console, '[HH:MM:ss.l]');

var pg = require('pg');
const { Pool } = require('pg')

var _channel = "v3_dna_update";

var _joints = {
  A: { client: null,
       config: { 
                  user: 'postgres',
                  host: 'localhost',
                  database: 'tpcc',
                  password: 'xxx',
                  port: 5432
                }
  },
  B: { client: null,
       config: { 
                  user: 'postgres',
                  host: 'localhost',
                  database: 'tpcc',
                  password: 'xxx',
                  port: 9873
                }
  }
  
};

function update_table_in_joint(name, from, tableName, jsonRow) {

  var row = JSON.parse(jsonRow);

  const pool = new Pool(_joints[name].config);

  pool.on('error', (err, client) => {
  console.error('Unexpected error on idle client', err);
  process.exit(-1); });
  
  pool.connect((err, client, done) => {
  
  if (err) throw err;
  
  client.query('select _e_flush_c0(($1),$2,($3),$4)', [tableName,row.mark,row.key,row.rev], (err, res) => {
    done();
    if (err) {
      console.log(name + ': client COULD NOT update CACHE,', '\nrow = ' + jsonRow, err.stack);
    } else {
      console.log(name + ': CACHE got updated from ' + from + ', key = ' + row.key);
    }
  });
});

pool.end(() => {
  console.log('pool has ended')
});

}

function setup_notification(name) {
  console.log(name + ': ready to get notification');

  var client = _joints[name].client;
  client.query('LISTEN ' + _channel);

  client.on('notification', function(msg) {
    console.log(name + ': client got notification on \'' + msg.channel + '\'');

    var sepPos = msg.payload.indexOf(',');
    var tableName = msg.payload.substr(0, sepPos);
    var jsonRow = msg.payload.substr(sepPos + 1);
	
    for (var jointName in _joints) {
      if (jointName !== name) {
        if (msg.channel = _channel) update_table_in_joint(jointName, name, tableName, jsonRow);
      }
    }
  });
}


function main() {
  console.log('start the work');
  
  // create connections
  var wait_connections = [];
  for (var name in _joints) {
    _joints[name].client = new pg.Client(_joints[name].config);
    
    // to keep 'name' from changing by 'for'
    (function(name) {
      var connect = _joints[name].client.connect();
      connect.then(function() { console.log(name + ': client is connected'); })
            .catch(function(err) { console.error(name + ': client got a connection error', err.stack); });
      wait_connections.push(connect);
    })(name);
  }  

  // when everyone is connected
  Promise.all(wait_connections)
    .then(function() {
      for (var name in _joints) {
        setup_notification(name);
      }
    })
    .catch(function() {
      console.error('\n! one of the joints is not connected thus finish the work\n');
      for (var name in _joints) {
        // to keep 'name' from changing by 'for'
        (function(name) {
          _joints[name].client.end(function(err) { 
            console.log(name + ': client is disconnected');
            if (err) {
              console.log(name + ': client got error during disconnection', err.stack);
            }
          });
        })(name);
      }
    });
}

main();
