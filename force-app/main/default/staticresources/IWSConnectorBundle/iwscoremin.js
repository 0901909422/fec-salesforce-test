var sessionid = '';
var debug = true;
var myurl = '';
var initparams;
var clienttimeout = 20000;
var myTimer;
var bexit = false;
var ref_frame = null;
var path_image = '';
var div_name = '#IWSConnectorToolbar';
var b_cmbInteraction = false;
var b_imgState = false;
var b_lblMessage = false;
var clientType = 'default';
var _sipDisasterRecovery = false;
var _multyInteractions = true;
var _multyInteractionEvents = false;
var _enablePlaceHolder = false;
var IWSC_PLACEHOLDER = 'WDEC_INTERACTIONSELECTED';
var _iwsApplicationName = '';
var myprotocol = 'http';
var VERSION = '1.7.2.1';
var DEFAULT_OPTION = '== Interactions ==';
var compactMenu = false;
if (typeof (WDEConnector) == 'undefined') {
    WDEConnector = {
        isActive: false,
        isConnected: false
    }
};


//ARETEANS - BEGIN
var myInteractions = createUserData();
var makeCallParams = createUserData();
//ARETEANS - END



function getSessionId() {
    return sessionid
}

function setIwsApplicationName(iwsappname) {
    _iwsApplicationName = iwsappname
}

function getIwsApplicationName() {
    return _iwsApplicationName
}

function getVersion() {
    return VERSION
}

function setServerUrl(server, port) {
    myurl = myprotocol + '://' + server + ':' + port + '/';
    log['infoFormat']('Connector Url[{0}]', myurl)
}

function setSecureServerUrl(server, port) {
    myprotocol = 'https';
    setServerUrl(server, port)
}

function createSecureConnection(server, port, myparams) {
    myprotocol = 'https';
    log['info']('Set HTTPS protocol ');
    createConnection(server, port, myparams)
}

function createConnection(server, port, myparams) {
    log['info']('createConnection');
    setServerUrl(server, port);
    initparams = myparams;
    if (myparams) {
        if (myparams['type']) {
            clientType = myparams['type']
        }
    };
    log['info']('Client Group: ' + clientType);
    myTimer = setInterval(function () {
        startConnection(myparams)
    }, 5000);
    setTimeout(function () {
        startConnection(myparams)
    }, 500)
}

function createConnectionRecovery() {
    log['info']('createConnectionRecovery');
    showDisconnectedState();
    myTimer = setInterval(function () {
        startConnection(initparams)
    }, 10000)
}

function myStopFunction() {
    log['debug']('Stop Timer');
    clearInterval(myTimer)
}

function getWdeJsonp() {
    if (typeof jQuery['jsonp'] === 'function') {
        return jQuery['jsonp']
    };
    return $['jsonp']
}

function testJsonp() {
    var myjsonp = getWdeJsonp();
    myjsonp({
        url: myurl + 'TEST',
        data: {
            "\x70\x61\x72\x61\x6D\x31": 'value1'
        },
        dataType: 'jsonp',
        callbackParameter: 'jsonp_callback',
        timeout: 5000,
        success: function (data, status) {
            log['debug']('success ' + data)
        },
        error: function (XHR, textStatus, errorThrown) {
            log['error']('error in contact IWS\x0Astatus: ' + textStatus + '\x0Adetails: ' + errorThrown)
        }
    })
}

function startConnection(myparams) {
    try {
        var myjsonp = getWdeJsonp();
        myjsonp({
            url: myurl + 'CREATECONNECTION',
            data: myparams,
            dataType: 'jsonp',
            callbackParameter: 'jsonp_callback',
            timeout: 3000,
            success: function (data, status) {
                log['info']('success Connection ' + data);
                myStopFunction();
                if (data['sessiontimeout']) {
                    clienttimeout = data['sessiontimeout']
                };
                sessionid = data['sessionid'];
                log['info']('success id: ' + sessionid);
                log['info']('clienttimeout: ' + clienttimeout);

                log['info']('Start Long Polling ...');
                getEventWorkspace();
                log['info']('End Long Polling ...');
            },
            error: function (XHR, textStatus, errorThrown) {
                log['error']('error in contact IWS\x0Astatus: ' + textStatus + '\x0Adetails: ' + errorThrown)
            }
        })
    } catch (e) {
        log['debug'](e['message'])
    }
}

function getEventWorkspace() {
    try {
        log['info']('Handle getEventWorkspace ... ');
        if (!sessionid) {
            log['warn']('Session closed!');
            return
        };

        var myjsonp = getWdeJsonp();
        myjsonp({
            url: myurl + 'EVENT',
            data: {
                "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid
            },
            dataType: 'jsonp',
            callbackParameter: 'jsonp_callback',
            timeout: clienttimeout,
            success: function(data, status) {
                log['info']('success getEventWorkspace ' + data);
                handleEvent(data);
                getEventWorkspace();
            },
            error: function(XHR, textStatus, errorThrown) {
                log['error']('error in read event from IWS \x0Astatus: ' + textStatus + '\x0Adetails: ' + errorThrown);
                if (!bexit) {
                    // createConnectionRecovery()
                    log['warn']('Retrying getEventWorkspace in 5s...');
                    setTimeout(getEventWorkspace, 5000); // Thử lại Long Polling, không cần tạo lại Connection
                }
            }
        })
    } catch (e) {
        log['error']('FATAL ERROR inside getEventWorkspace: ' + e['message']);
        // Bắt buộc phải thêm lệnh gọi recovery nếu nó bị lỗi ở đây
        if (!bexit) {
            log['warn']('Retrying getEventWorkspace in 5s due to internal error...');
            setTimeout(getEventWorkspace, 5000); 
       }
    }
}

