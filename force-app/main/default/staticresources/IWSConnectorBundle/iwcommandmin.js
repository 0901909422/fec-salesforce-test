///========================================
/// SoftPhone s.r.l
/// IWSConnector release 1.7.1.0
/// Date: 19/01/2017
///========================================


function Ready() {
    log['debug']('try to call ready');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'READY',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid
    };
    executeStandardCommand(JSON['stringify'](command))
}

function NotReady(actioncode) {
    log['debug']('try to call notready');
    if (actioncode == 'undefined') {
        actioncode = ''
    };
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'NOTREADY',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x61\x63\x74\x69\x6F\x6E\x63\x6F\x64\x65": actioncode
    };
    executeStandardCommand(JSON['stringify'](command))
}

function ReadyAll() {
    log['debug']('try to call ready');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'READYALL',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid
    };
    executeStandardCommand(JSON['stringify'](command))
}

function NotReadyAll(actioncode) {
    log['debug']('try to call notready');
    if (actioncode == 'undefined') {
        actioncode = ''
    };
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'NOTREADYALL',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x61\x63\x74\x69\x6F\x6E\x63\x6F\x64\x65": actioncode
    };
    executeStandardCommand(JSON['stringify'](command))
}

function MediaReady(medianame) {
    log['debug']('try to call media ready');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'MEDIAREADY',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x6D\x65\x64\x69\x61\x6E\x61\x6D\x65": medianame
    };
    executeStandardCommand(JSON['stringify'](command))
}

function MediaNotReady(medianame, actioncode) {
    log['debug']('try to call media notready');
    if (actioncode == 'undefined') {
        actioncode = ''
    };
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'MEDIANOTREADY',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x6D\x65\x64\x69\x61\x6E\x61\x6D\x65": medianame,
        "\x61\x63\x74\x69\x6F\x6E\x63\x6F\x64\x65": actioncode
    };
    executeStandardCommand(JSON['stringify'](command))
}

function ACWAll() {
    log['debug']('try to call acw');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'ACWALL',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid
    };
    executeStandardCommand(JSON['stringify'](command))
}

function MediaACW(medianame) {
    log['debug']('try to call media acw');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'MEDIAACW',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x6D\x65\x64\x69\x61\x6E\x61\x6D\x65": medianame
    };
    executeStandardCommand(JSON['stringify'](command))
}

function Logout() {
    log['debug']('try to call logout');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'LOGOUT',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid
    };
    executeStandardCommand(JSON['stringify'](command))
}

function Login() {
    log['debug']('try to call login');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'LOGIN',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid
    };
    executeStandardCommand(JSON['stringify'](command))
}

function CloseIWS() {
    log['debug']('try to call CloseIWS');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'CLOSEIWS',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid
    };
    executeStandardCommand(JSON['stringify'](command))
}



function MakeCall(number, params) {
    log['debug']('try to make a call:' + number);
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'MAKEACALL',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x6E\x75\x6D\x62\x65\x72": number,
        "\x61\x74\x74\x61\x63\x68\x64\x61\x74\x61": (params ? params['toJsonObject']() : {})
    };
    executeStandardCommand(JSON['stringify'](command))
}

function MakeCallEx(number, params) {
    log['debug']('try to make a call:' + number);
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'MAKEACALL',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x6E\x75\x6D\x62\x65\x72": number,
        "\x61\x74\x74\x61\x63\x68\x64\x61\x74\x61": params
    };
    executeStandardCommand(JSON['stringify'](command))
}

function MakeCallCampaign(number, recordhandle) {
    log['debug']('try to make a call on Campaign: ' + number);
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'MAKEACALLCAMPAIGN',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x6E\x75\x6D\x62\x65\x72": number,
        "\x72\x65\x63\x6F\x72\x64\x68\x61\x6E\x64\x6C\x65": recordhandle
    };
    executeStandardCommand(JSON['stringify'](command))
}

