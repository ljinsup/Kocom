var assert = require('assert');
var CryptoJS = require('crypto-js');
var Mongo = require('mongodb');
var MongoClient = Mongo.MongoClient;
var mqtt = require('mqtt');
var SC_Console = require('./SC_Console');

var DB_URI = process.env.DB_URI || "mongodb://localhost:30000/";
var MQTT_URI = process.env.MQTT_URI || "mqtt://localhost:1883";
var CFG_DB = process.env.CF_DB || "scconfig";
var TG_DB = process.env.TG_DG || "tgconfig";
var GRP_DB = process.env.GRP_DB || "groupdata";
var SS_DB = process.env.SS_DB || "sensordata";
var LOG_DB = process.env.LOG_DB || "logdata";
var KEY_TOPIC = process.env.KEY_TOPIC || "kocom";
//var THR_TOPIC = process.env.THR_TOPIC || "SC/THR/"
//var TGThr_TOPIC = process.env.TGThr_TOPIC || "kocom/TGThr/"

var MQTTClient = null;
var DB_DATA = null;
var DB_LIST = null;
var DB_SCCFG = null;
var DB_TGCFG = null;
var DB_GRP = null;
var DB_SS = null;
var DB_LOG = null;

var QH = {
    initQH: function () {
        SC_Console.startPrint('QH Initializing...');
        SC_Console.midPrint("Connecting to MQTT server... (" + MQTT_URI + ")");
        MQTTClient = mqtt.connect(MQTT_URI);

        MQTTClient.on('connect', function () {
            SC_Console.midPrint('MQTT connected.');

            QH.subscribeTopic('kocom/TGdata/#');
            QH.subscribeTopic('kocom/Log/#');
            QH.subscribeTopic('kocom/registerTG');
            QH.subscribeTopic('kocom/SERV/#');
            QH.subscribeTopic('kocom/TGThr/#');
            QH.subscribeTopic('SC/TGThr/#');
            QH.subscribeTopic('SC/SERV/#');
            QH.subscribeTopic('SC/THR/#');

            SC_Console.midPrint('MQTT Initialized.');
            SC_Console.endPrint();

            MQTTClient.on('message', function (topic, message) {
                var currentdate = new Date();
                var datetime = currentdate.getFullYear() + "/"
                        + (currentdate.getMonth() + 1) + "/"
                        + currentdate.getDate() + " "
                        + currentdate.getHours() + ":"
                        + currentdate.getMinutes() + ":"
                        + currentdate.getSeconds();
                SC_Console.startPrint('Message arrived... ' + datetime);
                SC_Console.midPrint('Topic - ' + topic.toString());
                SC_Console.midPrint('Message - ' + message.toString());

                try {

                    var msg = JSON.parse(message);
                
                    var spTopic = topic.split('/');
                    if (spTopic.length > 1) {
                        if (spTopic[1] === 'TGdata') {
                            
                            SC_Console.midPrint('Action : Sensor Data Insertion');

                            MH.insertOne(DB_SS, spTopic[2], {
                                sensors_data: msg.sensors_data,
                                dev_type: msg.dev_type,
                                time: new Date()
                            }, function (err) {
                                assert.equal(err, null);
                                SC_Console.midPrint('Public data is stored.');
                                SC_Console.endPrint();
                            });

                            QH.publishMsg('SC/SERV/USER_01', JSON.stringify({
                                type: 'sensordata',
                                userid: msg.userid,
                                tgid: msg.tgid,
                                dev_type: msg.dev_type,
                                sensors_data: msg.sensors_data,
                                origin: msg.origin
                            }));

                        } else if (spTopic[1] === 'Log') {
                            SC_Console.midPrint('Action : Log Data Insertion');
                            MH.insertOne(DB_LOG, spTopic[2], {
                                data: msg.data,
                                lognum: msg.lognum,
                                time: new Date()
                            }, function (err) {
                                assert.equal(err, null);
                                SC_Console.midPrint('Public data is stored.');
                                SC_Console.endPrint();
                            });
                        } else if (spTopic[1] === 'TGThr') {
                            SC_Console.midPrint('Action : Thin-Gateway Threshold Request');

                            //MH.findUpdate(DB_TGCFG, msg.tgid, {'list.dev_type': msg.dev_type}, {'list.$.origin':msg.origin}, function(doc){});
/*
                            MH.findUpdate(DB_TGCFG, 'TG_01', {'dev_type':msg.dev_type}, {'origin':msg.origin}, function(thr){
                                    QH.publishMsg('SC/THR/' + msg.userid, JSON.stringify({
                                    type: 'changeThrRes',
                                    userid: msg.userid,
                                    tgid: msg.tgid,
                                    origin: msg.origin
                                }));
                            });
*/

                            SC_Console.midPrint('Transffered threshold data to Application...');
                            SC_Console.endPrint();

                        } else if (spTopic[1] === 'SERV') {
                            if(spTopic[2] == "USER_01"){
                                SC_Console.midPrint('Action : APP Service List Request');
                                var user = spTopic[2];
                                SC_Console.midPrint('USER_ID : ' + user);
                                if (msg.type == 'requestService') {
                                    SC_Console.midPrint('Action : APP Service List Request');
                                    var service_data = '[';
                                    MH.findAll(DB_SCCFG, 'service', {}, function (DB_SCCFG) {
                                        for (var i = 0; i < DB_SCCFG.length; i++) {
                                            service_data += (JSON.stringify({
                                                service_id: DB_SCCFG[i].service_id,
                                                description: DB_SCCFG[i].description
                                            }));

                                            if (i == DB_SCCFG.length - 1)
                                                service_data += ']';
                                            else
                                                service_data += ',';
                                        }
                                    //SC_Console.midPrint(service_data);
                                        if (msg.data == '') {
                                            QH.publishMsg('SC/SERV/' + msg.userid, JSON.stringify({
                                                type: 'responseService',
                                                userid: msg.userid,
                                                tgid: msg.tgid,
                                                data: service_data
                                            }));
                                        }
                                        else {
                                            SC_Console.midPrint('data : ' + msg.data);
                                        //   for( var i in msg.data)
                                        //      SC_Console.midPrint('data : ' +msg.data[i].server_id);
                                        }
                                    });
                                } else if (msg.type == 'responseService') {
                                    SC_Console.midPrint('response to APP complete');
                                } else if (msg.type == 'requestServiceDetail') {
                                    SC_Console.midPrint('Action : APP Service List Request');
                                //MH.findAll(DB_SCCFG, 'service', {service_id : msg.data}, function(DB_SCCFG){
                                    MH.findAll(DB_TGCFG, msg.tgid, {service_id: msg.data}, function (DB_TGCFG) {
                                        SC_Console.midPrint('Service Detail : ' + DB_TGCFG.act);
                                    });
                                }
                            } else if(spTopic[2] == "TG_01"){
                                SC_Console.midPrint('response from '+spTopic[2]);

                                var coll_name = spTopic[2];
                                
                                var flag = 0;

                                // 만약 db에 같은 dev_type을 가진게 있으면 flag를 1로...
                                MH.findAll(DB_TGCFG, coll_name, {}, function(tgcfg){



                                    // db에 값이 있는지 없는지 검사
                                    if(tgcfg == '[]'){

                                        MH.insertOne(DB_TGCFG, coll_name, {
                                            'type': msg.type,
                                            'userid': msg.userid,
                                            'tgid': msg.tgid,
                                            'list':[{
                                                'origin': msg.origin,
                                                'dev_type': msg.dev_type,
                                                'sensor': msg.sensor
                                            }]
                                        },function(err){
                                            SC_Console.midPrint(err);
                                        });
                                    } else {
                                        for(var i = 0; i < tgcfg[0].list.length; i++){
                                            if(tgcfg[0].list[i].dev_type == msg.dev_type){
                                                flag = 1;
                                            }
                                        }

                                        console.log(flag);

                                        // flag가 1이면 db 업데이트
                                        if(flag){
                                            MH.findUpdate(DB_TGCFG, coll_name, {'list.dev_type': msg.dev_type}, {'list.$.origin':msg.origin}, function(doc){});
                                        // flag가 0이면(db에 해당 dev_type의 서비스가 없으면) db에 insert
                                        } else{
                                            
                                            MH.findPush(DB_TGCFG, coll_name, {'tgid':coll_name},{
                                                'list':
                                                {
                                                    $each:[{
                                                        'origin':msg.origin,
                                                        'dev_type':msg.dev_type,
                                                        'sensor':msg.sensor
                                                    }]
                                                }
                                            
                                            },function(err){console.log(err);});

                                        }
                                    }
                                  
                                });
                            }
                        } else if (spTopic[1] === 'THR') {
                            if(msg.type == 'requestThr'){
                                SC_Console.midPrint('Action : APP Threshold Request');

                                MH.findAll(DB_TGCFG, msg.tgid, {'list.dev_type':msg.data}, function(thr){
                                    for(var i = 0 ; i< thr[0].list.length; i++){
                                        if(thr[0].list[i].dev_type == msg.data){
                                            QH.publishMsg('SC/THR/' + msg.userid, JSON.stringify({
                                                type: 'responseThr',
                                                userid: msg.userid,
                                                tgid: msg.tgid,
                                                dev_type: thr[0].list[i].dev_type,
                                                origin: thr[0].list[i].origin
                                            }));
                                        }
                                    }
                                });
/*
                                DB_TGCFG.collection(msg.tgid).find( {'tgid':msg.tgid},function(thr){
                                    console.log(thr);
                                });

                                MH.findAll(DB_TGCFG, 'TG_01', {}, function (thr) {
                                    
                                    for (var i = 0; i < thr[0].list.length; i++){
                                        
                                        QH.publishMsg('SC/THR/' + msg.userid, JSON.stringify({
                                            type: 'responseThr',
                                            userid: msg.userid,
                                            tgid: msg.tgid,
                                            dev_type: thr[0].list[i].dev_type,
                                            origin: thr[0].list[i].origin
                                        }));
                                    }

                                });
*/                                
                            } else if(msg.type == 'changeThrReq'){
                                SC_Console.midPrint('Action : APP Threshold Change Request');

                                QH.publishMsg('kocom/TGThr/TG_01', JSON.stringify({
                                    origin: msg.origin,
                                    tgid: msg.tgid,
                                    userid: msg.userid,
                                    type: msg.type
                                }));
                            }

                            /*
                            SC_Console.midPrint('Action : APP Threshold Request');
                            if (msg.type.indexOf('Req')) {
                                if (msg.type == 'changeThrReq')
                                    var t = 'changeThrReq';
                                else
                                    var t = 'requestThrReq';
                                QH.publishMsg(TGThr_TOPIC + msg.tgid, JSON.stringify({
                                    type: t,
                                    userid: msg.userid,
                                    tgid: msg.tgid,
                                    data: msg.data
                                }));
                            }
                            SC_Console.midPrint('Transffered threshold request to TG...');
                            SC_Console.endPrint();
                            */
                        } else if (spTopic[1] === 'registerTG') {
                            SC_Console.midPrint('Action : Thin-Gateway Registration First Step');
                            SC_Console.midPrint('TG ID : ' + msg.thID);
                            SC_Console.midPrint('S/N Number : ' + msg.secureNum);
                            var HASH_KEY = CryptoJS.SHA256(msg.secureNum);
                            SC_Console.midPrint('Hash Key Created...');

                            var TOPIC_DATA = 'kocom';
                            var IV_KEY = CryptoJS.enc.Hex.parse('01010101010101010101010101010101');
                            var encrypted = CryptoJS.AES.encrypt(JSON.stringify({seed: TOPIC_DATA}), HASH_KEY, {
                                iv: IV_KEY
                            });
                            SC_Console.midPrint('Encryption Finished...' + encrypted.ciphertext);

                            var decrypted = CryptoJS.AES.decrypt(encrypted, HASH_KEY, {
                                iv: IV_KEY
                            }).toString(CryptoJS.enc.Utf8);
                            SC_Console.midPrint('Decryption Test : ' + ((JSON.parse(decrypted).seed === TOPIC_DATA) ? 'PASS' : 'FAIL'));

                            QH.publishMsg(msg.thID, JSON.stringify({type: '00', data: encrypted.toString()}));
                            SC_Console.midPrint('Thin-Gateway Registration Finished...');
                        } else if (spTopic[1] === 'PUSH') {

                        } else {
                            SC_Console.midPrint('Wrong Topic...');
                        }
                    } else {
                        SC_Console.midPrint('Wrong Topic...');
                    }

                } catch(err) {
                    SC_Console.midPrint(err);
                }

                SC_Console.endPrint();
            });
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
            SC_Console.midPrint("Update a document of " + coll + " collection to: " + result);
            callback(result);
        });
    },
    findPush: function (db, coll, doc, updoc, callback) {
        assert.notEqual(DB_URI, '', 'DB_URI must be assigned!!!');
        assert.notEqual(db, null, 'DB must be initialized!!!');

        db.collection(coll).findOneAndUpdate(doc, {$push: updoc}, {returnOriginal: false}, function (err, result) {
            assert.equal(err, null);
            SC_Console.midPrint("Push a document of " + coll + " collection to: " + result);
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

SC_Console.startPrint('Smart Cloud Initializing...');
SC_Console.midPrint("Smart Cloud Configuration DB URI : " + DB_URI + CFG_DB);
SC_Console.midPrint("Connecting to Smart Cloud Configuration DB ...");
MongoClient.connect(DB_URI + CFG_DB, function (err, db_SCCFG) {
    DB_SCCFG = db_SCCFG;
    SC_Console.midPrint("Finished.");

    SC_Console.midPrint("Initialize KEY_TOPIC...");
    MH.removeAll(DB_SCCFG, 'key', function () {
        SC_Console.midPrint('Previous KEY_TOPIC is Removed');
        
        MH.insertOne(DB_SCCFG, 'key', {key: KEY_TOPIC}, function () {
            SC_Console.midPrint('New KEY_TOPIC is Inserted (' + KEY_TOPIC + ')');

            SC_Console.midPrint("Thin-Gateway Configuration DB URI : " + DB_URI + TG_DB);
            SC_Console.midPrint("Connecting to Thin-Gateway Configuration DB ...");
            MongoClient.connect(DB_URI + TG_DB, function (err, db_TGCFG) {
                DB_TGCFG = db_TGCFG;
                SC_Console.midPrint("Finished.");

                SC_Console.midPrint("Group Data DB URI : " + DB_URI + GRP_DB);
                SC_Console.midPrint("Connecting to Group Data DB ...");
                MongoClient.connect(DB_URI + GRP_DB, function (err, db_GRP) {
                    DB_GRP = db_GRP;
                    SC_Console.midPrint("Finished.");

                    SC_Console.midPrint("Log Data List DB URI : " + DB_URI + LOG_DB);
                    SC_Console.midPrint("Connecting to Log Data List DB ...");
                    MongoClient.connect(DB_URI + LOG_DB, function (err, db_LOG) {
                        DB_LOG = db_LOG;
                        SC_Console.midPrint("Finished.");

                        SC_Console.midPrint("Sensor Data List DB URI : " + DB_URI + SS_DB);
                        SC_Console.midPrint("Connecting to Sensor Data List DB ...");
                        MongoClient.connect(DB_URI + SS_DB, function (err, db_SS) {
                            DB_SS = db_SS;
                            SC_Console.midPrint("Finished.");
                            SC_Console.endPrint();

                            QH.initQH();
                        });
                    });
                });
            });
        });
    });
});