function handleEvent(message) {
    try {
        if (message['EVENT'] == 'KeepAlive') {
            return
        };
        log['info'](JSON['stringify'](message));
        if (isFilter()) {
            log['debugFormat']('====== Filters defined, try check to [{0}]', message.EVENT);
            var action = getActionFilter(message);
            if (action) {
                log['debugFormat']('====== Filter defined to [{0}], try execute action', message.EVENT);
                var bret = executeActionFilter(message, action);
                log['debug']('====== Filter Action Return: ' + bret);
                if (!bret) {
                    log['infoFormat']('Filter break event cicle: {0}', message.EVENT);
                    return
                }
            } else {
                log['debug']('====== No Filter Founded ===')
            }
        };
        if (message && message['EVENT']) {
            var sevent = message['EVENT'];
            if (message['MediaType']) {
                sevent = message['EVENT'] + (message['CallType'] ? message['CallType'] : '');
                updateJSONObjectInMemory(message)
            };
            log['info']('Try to call Event on' + sevent);
            if (checkFunction('onPre' + sevent)) {
                var ret1 = callSafetyFunction('onPre' + sevent + '(message);', message);
                log['debugFormat']('Pre Event Return: {0}', ret1);
                if ((ret1 != null) && (ret1 === false)) {
                    log['debugFormat']('Pre Event onPre{0} stop the chain', sevent);
                    return
                }
            };
            if (isMultyInteractions() || isMultyInteractionsEvents()) {
                callSafetyFunction('on' + sevent + '(message);', message)
            } else {
                handleEventMultyInteractions(sevent, message)
            };
            if (checkFunction('onPost' + sevent)) {
                callSafetyFunction('onPost' + sevent + '(message);', message)
            }
        } else {
            log['warn']('No Handle Events')
        }
    } catch (e) {
        log['error']('HandleEvent: ' + e['message'])
    }
}

function handleEventMultyInteractions(sevent, message) {
    try {
        log['debug']('[handleEventMultyInteractions] Init');
        if (countInteractions() == 0) {
            log['debug']('[handleEventMultyInteractions] Interaction Count 0');
            callSafetyFunction('on' + sevent + '(message);', message)
        } else {
            var selid = getSelectedInteractionId();
            log['debugFormat']('[handleEventMultyInteractions] Selected ID[{0}] ConnectionID[{1}]', selid, message.ConnectionID);
            if (!selid) {
                log['debug']('[handleEventMultyInteractions] No Selected Element in Multi Interactions Combo, throw Event...');
                callSafetyFunction('on' + sevent + '(message);', message);
                return
            };
            if (isCampaign(message)) {
                var currid = getRecordHandle(message);
                log['debugFormat']('[handleEventMultyInteractions] Check ID[{0}] Current ConnectionID[{1}]', selid, currid);
                if (selid == currid) {
                    log['debugFormat']('[handleEventMultyInteractions] throws the Event [{0}]', sevent);
                    callSafetyFunction('on' + sevent + '(message);', message)
                } else {
                    log['debugFormat']('[handleEventMultyInteractions] discard the Event [on{0}]', sevent)
                }
            } else {
                if (message['ConnectionID']) {
                    var currid = message['ConnectionID']['toLowerCase']();
                    log['debugFormat']('[handleEventMultyInteractions] Check ID[{0}] Current ConnectionID[{1}]', selid, currid);
                    if (selid == currid) {
                        log['debugFormat']('[handleEventMultyInteractions] throws the Event [{0}]', sevent);
                        callSafetyFunction('on' + sevent + '(message);', message)
                    } else {
                        log['debugFormat']('[handleEventMultyInteractions] discard the Event [on{0}]', sevent)
                    }
                } else {
                    log['debug']('[handleEventMultyInteractions] Message without ConnectionID, throw Event...');
                    callSafetyFunction('on' + sevent + '(message);', message)
                }
            }
        }
    } catch (e) {
        log['error']('HandleEventMultyInteractions: ' + e['message'])
    }
}

function isSelectedInteraction(message) {
    var selid = getSelectedInteractionId();
    if (!selid) {
        return false
    };
    var currid = (isCampaign(message) ? getRecordHandle(message) : message['ConnectionID']['toLowerCase']());
    return (selid == currid)
}

function callSafetyFunction(function_name, message) {
    try {
        log['debugFormat']('Calling [{0}]', function_name);
        return eval(function_name)
    } catch (e) {
        log['error'](e['message'])
    };
    return true
}

function checkFunction(function_name) {
    if (eval('typeof ' + function_name + ' == \'function\'')) {
        log['debug']('Exist function: ' + function_name);
        return true
    } else {
        log['warn']('Not Exist function: ' + function_name);
        return false
    }
}

function onKeepAlive(message) { }

function getMessageId(message) {
    var id = '';
    if (isCampaign(message)) {
        id = '' + getRecordHandle(message)
    } else {
        id = message['ConnectionID']
    };
    log['debugFormat']('[getMessageId] id[{0}]', id);
    return id
}
var enumloglevel = {
    "\x64\x65\x62\x75\x67": 3,
    "\x69\x6E\x66\x6F": 2,
    "\x77\x61\x72\x6E": 1,
    "\x65\x72\x72\x6F\x72": 0,
    "\x6E\x6F\x6E\x65": -1
};
var loglevel = enumloglevel['error'];
var log = {
    debug: log_debug,
    info: log_info,
    warn: log_warn,
    error: log_error,
    infoFormat: log_infoFormat,
    debugFormat: log_debugFormat,
    warnFormat: log_warnFormat,
    errorFormat: log_errorFormat
};

function setLogLevel(level) {
    loglevel = level
}

function log_debug(message) {
    if (loglevel >= enumloglevel['debug']) {
        trace(' DEBUG:	' + message)
    }
}

function log_info(message) {
    if (loglevel >= enumloglevel['info']) {
        trace(' INFO:	' + message)
    }
}

function log_warn(message) {
    if (loglevel >= enumloglevel['warn']) {
        trace(' WARN:	' + message)
    }
}

function log_error(message) {
    if (loglevel >= enumloglevel['error']) {
        trace(' ERROR:	' + message)
    }
}

function log_infoFormat() {
    if (loglevel < enumloglevel['info']) {
        return
    };
    var s = createFormatMessage(arguments);
    trace(' INFO:	' + s)
}

function log_debugFormat() {
    if (loglevel < enumloglevel['debug']) {
        return
    };
    var s = createFormatMessage(arguments);
    trace(' DEBUG:	' + s)
}

function log_warnFormat() {
    if (loglevel < enumloglevel['warn']) {
        return
    };
    var s = createFormatMessage(arguments);
    trace(' WARN:	' + s)
}

function log_errorFormat() {
    if (loglevel < enumloglevel['warn']) {
        return
    };
    var s = createFormatMessage(arguments);
    trace(' ERROR:	' + s)
}