function setattachdata(params) {
    log['debug']('try to call attachdata:' + params);
    var command = '{\'command\':\'SETATTACHDATA\',\'sessionid\':\'' + sessionid + '\', \'attachdata\' : {' + params + '} }';
    executeStandardCommand(command)
}

function SetAttachdataById(interactionid, params) {
    log['debug']('try to call attachdata...');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'SETATTACHDATA',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionid,
        "\x61\x74\x74\x61\x63\x68\x64\x61\x74\x61": (params ? params['toJsonObject']() : {})
    };
    executeStandardCommand(JSON['stringify'](command))
}

function SetAttachdataPlaceHolder(interactionid) {
    log['debug']('try to call SetAttachdataPlaceHolder...');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'SETATTACHDATA',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionid,
        "\x61\x74\x74\x61\x63\x68\x64\x61\x74\x61": {
            IWSC_PLACEHOLDER: 'ACTIVATED'
        }
    };
    executeStandardCommand(JSON['stringify'](command))
}

function SetAttachdataOnSelectedInteraction(params) {
    log['debug']('try to call attachdata:' + params);
    try {
        var message = getSelectedInteraction();
        if (message) {
            SetAttachdataById(message.ConnectionID, params)
        } else {
            log['warn']('SetAttachData InteractionId not found!')
        }
    } catch (e) {
        log['warnFormat']('Error in SetAttachdataOnSelectedInteraction: [{0}]', e['message'])
    }
}


function SetDispositionCode(interactionid, dispositioncode) {
    log['debug']('try to call SetDispositionCode');
  
  	 var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'SetDispositionCode',
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionid,
        "\x64\x69\x73\x70\x6F\x73\x69\x74\x69\x6F\x6E\x63\x6F\x64\x65": dispositioncode
    };
    executeStandardCommand(JSON['stringify'](command))
}

function GetRecord(campaignname) {
    log['debug']('try to call GetRecord');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'GetRecord',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x63\x61\x6D\x70\x61\x69\x67\x6E\x6E\x61\x6D\x65": campaignname
    };
    executeStandardCommand(JSON['stringify'](command))
}

function RecordProcessed(recordhandle, callresult, phonenumber, customfields) {
    log['debug']('try to call RecordProcessed');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'RecordProcessed',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x72\x65\x63\x6F\x72\x64\x68\x61\x6E\x64\x6C\x65": recordhandle,
        "\x70\x68\x6F\x6E\x65\x6E\x75\x6D\x62\x65\x72": phonenumber,
        "\x63\x61\x6C\x6C\x72\x65\x73\x75\x6C\x74": callresult,
        "\x63\x75\x73\x74\x6F\x6D\x66\x69\x65\x6C\x64\x73": (customfields ? customfields['toJsonObject']() : {})
    };
    executeStandardCommand(JSON['stringify'](command))
}

function RecordReschedule(recordhandle, schedulemode, rescheduletime, phonenumber, customfields) {
    log['debug']('try to call RecordReschedule');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'RecordReschedule',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x72\x65\x63\x6F\x72\x64\x68\x61\x6E\x64\x6C\x65": recordhandle,
        "\x70\x68\x6F\x6E\x65\x6E\x75\x6D\x62\x65\x72": phonenumber,
        "\x72\x65\x73\x63\x68\x65\x64\x75\x6C\x65\x74\x69\x6D\x65": rescheduletime,
        "\x73\x63\x68\x65\x64\x75\x6C\x65\x6D\x6F\x64\x65": schedulemode,
        "\x63\x75\x73\x74\x6F\x6D\x66\x69\x65\x6C\x64\x73": (customfields ? customfields['toJsonObject']() : {})
    };
    executeStandardCommand(JSON['stringify'](command))
}

function RecordRejected(recordhandle, customfields) {
    log['debug']('try to call RecordRejected');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'RecordRejected',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x72\x65\x63\x6F\x72\x64\x68\x61\x6E\x64\x6C\x65": recordhandle,
        "\x63\x75\x73\x74\x6F\x6D\x66\x69\x65\x6C\x64\x73": (customfields ? customfields['toJsonObject']() : {})
    };
    executeStandardCommand(JSON['stringify'](command))
}

