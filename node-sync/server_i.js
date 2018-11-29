var pg = require('pg');

var _channel = "v3_dna_insert";

var _joints = {
  A: { client: null,
       config: { 
                  user: 'postgres',
                  host: 'localhost',
                  database: 'people',
                  password: 'xxx',
                  port: 5432
                }
  },
  B: { client: null,
       config: { 
                  user: 'postgres',
                  host: 'localhost',
                  database: 'people',
                  password: 'xxx',
                  port: 9873
                }
  }
  
};

function update_table_in_joint(name, from, jsonRow) {
  var client = _joints[name].client;
  var row = JSON.parse(jsonRow);
  var tableName  = row.tab;
  
  client.query('INSERT INTO ' + tableName + '_v3_dna (mark, rev, key, ancestor) VALUES($1,$2,$3,$4)'
    , [row.mark, row.rev, row.key, row.ancestor])
    .then(function()     { console.log(name + ': client got update from ' + from + ', key = ' + row.key); })
    .catch(function(err) { console.error(name + ': client COULD NOT get update,', '\nrow = ' + jsonRow, err.stack); });
  
  client.query('select _e_atomic_c0(($1),$2,($3))'
    , [row.tab, row.mark, row.key])
    .then(function()     { console.log(name + ': client got atomic cache insert from ' + from + ', key = ' + row.key); })
    .catch(function(err) { console.error(name + ': client COULD NOT get atomic cache insert,', '\nrow = ' + jsonRow, err.stack); });
}

function setup_notification(name) {
  console.log(name + ': ready to get notification');

  var client = _joints[name].client;
  client.query('LISTEN ' + _channel);

  client.on('notification', function(msg) {
    console.log(name + ': client got notification on \'' + msg.channel + '\'');

    //var sepPos = msg.payload.indexOf(',');
    //var tableNum = msg.payload.substr(0, sepPos);
    //var jsonRow = msg.payload.substr(sepPos + 1);
    var jsonRow = msg.payload;
	
    for (var jointName in _joints) {
      if (jointName !== name) {
        if (msg.channel = _channel) update_table_in_joint(jointName, name, jsonRow);
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