function createFormatMessage(arguments) {
    var s = '';
    try {
        var sapp = 's = \'' + arguments[0] + '\'.format(';
        for (var i = 1; i < arguments['length']; i++) {
            if (i > 1) {
                sapp += ', '
            };
            sapp += '\'' + arguments[i] + '\''
        };
        sapp += ');';
        eval(sapp)
    } catch (e) {
        log['error']('Error in format log message: ' + e['message'])
    };
    return s
}

function trace(message) {
    try {
        currentTime = new Date();
        setTimeout(function () {
            saveLogIntoIndexedDB(message, currentTime);
        }, 500);
    } catch (e) { }
    try {
        console['log'](new Date()['toLocaleTimeString']() + ' IWSC ' + VERSION + message)
    } catch (e) { }
}
var mapInteractions = new Object();

function updateJSONObjectInMemory(message) {
    log['debug']('Try to UpdateJSONObjectInMemory: ' + message);
    try {
        var key = null;
        if (isCampaign(message)) {
            key = '' + getRecordHandle(message)
        } else {
            if (message['ConnectionID']) {
                key = message['ConnectionID']['toLowerCase']()
            }
        };
        if (key) {
            if (existInteraction(key)) {
                addInteraction(key, message);
                log['debug']('Executed UpdateJSONObjectInMemory: ' + message)
            }
        }
    } catch (e) {
        log['error']('UpdateJSONObjectInMemory: ' + e['message'])
    }
}

function removeJSONObjectInMemory(key) {
    log['debug']('Try to remove key:' + key);
    try {
        if (key) {
            key = key['toLowerCase']();
            log['error']('Try to remove removeInteraction key:' + key);
            removeInteraction(key);
            log['error']('Try to remove removeInteractionOption key:' + key);
            removeInteractionOption(key)
        }
    } catch (e) {
        log['error']('RemoveJSONObjectInMemory: ' + e['message'])
    }
}

function addJSONObjectInMemory(message, selected) {
    var myselected = false;
    if (typeof selected != 'undefined') {
        myselected = selected
    } else {
        if (isMultyInteractions()) {
            myselected = true
        } else {
            log['debug']('countInteractions: ' + countInteractions());
            myselected = (countInteractions() < 1)
        }
    };
    log['debugFormat']('[addJSONObjectInMemory] origin selected[{0}] new selected[{1}]', selected, myselected);
    try {
        if (message['ConnectionID']) {
            if (!existInteraction(message['ConnectionID']['toLowerCase']())) {
                addInteraction(message['ConnectionID']['toLowerCase'](), message);
                var s = getMultiInteractionFormated(message.MediaName, message);
                addInteractionOption(message['ConnectionID']['toLowerCase'](), s, myselected)
            }
        }
    } catch (e) {
        log['error']('AddJSONObjectInMemory: ' + e['message'])
    }
}

function addJSONObjectInMemoryCampaign(message, selected) {
    try {
        var myselected = false;
        if (typeof selected != 'undefined') {
            myselected = selected
        } else {
            if (isMultyInteractions()) {
                myselected = true
            } else {
                log['debug']('countInteractions: ' + countInteractions());
                myselected = (countInteractions() < 1)
            }
        };
        log['debugFormat']('[addJSONObjectInMemory] origin selected[{0}] new selected[{1}]', selected, myselected);
        var recordhandle = '' + getRecordHandle(message);
        log['debug']('addJSONObjectInMemoryCampaign: recordhandle is ' + recordhandle);
        if (!existInteraction(recordhandle)) {
            addInteraction(recordhandle, message);
            var s = getMultiInteractionFormated('preview', message);
            addInteractionOption(recordhandle, s, myselected)
        } else {
            log['debug']('addJSONObjectInMemoryCampaign: removed selectInteractionOption for recordhandle ' + recordhandle)
        }
    } catch (e) {
        log['error']('AddJSONObjectInMemoryCampaign: ' + e['message'])
    }
}
String['prototype']['format'] = function () {
    var args = arguments;
    return this['replace'](/{(\d+)}/g, function (match, number) {
        return typeof args[number] != 'undefined' ? args[number] : match
    })
};
if (typeof String['prototype']['startsWith'] != 'function') {
    String['prototype']['startsWith'] = function (str) {
        return this['slice'](0, str['length']) == str
    }
};

function addInteraction(key, message) {
    mapInteractions[key] = message;
    log['debug']('added message in memory, key: ' + key + ' Name:' + message['EVENT']);
    if (isCompactMenu()) {
        updateUIInteractionCounter()
    }
}

function getInteraction(key) {
    key = key['toLowerCase']();
    return mapInteractions[key]
}

function existInteraction(key) {
    var bret = false;
    key = key['toLowerCase']();
    bret = (mapInteractions[key] != null);
    log['debug']('existInteraction key:' + key + ' - ' + bret);
    return bret
}

function removeInteraction(key) {
    try {
        key = key['toLowerCase']();
        delete (mapInteractions[key]);
        log['debug']('removed message from memory, key: ' + key);
        if (isCompactMenu()) {
            updateUIInteractionCounter()
        }
    } catch (e) {
        log['warn']('Error in remove message from memory, key: ' + key)
    }
}

function getFirstInteraction() {
    var retmessage = null;
    for (var key in mapInteractions) {
        retmessage = mapInteractions[key];
        break
    };
    return retmessage
}

function getFirstInteractionId() {
    var retkey = null;
    for (var key in mapInteractions) {
        retkey = key;
        break
    };
    return retkey
}

function existActiveInteraction(medianame) {
    var media = (medianame ? medianame : 'voice');
    return (countActiveInteractions(media) > 0)
}

function countActiveInteractions(medianame) {
    var count = 0;
    var media = (medianame ? medianame : 'voice');
    log['debug']('countActiveInteractions for media: ' + media);
    var appInteraction = null;
    for (var key in mapInteractions) {
        try {
            appInteraction = mapInteractions[key];
            log['debug']('countActiveInteractions check interaction with key: ' + key);
            if (appInteraction && appInteraction['MediaName']) {
                if (appInteraction['MediaName'] == media) {
                    count++
                }
            }
        } catch (e) {
            log['warn']('countActiveInteractions: ' + e['message'])
        }
    };
    log['debugFormat']('countActiveInteractions  medianame [{0}] count [{1}] ', media, count);
    return count
}

function countInteractions() {
    var count = 0;
    for (var key in mapInteractions) {
        count++
    };
    return count
}

function isValidProperty(object) {
    return (typeof object !== 'undefined' || object !== null)
}

function isCompactMenu() {
    return compactMenu
}