function RecordCancel(recordhandle, customfields) {
    log['debug']('try to call RecordCancel');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'RecordCancel',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x72\x65\x63\x6F\x72\x64\x68\x61\x6E\x64\x6C\x65": recordhandle,
        "\x63\x75\x73\x74\x6F\x6D\x66\x69\x65\x6C\x64\x73": (customfields ? customfields['toJsonObject']() : {})
    };
    executeStandardCommand(JSON['stringify'](command))
}

function InteractionEmailMoveToWorkbin(interactionid, workbinid, workbinotionname, attachdata) {
    log['debug']('try to call InteractionEmailMoveToWorkbin');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'InteractionEmailMoveToWorkbin',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionid,
        "\x77\x6F\x72\x6B\x62\x69\x6E\x69\x64": workbinid,
        "\x77\x6F\x72\x6B\x62\x69\x6E\x6F\x74\x69\x6F\x6E\x6E\x61\x6D\x65": workbinotionname,
        "\x61\x74\x74\x61\x63\x68\x64\x61\x74\x61": (attachdata ? attachdata['toJsonObject']() : {})
    };
    executeStandardCommand(JSON['stringify'](command))
}

function InteractionEmailActionFromWorkbinPullById(interactionid, workbinid, worningmessagetarget) {
    log['debug']('try to call InteractionEmailActionFromWorkbinPullById');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'InteractionEmailActionFromWorkbinPullById',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionid,
        "\x77\x6F\x72\x6B\x62\x69\x6E\x69\x64": workbinid,
        "\x77\x6F\x72\x6E\x69\x6E\x67\x6D\x65\x73\x73\x61\x67\x65\x74\x61\x72\x67\x65\x74": worningmessagetarget
    };
    executeStandardCommand(JSON['stringify'](command))
}

function InteractionWorkItemMoveToWorkbin(interactionid, workbinid, workbinotionname, attachdata) {
    log['debug']('try to call InteractionWorkItemMoveToWorkbin');
    if (!interactionid) {
        interactionid = getSelectedInteractionId()
    };
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'InteractionWorkItemMoveToWorkbin',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionid,
        "\x77\x6F\x72\x6B\x62\x69\x6E\x69\x64": workbinid,
        "\x77\x6F\x72\x6B\x62\x69\x6E\x6F\x74\x69\x6F\x6E\x6E\x61\x6D\x65": workbinotionname,
        "\x61\x74\x74\x61\x63\x68\x64\x61\x74\x61": (attachdata ? attachdata['toJsonObject']() : {})
    };
    executeStandardCommand(JSON['stringify'](command))
}

function InteractionWorkItemActionFromWorkbinPullById(interactionid, workbinid, worningmessagetarget) {
    log['debug']('try to call InteractionWorkItemActionFromWorkbinPullById');
    if (!interactionid) {
        interactionid = getSelectedInteractionId()
    };
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'InteractionWorkItemActionFromWorkbinPullById',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionid,
        "\x77\x6F\x72\x6B\x62\x69\x6E\x69\x64": workbinid,
        "\x77\x6F\x72\x6E\x69\x6E\x67\x6D\x65\x73\x73\x61\x67\x65\x74\x61\x72\x67\x65\x74": getValueIfDefined(worningmessagetarget)
    };
    executeStandardCommand(JSON['stringify'](command))
}

function InteractionOpenMediaPullFromWorkbinById(interactionid, workbinid, worningmessagetarget) {
    log['debug']('try to call InteractionOpenMediaPullFromWorkbinById');
    if (!interactionid) {
        interactionid = getSelectedInteractionId()
    };
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'InteractionOpenMediaPullFromWorkbinById',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionid,
        "\x77\x6F\x72\x6B\x62\x69\x6E\x69\x64": workbinid,
        "\x77\x6F\x72\x6E\x69\x6E\x67\x6D\x65\x73\x73\x61\x67\x65\x74\x61\x72\x67\x65\x74": getValueIfDefined(worningmessagetarget)
    };
    executeStandardCommand(JSON['stringify'](command))
}

