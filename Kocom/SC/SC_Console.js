var bDEBUG = true;

module.exports = {
    setDEBUG: function setDEBUG(DEBUG){
        bDEBUG = DEBUG;
    },
    startPrint: function startPrint(title) {
        console.log('==================================================');
        console.log(getTimeLog() + ' - ' + title);
        console.log('--------------------------------------------------');
    },
    midPrint: function midPrint(note) {
        console.log('+ ' + note);
    },
    endPrint: function endPrint() {
        console.log('==================================================\n');
    },
    errPrint: function errorPrint(err) {
        console.log('==================================================');
        console.log('ERROR - ' + err);
        console.log('==================================================\n');
    },
    notyPrint: function errorPrint(note) {
        console.log('==================================================');
        console.log(note);
        console.log('==================================================\n');
    }
};

var getTimeLog = function () {
    var currentdate = new Date();
    var datetime = currentdate.getFullYear() + "/"
            + getCorrectTime((currentdate.getMonth() + 1)) + "/"
            + getCorrectTime(currentdate.getDate()) + " "
            + getCorrectTime(currentdate.getHours()) + ":"
            + getCorrectTime(currentdate.getMinutes()) + ":"
            + getCorrectTime(currentdate.getSeconds());
    return datetime;
};

var getCorrectTime = function(data){
    if(data < 10){
        return '0' + data;
    } else {
        return data;
    }
};