function getElementFromCombo(key) {
    var objsel;
    var combo = getComboInteraction();
    if (isCompactMenu()) {
        objsel = combo['find']('li[key=\'' + key + '\']')
    } else {
        objsel = combo['find']('option[value=\'' + key + '\']')
    };
    log['debugFormat']('getElementFromCombo [{0}] ', objsel);
    return objsel
}

function removeInteractionOption(key) {
    try {
        if (!existOptionInteractions()) {
            return
        };
        var selectedid = getSelectedInteractionId();
        var objdel = getElementFromCombo(key);
        log['debug']('removeInteractionOption: ' + objdel);
        log['debugFormat']('removeInteractionOption: selected[{0}] to remove[{1}]', selectedid, key);
        objdel['remove']();
        if (isCompactMenu()) {
            updateUIInteractionCounter()
        };
        if (!notExistInteractionOptions()) {
            if (selectedid == key) {
                switchInteraction()
            } else {
                log['debug']('switchInteraction not throw, because removed interaction was not the selected')
            }
        } else {
            addDefaultOption()
        }
    } catch (e) {
        log['error'](e['message'])
    }
}

function addInteractionOption(value, text, selected) {
    if (!existOptionInteractions()) {
        return
    };
    var combo = getComboInteraction();
    var objel = getElementFromCombo(value);
    try {
        if (objel['length'] > 0) {
            log['debug']('Already Exist Option : ' + value);
            return
        } else {
            log['debug']('Not Exist Option : ' + value)
        }
    } catch (e) {
        log['error'](e['message'])
    };
    var scombo = (isCompactMenu() ? '<li onclick=\'handleOptionClick(this)\' key=\'{0}\' {1}>{2}</li>' : '<option value=\'{0}\' {1}>{2}</option>');
    if (isCompactMenu()) {
        scombo = scombo['format'](value, (selected ? 'class=\'_selected\'' : ''), text)
    } else {
        scombo = scombo['format'](value, (selected ? 'selected' : ''), text)
    };
    if (isCompactMenu() && selected) {
        log['debug']('try remove selection before add a new one');
        var currselecte = combo['find']('._selected');
        if (currselecte) {
            currselecte['removeClass']('_selected')
        }
    };
    log['debug']('append in combomultiinteraction: ' + scombo);
    combo['append'](scombo);
    if (isCompactMenu()) {
        updateUIInteractionCounter()
    };
    if (isEnablePlaceHolder()) {
        SetInteractionOnWde(message.ConnectionID)
    };
    removeDefaultOption()
}

function getUIInteractionCounter() {
    return getElement('#iwsInteractionCounter')
}

function updateUIInteractionCounter() {
    var iwsCounter = getUIInteractionCounter();
    iwsCounter['text'](countInteractions())
}

function selectInteractionOptionByMessage(message) {
    var key = null;
    try {
        if (isCampaign(message)) {
            key = getRecordHandle(message)
        } else {
            key = message['ConnectionID']['toLowerCase']()
        };
        log['debugFormat']('selectInteractionOptionByMessage for key {0}', key);
        selectInteractionOption(key)
    } catch (e) {
        log['error']('selectInteractionOptionByMessage: ' + e['message'])
    }
}

function changeInteractionText(message, messageFormat, parametersValue) {
    log['debug']('[changeInteractionText] Init...');
    var key = null;
    if (!existOptionInteractions()) {
        return
    };
    if (isCampaign(message)) {
        key = '' + getRecordHandle(message)
    } else {
        key = message['ConnectionID']
    };
    log['debugFormat']('[changeInteractionText] key [{0}] messageFormat[{1}]', key, messageFormat);
    var objel = getElementFromCombo(key);
    try {
        if (objel['length'] > 0) {
            log['debugFormat']('[changeInteractionText] Option founded {0}', key);
            var message_temp = getInteraction(key);
            var stext = '';
            eval('stext = \'' + messageFormat + '\'.format(' + parametersValue + ');');
            if (stext) {
                objel['text'](stext)
            };
            return
        } else {
            log['debugFormat']('[updateInteractionText] Not Exist Option {0}', key);
            return
        }
    } catch (e) {
        log['error'](e['message'])
    }
}

function updateInteractionText(message) {
    log['debug']('[updateInteractionText] Init...');
    var key = null;
    var medianame = null;
    if (!existOptionInteractions()) {
        return
    };
    if (isCampaign(message)) {
        key = '' + getRecordHandle(message);
        medianame = 'preview'
    } else {
        key = message['ConnectionID'];
        medianame = message['MediaName']
    };
    log['debugFormat']('[updateInteractionText] key [{0}] media[{1}]', key, medianame);
    var objel = getElementFromCombo(key);
    try {
        if (objel['length'] > 0) {
            log['debugFormat']('[updateInteractionText] Option founded {0}', key);
            var message_temp = getInteraction(key);
            var stext = getMultiInteractionFormated(medianame, message_temp);
            if (stext) {
                objel['text'](stext)
            };
            return
        } else {
            log['debugFormat']('[updateInteractionText] Not Exist Option {0}', key);
            return
        }
    } catch (e) {
        log['error'](e['message'])
    }
}

function selectInteractionOption(key) {
    log['debug']('selectInteractionOption: ' + key);
    if (!existOptionInteractions()) {
        return
    };
    var objel = getElementFromCombo(key);
    try {
        if (objel['length'] > 0) {
            log['debug']('Try to select the Option : ' + key);
            if (isCompactMenu()) {
                objel['removeClass']('_selected')['addClass']('_selected')
            } else {
                objel['prop']('selected', 'selected')['change']()
            };
            return
        } else {
            log['debug']('Not Exist Option : ' + key)
        }
    } catch (e) {
        log['error'](e['message'])
    }
}

function hasSelectedInteraction() {
    if (!existOptionInteractions()) {
        return false
    };
    var selIntId = getSelectedInteractionId();
    if (selIntId) {
        if (DEFAULT_OPTION == selIntId) {
            return false
        } else {
            return true
        }
    };
    return false
}

function addEmptyOption() {
    if (isCompactMenu()) {
        return
    };
    var combo = getComboInteraction();
    combo['append']('<option value="emptykey" selected> </option>')
}

function removeEmptyOption() {
    if (isCompactMenu()) {
        return
    };
    var combo = getComboInteraction();
    var objdel = combo['find']('option[value=\'emptykey\']');
    if (objdel) {
        log['debug']('removeEmptyOption: ' + objdel);
        objdel['remove']()
    }
}