function InteractionOpenMediaPlaceInQueue(interactionId, destination, userdata) {
    if (!interactionId) {
        interactionId = getSelectedInteractionId()
    };
    log['debug']('InteractionOpenMediaPlaceInQueue interactionid: ' + interactionId);
    InteractionOpenMediaPlaceInQueueEx(interactionId, destination, userdata, null, null, null, null, 'InteractionQueue', destination)
}

function InteractionOpenMediaPlaceInQueueEx(interactionId, destination, userdata, reason, extension, transferringAgentName, transferringReason, transferringTargetType, transferringTarget) {
    log['debug']('try to call InteractionOpenMediaPullFromWorkbinById');
    if (userdata) {
        userdata = userdata['toJsonObject']()
    } else {
        userdata = {}
    };
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'InteractionOpenMediaPlaceInQueue',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionId,
        "\x44\x65\x73\x74\x69\x6E\x61\x74\x69\x6F\x6E": destination,
        "\x55\x73\x65\x72\x44\x61\x74\x61": userdata,
        "\x52\x65\x61\x73\x6F\x6E": getValueIfDefined(reason),
        "\x45\x78\x74\x65\x6E\x73\x69\x6F\x6E\x73": getValueIfDefined(extension),
        "\x52\x65\x63\x65\x6E\x74\x49\x6E\x64\x65\x78": null,
        "\x41\x64\x64\x69\x74\x69\x6F\x6E\x61\x6C\x54\x61\x72\x67\x65\x74\x49\x6E\x66\x6F\x72\x6D\x61\x74\x69\x6F\x6E": null,
        "\x44\x69\x73\x70\x6C\x61\x79\x4F\x62\x6A\x65\x63\x74": null,
        "\x54\x72\x61\x6E\x73\x66\x65\x72\x72\x69\x6E\x67\x41\x67\x65\x6E\x74\x4E\x61\x6D\x65": getValueIfDefined(transferringAgentName),
        "\x54\x72\x61\x6E\x73\x66\x65\x72\x72\x69\x6E\x67\x52\x65\x61\x73\x6F\x6E": getValueIfDefined(transferringReason),
        "\x54\x72\x61\x6E\x73\x66\x65\x72\x72\x69\x6E\x67\x54\x61\x72\x67\x65\x74\x54\x79\x70\x65": getValueIfDefined(transferringTargetType),
        "\x54\x72\x61\x6E\x73\x66\x65\x72\x72\x69\x6E\x67\x54\x61\x72\x67\x65\x74": getValueIfDefined(transferringTarget)
    };
    executeStandardCommand(JSON['stringify'](command))
}

function InteractionMarkDone(interactionId) {
    log['debugFormat']('try to call InteractionMarkDone [{0}]', interactionId);
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'InteractionMarkDone',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionId
    };
    executeStandardCommand(JSON['stringify'](command))
}

function InteractionRelease(interactionId) {
    log['debugFormat']('try to call InteractionRelease [{0}]', interactionId);
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'InteractionRelease',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionId
    };
    executeStandardCommand(JSON['stringify'](command))
}

function InteractionVoiceSingleStepTransfer(interactionId, destination, attachdata) {
    log['debug']('try to call InteractionVoiceSingleStepTransfer');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'InteractionVoiceSingleStepTransfer',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionId,
        "\x64\x65\x73\x74\x69\x6E\x61\x74\x69\x6F\x6E": destination,
        "\x61\x74\x74\x61\x63\x68\x64\x61\x74\x61": (attachdata ? attachdata['toJsonObject']() : {})
    };
    executeStandardCommand(JSON['stringify'](command))
}

