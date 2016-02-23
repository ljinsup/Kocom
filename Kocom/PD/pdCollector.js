var assert = require('assert');
var Mongo = require('mongodb');
var Agenda = require('agenda');
var MongoClient = Mongo.MongoClient;
var mqtt = require('mqtt');
var SC_Console = require('./SC_Console');
var xml2json = require('./xml2json');
var http = require('http');

var DB_URI = process.env.DB_URI || "mongodb://localhost/";
var MQTT_URI = process.env.MQTT_URI || "mqtt://localhost";
var AGENDA_URI = process.env.AGENDA_URI || "mongodb://localhost/agenda"
var PD_DB = process.env.PD_DB || "publicdata";
var PDLIST_DB = process.env.PDLIST_DB || PD_DB;
var PDLIST_COLL = process.env.PDLIST_COLL || "pdList";
var KEY_TOPIC = process.env.KEY_TOPIC || "DEFAULT";
var TIME_UNIT = process.env.UP_UNIT || 'hour';//1000 * 10;

var MQTTClient = null;
var DB_DATA = null;
var DB_LIST = null;
var AGENDA = null;

function pdCollector(ob) {
    var clientURL = ob.url.substring(0, ob.url.indexOf("/"));
    var serviceURL = ob.url.substring(ob.url.indexOf("/"));
    var usetime = ob.usetime;

    var time = new Date();
    var fullpath = '';

    if (usetime) {
        fullpath = serviceURL + '&base_time=' + time.getHours() + '00&ServiceKey=' + ob.apikey;
    } else {
        fullpath = serviceURL + '&ServiceKey=' + ob.apikey;
    }

    var options = {
        host: clientURL,
        port: 80,
        path: fullpath
    };

    http.get(options, function (res) {
        var enc = 'utf8';
        res.setEncoding(enc);

        res.on('data', function (chunk) {
            SC_Console.startPrint('Public data collected.');
            SC_Console.midPrint('DB Name : ' + PD_DB);

            var collection = ob.collection;
            SC_Console.midPrint('Collection Name : ' + collection);
            var jsonObjTemp = xml2json.parser(chunk);

            var test = jsonObjTemp.response.body.items.item;

            for(var i=0 ; i<Object.keys(test).length ; i++){
                if(json[Object.keys(json)[i]] == '-')
                    return;
            }

            var jsonObj = JSON.parse(JSON.stringify(test));
            SC_Console.midPrint('JSON Parsed.');

            MH.insertOne(DB_DATA, collection, jsonObj, function (err, result) {
                assert.equal(err, null);
                SC_Console.midPrint('Public data is stored.');
                SC_Console.endPrint();
            });
        });
    }).on("error", function (e) {
        SC_Console.errPrint(e.message);
    });
}

var QH = {
    initQH: function () {
        SC_Console.startPrint('MQTT Handler Initialization...');
        SC_Console.midPrint("MQTT Broker URI : " + MQTT_URI);
        SC_Console.midPrint("Connecting to MQTT Broker...");
        MQTTClient = mqtt.connect(MQTT_URI);

        MQTTClient.on('connect', function () {
            SC_Console.midPrint('MQTT connected.');

            QH.subscribeTopic(KEY_TOPIC + '/import');
            QH.subscribeTopic(KEY_TOPIC + '/remove');

            SC_Console.midPrint('MQTT Initialized.');
            SC_Console.endPrint();

            MQTTClient.on('message', function (topic, message) {
                SC_Console.startPrint('Message arrived... ');
                SC_Console.midPrint('Topic - ' + topic.toString());
                SC_Console.midPrint('Message - ' + message.toString());

                var msg = JSON.parse(message);

                var spTopic = topic.split('/');
                if (spTopic.length > 1) {
                    if (spTopic[1] === 'import') {
                        SC_Console.midPrint('Action : Public Data Insertion');

                        var d = new Date().getTime().toString();

                        SC_Console.midPrint('PD ID : ' + d);
                        SC_Console.midPrint('PD Collection : ' + msg.collection);
                        SC_Console.midPrint('PD Collect Period : ' + msg.period);

                        var objPublicData = {
                            "id": d,
                            "url": msg.url,
                            "apikey": msg.apikey,
                            "collection": msg.collection,
                            "period": msg.period,
                            "isCollected": true
                        };

                        AGENDA.define(d, function (job, done) {
                            pdCollector(job.attrs.data);
                            done();
                        });

                        AGENDA.every(msg.period + ' ' + TIME_UNIT, d, objPublicData);
                        SC_Console.midPrint('AGENDA : Collecting Schedule of ' + d + ' is Registered.');

                        MH.insertOne(DB_LIST, PDLIST_COLL, objPublicData, function () {
                        });

                        SC_Console.midPrint('The Public Data Information is registered');

                    } else if (spTopic[1] === 'remove') {
                        SC_Console.midPrint('Action : Public Data Removal');

                        AGENDA.cancel({name: msg.id}, function (err, numRemoved) {
                            assert.equal(err, null);
                            MH.findUpdate(DB_LIST, PDLIST_COLL, msg, {isCollected: false}, function (result) {
                                SC_Console.midPrint('The Public Data ' + result.title + ' Agenda is removed');
                            });
                        });
                    } else {
                        SC_Console.midPrint('Wrong Topic...');
                    }
                } else {
                    SC_Console.midPrint('Wrong Topic...');
                }
                SC_Console.endPrint();
            });
        });

        MQTTClient.on('reconnect', function () {
            SC_Console.midPrint('MQTT Status : reconnecting...');
        });

        MQTTClient.on('close', function () {
            SC_Console.midPrint('MQTT Status : closed');
        });

        MQTTClient.on('error', function () {
            SC_Console.midPrint('MQTT: error');
        });

        MQTTClient.on('offline', function () {
            SC_Console.endPrint();
            SC_Console.startPrint('MQTT Broker is disconnected');
            SC_Console.midPrint('MQTT Status : offline');
        });
    },
    subscribeTopic: function (topic) {
        assert.notEqual(topic, '', 'Topic is null...');
        MQTTClient.subscribe(topic);
        SC_Console.midPrint('Subscribe -> ' + topic);
    },
    unsubscribeTopic: function (topic) {
        assert.notEqual(topic, '', 'Topic is null...');
        MQTTClient.unsubscribe(topic);
        SC_Console.midPrint('Unsubscribe -> ' + topic);
    },
    publishMsg: function (topic, msg) {
        MQTTClient.publish(topic, msg);
    }
};