function removeDefaultOption() {
    if (isCompactMenu()) {
        return
    };
    var combo = getComboInteraction();
    var objdel = combo['find']('option[value=\'' + DEFAULT_OPTION + '\']');
    if (objdel) {
        log['debug']('removeDefaultOption: ' + objdel);
        objdel['remove']()
    }
}

function addDefaultOption() {
    if (isCompactMenu()) {
        return
    };
    if (notExistInteractionOptions()) {
        var combo = getComboInteraction();
        combo['append']('<option value="' + DEFAULT_OPTION + '" disabled="disabled">' + DEFAULT_OPTION + '</option>')
    }
}

function switchInteraction() {
    log['info']('switchInteraction Init...');
    try {
        var message = getSelectedInteraction();
        log['info']('switchInteraction Selected Message: ' + message['EVENT']);
        callSafetyFunction('onSwitchInteraction(message);', message);
        if (isEnablePlaceHolder()) {
            SetInteractionOnWde(message.ConnectionID)
        }
    } catch (e) {
        log['warn']('switchInteraction: ' + e['message'])
    };
    log['info']('switchInteraction End')
}

function notExistInteractionOptions() {
    var combo = getComboInteraction();
    if (isCompactMenu()) {
        return (combo['find']('li')['length'] < 1)
    } else {
        return (combo['find']('option')['length'] < 1)
    }
}

function existOptionInteractions() {
    log['debug']('Check combo interactions...');
    var ioption = getComboInteraction();
    if (ioption['length'] > 0) {
        log['debug']('combo interactions exist');
        return true
    } else {
        log['warn']('combo interactions not exist');
        return false
    }
}

function getSelectedInteractionId() {
    var selectedid = null;
    try {
        var combo = getComboInteraction();
        if (isCompactMenu()) {
            selectedid = combo['find']('._selected')['attr']('key')
        } else {
            selectedid = combo['find'](':selected')['val']()
        };
        log['debug']('[getSelectedInteractionId] Selected message key: ' + selectedid)
    } catch (e) {
        log['error']('GetSelectedInteractionId: ' + e['message'])
    };
    return selectedid
}

function getSelectedInteraction() {
    var message = null;
    try {
        var key = getSelectedInteractionId();
        log['debug']('[getSelectedInteraction] Selected message key: ' + key);
        message = getInteraction(key);
        log['debug']('[getSelectedInteraction] Selected message: ' + message)
    } catch (e) {
        log['error']('GetSelectedInteractionId: ' + e['message'])
    };
    return message
}

function getComboInteraction() {
    if (isCompactMenu()) {
        return getElement('.select')
    } else {
        return getElement('#interactions')
    }
}

function isEnablePlaceHolderInteraction(message) {
    var bret = false;
    log['debug']('isEnablePlaceHolderInteraction...');
    if (message[IWSC_PLACEHOLDER]) {
        log['debugFormat']('[isEnablePlaceHolderInteraction] [{0}] [{1}] ', IWSC_PLACEHOLDER, message[IWSC_PLACEHOLDER]);
        bret = (message[IWSC_PLACEHOLDER] == 'true')
    };
    log['debugFormat']('[isEnablePlaceHolderInteraction] return [{0}] ', bret);
    return bret
}

function showConnectedState() {
    WDEConnector['isConnected'] = true;
    changeImage('yellow')
}

function showActivedState() {
    WDEConnector['isActive'] = true;
    changeImage('green')
}

function showDisconnectedState() {
    WDEConnector['isActive'] = false;
    WDEConnector['isConnected'] = false;
    changeImage('red')
}

function changeImage(colorname) {
    if (!b_imgState) {
        return
    };
    var myimg = getElement('#connectorstate');
    myimg['attr']('src', path_image + 'led' + colorname + '.png');
    if (isCompactMenu()) {
        var iwsCounter = getUIInteractionCounter();
        iwsCounter['removeClass']('red yellow green')['addClass'](colorname)
    }
}

function isActiveConnection() {
    return WDEConnector['isActive']
}

function isConnected() {
    return WDEConnector['isConnected']
}

function setSipDisasterRecovery(val) {
    _sipDisasterRecovery = val;
    log['info']('sipDisasterRecovery = ' + _sipDisasterRecovery)
}

function isSipDisasterRecovery() {
    return _sipDisasterRecovery
}

function setMultyInteractions(val) {
    _multyInteractions = val;
    log['info']('multyInteractions = ' + _multyInteractions)
}

function isMultyInteractions() {
    return _multyInteractions
}

function setMultyInteractionsEvents(val) {
    _multyInteractionEvents = val;
    log['info']('multyInteractionEvents = ' + _multyInteractionEvents)
}

function isMultyInteractionsEvents() {
    return _multyInteractionEvents
}

function setPlaceHolder(val) {
    _enablePlaceHolder = val;
    log['info']('enablePlaceHolder = ' + _enablePlaceHolder)
}

function isEnablePlaceHolder() {
    return _enablePlaceHolder
}

function showEventMessage(text, millisectime, labelcolor) {
    if (!b_lblMessage) {
        return
    };
    if (isCompactMenu()) { } else {
        var objEl = getElement('#labelmessage');
        objEl['text'](text);
        if ((millisectime) && (millisectime > 0)) {
            setTimeout(function () {
                objEl['text']('')
            }, millisectime)
        };
        if (labelcolor) {
            objEl['css']('color', labelcolor)
        }
    }
}

function getElement(id) {
    if (ref_frame) {
        return jQuery(id, ref_frame['document'])
    } else {
        return jQuery(id)
    }
}
var bEnableRightClick = false;

function setEnableRightClick(benable) {
    bEnableRightClick = benable
}

function disableRightClick() {
    if (bEnableRightClick) {
        log['info']('The right click is Enabled');
        return
    };
    var mysection = null;
    if (ref_frame) {
        mysection = jQuery(ref_frame['document'])
    } else {
        mysection = jQuery(document)
    };
    if (mysection) {
        jQuery(mysection)['bind']('contextmenu', function (e) {
            return false
        })
    }
}
var bint = false;

function initIWSToolBar(placeframe, divname, imagepath, prefiximage) {
    ref_frame = placeframe;
    if (imagepath) {
        path_image = imagepath + '/'
    };
    if (divname) {
        div_name = divname
    };
    if (prefiximage) {
        path_image = path_image + prefiximage
    };
    bint = true
}