function InteractionVoiceSingleStepConference(interactionId, destination, attachdata) {
    log['debug']('try to call InteractionVoiceSingleStepConference');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'InteractionVoiceSingleStepConference',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionId,
        "\x64\x65\x73\x74\x69\x6E\x61\x74\x69\x6F\x6E": destination,
        "\x61\x74\x74\x61\x63\x68\x64\x61\x74\x61": (attachdata ? attachdata['toJsonObject']() : {})
    };
    executeStandardCommand(JSON['stringify'](command))
}

function InteractionVoiceInitConference(interactionId, destination, attachdata) {
    log['debug']('try to call InteractionVoiceInitConference');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'InteractionVoiceInitConference',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionId,
        "\x64\x65\x73\x74\x69\x6E\x61\x74\x69\x6F\x6E": destination,
        "\x61\x74\x74\x61\x63\x68\x64\x61\x74\x61": (attachdata ? attachdata['toJsonObject']() : {})
    };
    executeStandardCommand(JSON['stringify'](command))
}

function InteractionVoiceCompleteConference(interactionId) {
    log['debug']('try to call InteractionVoiceCompleteConference');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'InteractionVoiceCompleteConference',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionId
    };
    executeStandardCommand(JSON['stringify'](command))
}

function CreateNewOutboundEmail(to, cc, bcc, subject, bodymessage, attachdata) {
    log['debug']('try to call MediaEmailCreateNewOutboundEmail');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'MediaEmailCreateNewOutboundEmail',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x74\x6F": to,
        "\x63\x63": cc,
        "\x62\x63\x63": bcc,
        "\x73\x75\x62\x6A\x65\x63\x74": subject,
        "\x62\x6F\x64\x79\x6D\x65\x73\x73\x61\x67\x65": bodymessage,
        "\x61\x74\x74\x61\x63\x68\x64\x61\x74\x61": (attachdata ? attachdata['toJsonObject']() : {})
    };
    executeStandardCommand(JSON['stringify'](command))
}

function ReplyEmailById(id) {
    log['debug']('try to call InteractionEmailReplyById');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'InteractionEmailReplyById',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": id
    };
    executeStandardCommand(JSON['stringify'](command))
}

function SendSilentEmail(to, cc, bcc, subject, bodymessage, attachdata, attachments) {
    log['debug']('try to call SendSilentEmail');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'SendSilentEmail',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x74\x6F": to,
        "\x63\x63": cc,
        "\x62\x63\x63": bcc,
        "\x73\x75\x62\x6A\x65\x63\x74": subject,
        "\x62\x6F\x64\x79\x6D\x65\x73\x73\x61\x67\x65": bodymessage,
        "\x61\x74\x74\x61\x63\x68\x64\x61\x74\x61": (attachdata ? attachdata['toJsonObject']() : {}),
        "\x61\x74\x74\x61\x63\x68\x6D\x65\x6E\x74\x73": (attachments ? attachments : [])
    };
    executeStandardCommand(JSON['stringify'](command))
}

function AddEmailAttachments(id, attachments) {
    log['debug']('try to call AddEmailAttachments');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'AddEmailAttachments',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": id,
        "\x61\x74\x74\x61\x63\x68\x6D\x65\x6E\x74\x73": (attachments ? attachments : [])
    };
    executeStandardCommand(JSON['stringify'](command))
}

function SendEmailById(id) {
    log['debug']('try to call SendEmailById');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'SendEmailById',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": id
    };
    executeStandardCommand(JSON['stringify'](command))
}

function AddEmailBody(id, bodymessage) {
    log['debug']('try to call AddEmailBody');
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'AddEmailBody',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": id,
        "\x62\x6F\x64\x79\x6D\x65\x73\x73\x61\x67\x65": bodymessage
    };
    executeStandardCommand(JSON['stringify'](command))
}

function PublishInformation(message) {
    PublishEvent('PublishInformation', message)
}

function PublishWarning(message) {
    PublishEvent('PublishWarning', message)
}

function PublishError(message) {
    PublishEvent('PublishError', message)
}