var MH = {
    removeAll: function (db, coll, callback) {
        assert.notEqual(DB_URI, '', 'DB_URI must be assigned!!!');
        assert.notEqual(db, null, 'DB must be initialized!!!');

        db.collection(coll).deleteMany({}, function (err, results) {
            assert.equal(err, null);
            SC_Console.midPrint("All documents of " + coll + " are removed...");
            callback();
        });
    },
    findOne: function (db, coll, doc, callback) {
        assert.notEqual(DB_URI, '', 'DB_URI must be assigned!!!');
        assert.notEqual(db, null, 'DB must be initialized!!!');

        db.collection(coll).find(doc, function (err, result) {
            assert.equal(err, null);
            SC_Console.midPrint("Find document of " + coll + " collection: " + result);
            callback(result);
        });
    },
    findAll: function (db, coll, doc, callback) {
        assert.notEqual(DB_URI, '', 'DB_URI must be assigned!!!');
        assert.notEqual(db, null, 'DB must be initialized!!!');

        db.collection(coll).find(doc).toArray(function (err, result) {
            assert.equal(null, err);
            callback(result);
        });
    },
    findUpdate: function (db, coll, doc, updoc, callback) {
        assert.notEqual(DB_URI, '', 'DB_URI must be assigned!!!');
        assert.notEqual(db, null, 'DB must be initialized!!!');

        db.collection(coll).findOneAndUpdate(doc, {$set: updoc}, {returnOriginal: false}, function (err, result) {
            assert.equal(err, null);
            console.log(result);
            SC_Console.midPrint("Update a document of " + coll + " collection to: " + result);
            callback(result);
        });
    },
    updateOne: function (db, coll, doc, updoc, callback) {
        assert.notEqual(DB_URI, '', 'DB_URI must be assigned!!!');
        assert.notEqual(db, null, 'DB must be initialized!!!');

        db.collection(coll).update(doc, updoc, function (err, result) {
            assert.equal(err, null);
            SC_Console.midPrint("Update a document of " + coll + " collection to: " + updoc);
            callback();
        });
    },
    insertOne: function (db, coll, doc, callback) {
        assert.notEqual(DB_URI, '', 'DB_URI must be assigned!!!');
        assert.notEqual(db, null, 'DB must be initialized!!!');

        db.collection(coll).insertOne(doc, function (err, result) {
            assert.equal(err, null);
            SC_Console.midPrint("Inserted a document into the " + coll + " collection.");
            callback();
        });
    }
};

SC_Console.startPrint('MongoDB Handler Initialization...');
SC_Console.midPrint("Public Data DB URI : " + DB_URI + PD_DB);
SC_Console.midPrint("Connecting to Public Data DB ...");
MongoClient.connect(DB_URI + PD_DB, function (err, db) {
    DB_DATA = db;
    SC_Console.midPrint("Finished.");

    SC_Console.midPrint("Public Data List DB URI : " + DB_URI + PDLIST_DB);
    SC_Console.midPrint("Connecting to Public Data List DB ...");
    MongoClient.connect(DB_URI + PDLIST_DB, function (err, dblist) {
        DB_LIST = dblist;
        SC_Console.midPrint("Finished.");
        SC_Console.endPrint();

        SC_Console.startPrint('Agenda Initializing...');
        SC_Console.midPrint("Agenda DB URI : " + AGENDA_URI);
        SC_Console.midPrint("Connecting to Agenda DB ...");

        AGENDA = new Agenda({db: {address: AGENDA_URI, collection: 'agendaJobs'}});

        AGENDA.on('ready', function () {
            AGENDA.purge();
            AGENDA.processEvery('1 second');
            AGENDA.start();
            SC_Console.midPrint("Agenda Started.");

            MH.findAll(DB_LIST, PDLIST_COLL, {isCollected: true}, function (pdList) {
                for (var i = 0; i < pdList.length; i++) {
                    AGENDA.define(pdList[i].id, function (job, done) {
                        pdCollector(job.attrs.data);
                        done();
                    });

                    AGENDA.every(pdList[i].period + ' ' + TIME_UNIT, pdList[i].id, pdList[i]);
                    SC_Console.midPrint('AGENDA : Collecting Schedule of ' + pdList[i].id + ' is Registered.');
                }
                SC_Console.endPrint();
                QH.initQH();
            });
        });
    });
});