function handleMenuClick() {
    jQuery('#open')['click']()
}

function handleOptionClick(_ele) {
    if (jQuery(_ele)['hasClass']('_selected')) {
        log['debug']('handleOptionClick the element is already selected');
        handleMenuClick();
        return
    };
    var combo = getComboInteraction();
    var prevSelected = combo['find']('._selected');
    if (prevSelected['length'] > 0) {
        prevSelected['removeClass']('_selected')
    };
    jQuery(_ele)['addClass']('_selected');
    showEventMessage(jQuery(_ele)['text'](), 5000);
    handleMenuClick();
    switchInteraction()
}

function enableCompactMenu() {
    compactMenu = true
}

function showIWSToolBar(cmbInteraction, imgState, lblMessage) {
    if (!bint) {
        alert('ToolBar not initialized!!!');
        return
    };
    b_cmbInteraction = cmbInteraction;
    if (imgState) {
        b_imgState = imgState
    };
    if (lblMessage) {
        b_lblMessage = lblMessage
    };
    var objEl = getElement(div_name);
    if (isCompactMenu()) {
        if (cmbInteraction) {
            objEl['addClass']('search-select');
            var src = path_image + 'ledred.png';
            jQuery('<div onclick="handleMenuClick()" class="field"><div><img id="connectorstate" name="connectorstate" alt="state" src="' + src + '"/></div><div id ="iwsInteractionCounter" class="iwsInteractionCounter red">0</div></div><input id="open" type="checkbox" /><ul class="select"></ul>')['appendTo'](objEl)
        };
        if (imgState) { }
    } else {
        var tbl = jQuery('<table class="iwsTable" ></table>')['appendTo'](objEl);
        var row = jQuery('<tr></tr>')['appendTo'](tbl);
        if (cmbInteraction) {
            jQuery('<td></td>')['append']('<select class="iwsSelect" id="interactions" onChange="switchInteraction();" ><option value="' + DEFAULT_OPTION + '" disabled="disabled">' + DEFAULT_OPTION + '</option></select>')['appendTo'](row)
        } else {
            jQuery('<td></td>')['append']('<select class="iwsSelectHide" id="interactions" onChange="switchInteraction();" ><option value="' + DEFAULT_OPTION + '" disabled="disabled">' + DEFAULT_OPTION + '</option></select>')['appendTo'](row)
        };
        if (imgState) {
            jQuery('<td valign="middle"></td>')['append']('<img id="connectorstate" name="connectorstate" alt="state" src="' + path_image + 'ledred.png">')['appendTo'](row)
        };
        if (lblMessage) {
            jQuery('<td></td>')['append']('<span class="iwsMessage" id="labelmessage" name="labelmessage"></span>')['appendTo'](row)
        }
    };
    disableRightClick()
}

function getInternetExplorerVersion() {
    var rv = -1;
    if (navigator['appName'] == 'Microsoft Internet Explorer') {
        var ua = navigator['userAgent'];
        var re = new RegExp('MSIE ([0-9]{1,}[.0-9]{0,})');
        if (re['exec'](ua) != null) {
            rv = parseFloat(RegExp.$1)
        }
    } else {
        log['debug'](navigator['appName']);
        rv = 8.0
    };
    return rv
}

function isIE8orLater() {
    var ver = getInternetExplorerVersion();
    if (ver > -1) {
        if (ver >= 8.0) {
            return true
        }
    };
    return false
}
var mapFormatInteraction = new Object();

function addFormatInteraction(media_name, message_format, parameters_value) {
    media_name = media_name['toLowerCase']();
    mapFormatInteraction[media_name] = {
        mediaName: media_name,
        messageFormat: message_format,
        parametersValue: parameters_value
    }
}

function getFormatInteraction(media_name) {
    try {
        log['debug']('init getFormatInteraction...');
        media_name = media_name['toLowerCase']();
        if (isSipDisasterRecovery()) {
            if (media_name['startsWith']('voice')) {
                media_name = 'voice'
            }
        };
        var objval = mapFormatInteraction[media_name];
        log['debug']('getFormatInteraction media:' + media_name);
        log['debug']('getFormatInteraction format value:' + objval);
        if (objval != null) {
            return objval
        } else {
            return {
                mediaName: media_name,
                messageFormat: '{0}',
                parametersValue: 'message.InteractionID'
            }
        }
    } catch (e) {
        log['error']('GetFormatInteraction: ' + e['message']);
        return {
            mediaName: media_name,
            messageFormat: '{0}',
            parametersValue: 'message.InteractionID'
        }
    }
}

function getMultiInteractionFormated(media_name, message) {
    var s = '';
    var app = getFormatInteraction(media_name);
    eval('s = \'' + app['messageFormat'] + '\'.format(' + app['parametersValue'] + ');');
    return s
}

function isCampaign(message) {
    if (message['attachdata']) {
        if (message['attachdata']['GSW_RECORD_HANDLE']) {
            return true
        }
    };
    return false
}

function getRecordHandle(message) {
    try {
        return message['attachdata']['GSW_RECORD_HANDLE']
    } catch (e) {
        return null
    }
}

function getCampaignName(message) {
    try {
        return message['attachdata']['GSW_CAMPAIGN_NAME']
    } catch (e) {
        return null
    }
}
var map_filter = new Object();
var filter = false;

function addFilter(eventname, action) {
    filter = true;
    log['infoFormat']('added Filter [{0}]', eventname);
    map_filter[eventname] = action
}

function isFilter() {
    return filter
}

function getActionFilter(message) {
    var sevent = 'on' + message['EVENT'];
    if (message['MediaType']) {
        sevent = sevent + (message['CallType'] ? message['CallType'] : '')
    };
    log['debug']('[Filter] check Event: ' + sevent);
    var action = map_filter[sevent];
    return action
}

function getActionFilterByName(eventname) {
    log['debug']('[Filter] check Event: ' + eventname);
    var action = map_filter[eventname];
    return action
}

function executeActionFilter(message, action) {
    log['debug']('Try to call Action: ' + action);
    if (action) {
        var ret = callSafetyFunction(action + '(message);', message);
        log['debug']('Action ret: ' + ret);
        return ret
    };
    return true
}