function PublishMessage(message) {
    PublishEvent('PublishMessage', message)
}

function PublishEvent(eventname, message) {
    log['debug']('try to call ' + eventname);
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": eventname,
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x6D\x65\x73\x73\x61\x67\x65": message
    };
    executeStandardCommand(JSON['stringify'](command))
}

function ExecuteDelegatedCommand(delegated_id) {
    log['debug']('try to call ExecuteDelegatedCommand ' + delegated_id);
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'ExecuteDelegatedCommand',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x64": delegated_id
    };
    executeStandardCommand(JSON['stringify'](command))
}

function RemoveDelegatedCommand(delegated_id) {
    log['debug']('try to call RemoveDelegatedCommand ' + delegated_id);
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'RemoveDelegatedCommand',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x69\x64": delegated_id
    };
    executeStandardCommand(JSON['stringify'](command))
}

function getJsonValue(objvalue) {
    return (!objvalue ? 'null' : '\'' + objvalue + '\'')
}

function getValueIfDefined(objvalue) {
    return (!objvalue ? null : objvalue)
}

function sessionexit() {
    bexit = true;
    log['info']('try to exit:' + sessionid);
  
    var sizeInter = myInteractions.size();

    if(sizeInter > 0)
    {
          log['info']('Closing Open Interactions:' + sizeInter);
      	var dispositioncode = "N/A";
    	var Reason = "N/A";
    	var SubReason = "N/A";
  
    	SetDispositionCodeWrapper(dispositioncode, Reason, SubReason);
    }
  
    var command = '{\'command\':\'EXIT\',\'sessionid\':\'' + sessionid + '\', \'type\':\'' + clientType + '\'}';
    callJsonpSync('message=' + command);
    sessionid = ''
}

function sessionexitPotentialRefresh() {
    log['debug']('try sessionexitPotentialRefresh:' + sessionid);
    var command = '{\'command\':\'REFRESH\',\'sessionid\':\'' + sessionid + '\', \'type\':\'' + clientType + '\'}';
    callJsonpSync('message=' + command)
}

function executeCustomCommand(message) {
    log['debug']('try to call executeCustomCommand:' + message);
    executeCommand('EXECUTECUSTOMCOMMAND', 'message=' + encodeURIComponent(message))
}

function executeStandardCommand(myparams) {
    log['debug']('try to call executeStandardCommand:' + myparams);
    executeCommand('EXECUTECOMMAND', 'message=' + encodeURIComponent(myparams))
}

function executeCommand(mycommand, myparams) {
    if (!myurl) {
        log['error']('Server url not initialized');
        return
    };
    var myjsonp = getWdeJsonp();
    myjsonp({
        url: myurl + mycommand,
        data: myparams,
        dataType: 'jsonp',
        callbackParameter: 'jsonp_callback',
        timeout: 10000,
        success: function(data, status) {
            log['debug']('success ' + data)
        },
        error: function(XHR, textStatus, errorThrown) {
            log['error']('status: ' + textStatus + '\x0Aerror: ' + errorThrown)
        }
    })
}
var exitOnDocumentUnload = true;

function removeExitOnDocumentUnload() {
    log['info']('==== Removed the Session Exit on DocumentUnload ====');
    exitOnDocumentUnload = false
}
jQuery(window)['bind']('beforeunload', function() {
    if (exitOnDocumentUnload) {
        log['info']('Exit - DocumentUnload enabled');
        sessionexit()
    } else {
        if (isEnablePlaceHolder()) {
            log['info']('Potential Refresh - DocumentUnload disabled!');
            sessionexitPotentialRefresh()
        }
    }
});

function callJsonpSync(myparams) {
    jQuery['ajax']({
        url: myurl + 'EXECUTECOMMAND',
        data: myparams,
        async: false,
        crossDomain: false
    })['done'](function() {})
}