function Hashtable() {
    this['clear'] = hashtable_clear;
    this['containsKey'] = hashtable_containsKey;
    this['containsValue'] = hashtable_containsValue;
    this['get'] = hashtable_get;
    this['isEmpty'] = hashtable_isEmpty;
    this['keys'] = hashtable_keys;
    this['put'] = hashtable_put;
    this['remove'] = hashtable_remove;
    this['size'] = hashtable_size;
    this['toString'] = hashtable_toString;
    this['toJson'] = hashtable_toJson;
    this['toJsonObject'] = hashtable_toJsonObject;
    this['values'] = hashtable_values;
    this['hashtable'] = new Array()
}

function hashtable_clear() {
    this['hashtable'] = new Array()
}

function hashtable_containsKey(key) {
    var exists = false;
    for (var i in this['hashtable']) {
        if (i == key && this['hashtable'][i] != null) {
            exists = true;
            break
        }
    };
    return exists
}

function hashtable_containsValue(value) {
    var contains = false;
    if (value != null) {
        for (var i in this['hashtable']) {
            if (this['hashtable'][i] == value) {
                contains = true;
                break
            }
        }
    };
    return contains
}

function hashtable_get(key) {
    return this['hashtable'][key]
}

function hashtable_isEmpty() {
    return (parseInt(this['size']()) == 0) ? true : false
}

function hashtable_keys() {
    var keys = new Array();
    for (var i in this['hashtable']) {
        if (this['hashtable'][i] != null) {
            keys['push'](i)
        }
    };
    return keys
}

function hashtable_put(key, value) {
    if (key == null) {
        throw 'NullPointerException {' + key + '},{' + value + '}'
    } else {
        this['hashtable'][key] = value
    }
}

function hashtable_remove(key) {
    var rtn = this['hashtable'][key];
    this['hashtable'][key] = null;
    return rtn
}

function hashtable_size() {
    var size = 0;
    for (var i in this['hashtable']) {
        if (this['hashtable'][i] != null) {
            size++
        }
    };
    return size
}

function hashtable_toString() {
    return JSON['stringify'](this['hashtable'])
}

function hashtable_toJson() {
    return JSON['stringify'](this['toJsonObject']())
}

function hashtable_toJsonObject() {
    var obj = {};
    for (var i in this['hashtable']) {
        if (this['hashtable'][i] != null) {
            obj[i] = this['hashtable'][i]
        }
    };
    return obj
}

function hashtable_values() {
    var values = new Array();
    for (var i in this['hashtable']) {
        if (this['hashtable'][i] != null) {
            values['push'](this['hashtable'][i])
        }
    };
    return values
}

function createUserData() {
    return new Hashtable()
}
if (typeof JSON !== 'object') {
    JSON = {}
};
(function () {
    'use strict';

    function f(n) {
        return n < 10 ? '0' + n : n
    }
    if (typeof Date['prototype']['toJSON'] !== 'function') {
        Date['prototype']['toJSON'] = function (key) {
            return isFinite(this.valueOf()) ? this['getUTCFullYear']() + '-' + f(this['getUTCMonth']() + 1) + '-' + f(this['getUTCDate']()) + 'T' + f(this['getUTCHours']()) + ':' + f(this['getUTCMinutes']()) + ':' + f(this['getUTCSeconds']()) + 'Z' : null
        };
        String['prototype']['toJSON'] = Number['prototype']['toJSON'] = Boolean['prototype']['toJSON'] = function (key) {
            return this.valueOf()
        }
    };
    var cx = /[\u0000\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,
        escapable = /[\\\"\x00-\x1f\x7f-\x9f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,
        gap, indent, meta = {
            "\x08": '\b',
            "\x09": '\t',
            "\x0A": '\n',
            "\x0C": '\f',
            "\x0D": '\r',
            "\x22": '\"',
            "\x5C": '\\'
        },
        rep;

    function quote(string) {
        escapable['lastIndex'] = 0;
        return escapable['test'](string) ? '"' + string['replace'](escapable, function (a) {
            var c = meta[a];
            //      return typeof c === 'string' ? c : '\u' + ('0000' + a['charCodeAt'](0).toString(16))['slice'](-4)
        }) + '"' : '"' + string + '"'
    }

    function str(key, holder) {
        var i, k, v, length, mind = gap,
            partial, value = holder[key];
        if (value && typeof value === 'object' && typeof value['toJSON'] === 'function') {
            value = value['toJSON'](key)
        };
        if (typeof rep === 'function') {
            value = rep['call'](holder, key, value)
        };
        switch (typeof value) {
            case 'string':
                return quote(value);
            case 'number':
                return isFinite(value) ? String(value) : 'null';
            case 'boolean':
                ;
            case 'null':
                return String(value);
            case 'object':
                if (!value) {
                    return 'null'
                };
                gap += indent;
                partial = [];
                if (Object['prototype']['toString']['apply'](value) === '[object Array]') {
                    length = value['length'];
                    for (i = 0; i < length; i += 1) {
                        partial[i] = str(i, value) || 'null'
                    };
                    v = partial['length'] === 0 ? '[]' : gap ? '[\x0A' + gap + partial['join'](',\x0A' + gap) + '\x0A' + mind + ']' : '[' + partial['join'](',') + ']';
                    gap = mind;
                    return v
                };
                if (rep && typeof rep === 'object') {
                    length = rep['length'];
                    for (i = 0; i < length; i += 1) {
                        if (typeof rep[i] === 'string') {
                            k = rep[i];
                            v = str(k, value);
                            if (v) {
                                partial['push'](quote(k) + (gap ? ': ' : ':') + v)
                            }
                        }
                    }
                } else {
                    for (k in value) {
                        if (Object['prototype']['hasOwnProperty']['call'](value, k)) {
                            v = str(k, value);
                            if (v) {
                                partial['push'](quote(k) + (gap ? ': ' : ':') + v)
                            }
                        }
                    }
                };
                v = partial['length'] === 0 ? '{}' : gap ? '{\x0A' + gap + partial['join'](',\x0A' + gap) + '\x0A' + mind + '}' : '{' + partial['join'](',') + '}';
                gap = mind;
                return v
        }
    }
    if (typeof JSON['stringify'] !== 'function') {
        JSON['stringify'] = function (value, replacer, space) {
            var i;
            gap = '';
            indent = '';
            if (typeof space === 'number') {
                for (i = 0; i < space; i += 1) {
                    indent += ' '
                }
            } else {
                if (typeof space === 'string') {
                    indent = space
                }
            };
            rep = replacer;
            if (replacer && typeof replacer !== 'function' && (typeof replacer !== 'object' || typeof replacer['length'] !== 'number')) {
                throw new Error('JSON.stringify')
            };
            return str('', {
                "": value
            })
        }
    };
    if (typeof JSON['parse'] !== 'function') {
        JSON['parse'] = function (text, reviver) {
            var j;

            function walk(holder, key) {
                var k, v, value = holder[key];
                if (value && typeof value === 'object') {
                    for (k in value) {
                        if (Object['prototype']['hasOwnProperty']['call'](value, k)) {
                            v = walk(value, k);
                            if (v !== undefined) {
                                value[k] = v
                            } else {
                                delete value[k]
                            }
                        }
                    }
                };
                return reviver['call'](holder, key, value)
            }
            text = String(text);
            cx['lastIndex'] = 0;
            if (cx['test'](text)) {
                text = text['replace'](cx, function (a) {
                    //                return '\u' + ('0000' + a['charCodeAt'](0).toString(16))['slice'](-4)
                })
            };
            if (/^[\],:{}\s]*$/['test'](text['replace'](/\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g, '@')['replace'](/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g, ']')['replace'](/(?:^|:|,)(?:\s*\[)+/g, ''))) {
                j = eval('(' + text + ')');
                return typeof reviver === 'function' ? walk({
                    "": j
                }, '') : j
            };
            throw new SyntaxError('JSON.parse')
        }
    }
}())


/////

// IWS LOG

var DATABASE_NAME = 'IWSC_Logs';
var DATABASE_VERSION = 1;
var OBJECT_STORE_NAME = 'logs';
var LOG_RETENTION_HOURS = 12;
var CLEANUP_INTERVAL_MINUTES = 15;

function initDatabase(callback) {
    var request = indexedDB.open(DATABASE_NAME, DATABASE_VERSION);

    request.onupgradeneeded = function (event) {
        var db = event.target.result;
        if (!db.objectStoreNames.contains(OBJECT_STORE_NAME)) {
            var store = db.createObjectStore(OBJECT_STORE_NAME, { keyPath: 'id', autoIncrement: true });
            store.createIndex('timestamp', 'timestamp', { unique: false });
        }
    };

    request.onsuccess = function (event) {
        if (typeof callback === 'function') {
            callback(null, event.target.result);
        }
    };

    request.onerror = function (event) {
        if (typeof callback === 'function') {
            callback(request.error, null);
        }
    };
}


function saveLogIntoIndexedDB(message, logTime, callback) {
    if (!(typeof logTime === 'object' && logTime instanceof Date)) {
        logTime = new Date();
    }

    if (message.includes("KeepAlive")) {
        if (typeof callback === 'function') {
            callback(err, null);
        }
        return;
    }

    initDatabase(function (err, db) {
        if (err) {
            if (typeof callback === 'function') {
                callback(err, null);
            }
            return;
        }

        var log = {
            timestamp: logTime.toISOString(),
            message: "IWSC " + VERSION + " " + message,
        };

        var transaction = db.transaction(OBJECT_STORE_NAME, 'readwrite');
        var store = transaction.objectStore(OBJECT_STORE_NAME);
        var request = store.add(log);

        request.onsuccess = function () {
            if (typeof callback === 'function') {
                callback(null, true);
            }
        };

        request.onerror = function () {
            if (typeof callback === 'function') {
                callback(request.error, null);
            }
        };
    });
}

function deleteLogsOlder(callback) {
    initDatabase(function (err, db) {
        if (err) {
            return callback(err);
        }

        var cutoffTime = new Date();
        cutoffTime.setHours(cutoffTime.getHours() - LOG_RETENTION_HOURS);

        var transaction = db.transaction(OBJECT_STORE_NAME, 'readwrite');
        var store = transaction.objectStore(OBJECT_STORE_NAME);
        var index = store.index('timestamp');
        var range = IDBKeyRange.upperBound(cutoffTime.toISOString());

        var request = index.openCursor(range);

        request.onsuccess = function (event) {
            var cursor = event.target.result;
            if (cursor) {
                store.delete(cursor.primaryKey);
                cursor.continue();
            } else {
                console.table("[Cleanup] Logs older than " + LOG_RETENTION_HOURS + "hours have been deleted.");
                if (typeof callback === 'function') {
                    callback(null, true);
                }
            }
        };

        request.onerror = function () {
            if (typeof callback === 'function') {
                callback(request.error, null);
            }
        };
    });
}


function startLogCleanupInterval() {
    function cleanupLogs() {
        console.table('[Cleanup] Starting log cleanup...');
        deleteLogsOlder(function (err) {
            if (err) {
                console.table('[Cleanup] Error during log cleanup:' + JSON.stringify(err));
            }
        });
    }
    setInterval(cleanupLogs, CLEANUP_INTERVAL_MINUTES * 60 * 1000);
    cleanupLogs();
}

startLogCleanupInterval();


function downloadLogIWSCFromIndexedDB() {
    initDatabase(function (err, db) {
        if (err) {
            console.table("[Download] Failed to initialize database:" + JSON.stringify(err));
            return;
        }

        var transaction = db.transaction(OBJECT_STORE_NAME, 'readonly');
        var store = transaction.objectStore(OBJECT_STORE_NAME);
        var request = store.getAll();

        request.onsuccess = function () {
            var logs = request.result;
            if (!logs || logs.length === 0) {
                console.warn("[Download] No logs available to download.");
                return;
            }

            var logContent = logs
                .map(function (log) { return log.timestamp + ":" + log.message })
                .join('\n');

            var filenameLog = "iwsc_" + new Date().toLocaleString() + ".log";
            var downloadLogIWSCElement = document.createElement('a');
            downloadLogIWSCElement.setAttribute(
                'href',
                'data:text/plain;charset=utf-8,' + encodeURIComponent(logContent)
            );
            downloadLogIWSCElement.setAttribute('download', filenameLog);

            downloadLogIWSCElement.style.display = 'none';
            document.body.appendChild(downloadLogIWSCElement);

            downloadLogIWSCElement.click();

            document.body.removeChild(downloadLogIWSCElement);

            console.table("[Download] Logs have been downloaded as " + filenameLog);
        };

        request.onerror = function () {
            console.table("[Download] Error while fetching logs from database:" + JSON.stringify(request.error));
        };
    });
}
//static-content-hash-trigger-YUI