function SetInteractionOnWde(interactionid) {
    log['debugFormat']('try to call SetInteractionOnWde on interactionid[{0}]...', interactionid);
    if (interactionid) {
        var command = {
            "\x63\x6F\x6D\x6D\x61\x6E\x64": 'SWITCHINTERACTION',
            "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
            "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionid
        };
        executeStandardCommand(JSON['stringify'](command))
    } else {
        log['warn']('try to call SetInteractionOnWde on undefined interactionid')
    }
}

function ActiveMe(url, cmdshow, topmost, browser) {
    var mycmdshow = 3;
    var mytopmost = true;
    var myurl = document['location']['href'];
    var mybrowser = 'ie';
    if (url) {
        myurl = url
    };
    if (topmost) {
        mytopmost = topmost
    };
    if (cmdshow) {
        mycmdshow = cmdshow
    };
    if (browser) {
        mybrowser = browser
    };
    var message = {
        "\x65\x78\x74\x65\x6E\x73\x69\x6F\x6E\x63\x6F\x6D\x6D\x61\x6E\x64": 'activeme',
        "\x62\x72\x6F\x77\x73\x65\x72": mybrowser,
        "\x75\x72\x6C": myurl,
        "\x63\x6D\x64\x73\x68\x6F\x77": mycmdshow,
        "\x74\x6F\x70\x6D\x6F\x73\x74": mytopmost
    };
    executeCustomCommand(JSON['stringify'](message))
}

function InteractionSwitch(interactionid) {
    log['debugFormat']('try to call InteractionSwitch on interactionid[{0}]...', interactionid);
    if (interactionid) {
        var command = {
            "\x63\x6F\x6D\x6D\x61\x6E\x64": 'INTERACTIONSWITCH',
            "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
            "\x69\x6E\x74\x65\x72\x61\x63\x74\x69\x6F\x6E\x69\x64": interactionid
        };
        executeStandardCommand(JSON['stringify'](command))
    } else {
        log['warn']('try to call InteractionSwitch on undefined interactionid')
    }
}

function GetWDEAgentState(callbackfunction) {
    log['debug']('try to call GetAgentState');
    var command = {
        "\x6D\x65\x74\x68\x6F\x64": 'agentstate'
    };
    executeStandardMethod(JSON['stringify'](command), callbackfunction)
}

function GetWDEAllInteractions(callbackfunction) {
    log['debug']('try to call GetAllInteractions');
    var command = {
        "\x6D\x65\x74\x68\x6F\x64": 'allinteractions'
    };
    executeStandardMethod(JSON['stringify'](command), callbackfunction)
}

function GetWDESelectedInteraction(callbackfunction) {
    log['debug']('try to call GetCurrentInteraction');
    var command = {
        "\x6D\x65\x74\x68\x6F\x64": 'selectedinteraction'
    };
    executeStandardMethod(JSON['stringify'](command), callbackfunction)
}

function GetWDEInteractionById(connectionid, callbackfunction) {
    log['debug']('try to call GetInteractionById');
    var command = {
        "\x6D\x65\x74\x68\x6F\x64": 'interaction',
        "\x63\x6F\x6E\x6E\x65\x63\x74\x69\x6F\x6E\x69\x64": connectionid
    };
    executeStandardMethod(JSON['stringify'](command), callbackfunction)
}

function executeStandardMethod(myparams, callbackfunction) {
    log['debug']('try to call executeStandardMethod:' + myparams);
    getMethod('GETMETHOD', 'message=' + encodeURIComponent(myparams), callbackfunction)
}

function getMethod(mymethod, myparams, callbackfunction) {
    if (!myurl) {
        log['error']('Server url not initialized');
        return
    };
    var myjsonp = getWdeJsonp();
    myjsonp({
        url: myurl + mymethod,
        data: myparams,
        dataType: 'jsonp',
        callbackParameter: 'jsonp_callback',
        timeout: 10000,
        success: function(data, status) {
            log['debug']('success ' + data);
            callbackfunction(data)
        },
        error: function(XHR, textStatus, errorThrown) {
            log['error']('status: ' + textStatus + '\x0Aerror: ' + errorThrown)
        }
    })
}