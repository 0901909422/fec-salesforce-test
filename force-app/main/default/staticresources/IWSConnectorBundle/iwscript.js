///========================================
/// SoftPhone s.r.l
/// IWSConnector release 1.7.1.0
/// Date: 19/01/2017
///========================================
function networkError(message) {
    log.error(message);
}

function onIdentity(message) {}

function onConnectedSession(message) {}

function onDisconnectedSession(message) {}

function onActivateSession(message) {
    if (existOptionInteractions())
        switchInteraction();
}

function onPostActivateSession(message) {}

function onDeactivateSession(message) {}

function onChannelStatus(message) {

}

function onEventAgentNotReady(message) {
    //to get the ActionCode
    //message.attachdata.ActionCode
}

function onEventAgentNotReadyAfterCallWork(message) {}

function onEventAgentReady(message) {}

function onEventAgentLogout(message) {}

function onEventAgentLogin(message) {}

//==================================================================
// Events MediaVoice
/*
 * message.EVENT
 * message.Place
 * message.AgentID
 * message.MediaType
 * message.ConnectionID
 * message.ANI
 * message.DNIS
 * message.CallType
 * message.Duration
 * message.TimeStamp
 * message.attachdata
 * message.EntrepriseLastInteractionEvent.PreviousConnID
 */
//==================================================================

function printAllAttachData(message) {
    log.debug("called printAttachData on Event:" + message.EVENT);
    for (var key in message.attachdata) {
        log.debugFormat("attach key[{0}] value[{1}] ", key, message.attachdata[key]);
    }
}

function onEventRingingInbound(message) {
    printAllAttachData(message);
  
	createNewWorkFromIVR(message);
}


function onEventRingingInternal(message) {
    printAllAttachData(message);
    /*
    //SetAttachData Example
    var mycollection = createUserData();
    mycollection.put("paramtest", "value1");
    SetAttachdataById(message.ConnectionID, mycollection);
    */
}

function onEventRingingConsult(message) {
    /*
     	This event is received only by the second Agent (in the consult transfer scenario)
    	usually open the popup without create the activity
    */
}

function onEventRingingOutbound(message) {
	//createNewWorkFromIVR(message);
}

//EventEstablished
function onEventEstablishedInbound(message) {
    /*
    	open the ticket only if is not a transfer...
    	just check an attach-data
    */
  //createNewWorkFromIVR(message);
}

function onEventEstablishedInternal(message) {}

function onEventEstablishedConsult(message) {
    //open the ticket without create the activity
}

function onEventEstablishedOutbound(message) {
  console.log("onEventEstablishedOutbound called");
  /*CSM-7836: Click To Call */
  if(message.attachdata.ClickToCall != null && message.attachdata.ClickToCall == "true")
  {  
    SetCTCGenesysId(message);
  }
  printAllAttachData(message);
	createNewWorkFromIVR(message);
}

function onEventNetworkReachedOutbound(message) {
  //printAllAttachData(message);
  
	//createNewWorkFromIVR(message);
}
//EventHeld
function onEventHeldInbound(message) {}

function onEventHeldInternal(message) {}

function onEventHeldConsult(message) {}

function onEventHeldOutbound(message) {}
//EventRetrieved	
function onEventRetrievedInbound(message) {}

function onEventRetrievedInternal(message) {}

function onEventRetrievedConsult(message) {}

function onEventRetrievedOutbound(message) {}
//EventAttachedDataChanged
function onEventAttachedDataChangedInbound(message) {}

function onEventAttachedDataChangedInternal(message) {}

function onEventAttachedDataChangedConsult(message) {}

function onEventAttachedDataChangedOutbound(message) {}
//EventReleased
function onEventReleasedInbound(message) {}

function onEventReleasedInternal(message) {}

function onEventReleasedConsult(message) {}

function onEventReleasedOutbound(message) {
  /*CSM-7836: Click To Call */
  if(message.attachdata.ClickToCall != null && message.attachdata.ClickToCall == "true")
  {
    printAllAttachData(message);
    
    ResetCTCGenesysId(message);
  }
}
//EventDialing
function onEventDialingInternal(message) {}

function onEventDialingConsult(message) {}

function onEventDialingOutbound(message) {
  printAllAttachData(message);
  if(message.attachdata.ClickToCall != null && message.attachdata.ClickToCall == "true") {
    SetConnectSuccessClickToCall(message);
  }
}

//==================================================================
//Events MediaEmail
//==================================================================
function onEmailEventRingingInbound(message) {
  
  //printAllAttachData(message);
  
	//createNewWorkFromIVREmail(message);
}

function onEmailEventEstablishedInbound(message) {
  
  printAllAttachData(message);
  
	createNewWorkFromIVREmail(message);
}

function onEmailEventReleasedInbound(message) {}

function onEmailEventReplyEstablishedOutbound(message) {}

function onEmailEventReplyReleased(message) {}

function onEmailEventReplyCancelled(message) {}

function onEmailEventSessionInfo(message) {}

//==================================================================
//Events MediaWorkbin
//==================================================================

function onWorkbinTakenOut(message) {

}

function onWorkbinPlacedIn(message) {

}

function onWorkbinContent(message) {

}

//==================================================================
//Events MediaChat
//==================================================================
function onChatEventRingingInbound(message) {}

function onChatEventRingingConsult(message) {}

function onChatEventEstablishedInbound(message) {}

function onChatEventEstablishedConsult(message) {}

function onChatEventReleasedInbound(message) {}

function onChatEventReleasedConsult(message) {}

function onChatEventTranscriptLink(message) {
    //message.TranscriptPath
}

function onChatEventPartyRemovedInbound(message) {}

function onChatEventPartyAddedInbound(message) {}

function onChatEventPartyChangedInbound(message) {}

//==================================================================
//Events SMS
//==================================================================
function onSMSEventRingingInbound(message) {}

function onSMSEventEstablishedInbound(message) {}

function onSMSEventReleasedInbound(message) {}

function onSMSEventSendMessage(message) {
    //message.SmsMessage
}

//==================================================================
//Events WorkItem
//==================================================================
function onWorkitemEventRingingInbound(message) {}

function onWorkitemEventEstablishedInbound(message) {}

function onWorkitemEventReleasedInbound(message) {}

//==================================================================
//Events Facebook
//==================================================================
function onFacebookEventRingingInbound(message) {}

function onFacebookEventEstablishedInbound(message) {}

function onFacebookEventReleasedInbound(message) {}

function onFacebookEventSessionInfo(message) {}

//==================================================================
//Events Twitter
//==================================================================
function onTwitterEventRingingInbound(message) {}

function onTwitterEventEstablishedInbound(message) {}

function onTwitterEventSessionInfo(message) {}

function onTwitterEventReleasedInbound(message) {}

function onTwitterEventReplyOutbound(message) {
    alert("onTwitterEventReplyOutbound");
}

function onTwitterEventRetweetOutbound(message) {}

function onTwitterEventDirectMessageOutbound(message) {}

//==================================================================
//Events UserEvent
//==================================================================
function onEventUserEvent(message) {}

function onPreviewRecord(message) {
    log.debug("======= onPreviewRecord ==========");
    //selectInteractionOptionByMessage(message);
    //MakeCallEx(message.attachdata.GSW_PHONE, message.attachdata);	
}

function onChainedRecord(message) {}

function onRecordRejectAcknowledge(message) {}

function onRecordProcessedAcknowledge(message) {}

//==================================================================
//Events DelegateCommand
//==================================================================
function onDelegateCommand(message) {
    log.debug("======= onDelegateCommand ==========");
    if (message.Parameters.Device) {
        log.debugFormat("Device Name: {0}", message.Parameters.Device.Name);
    }
    /*
    //to authorize the command on IWS
    log.debugFormat("===== Execute message: {0}", message.ID);
    ExecuteDelegatedCommand(message.ID);
    // OR
    RemoveDelegatedCommand(message.ID);
    */
}

//==================================================================
//Events InhibitCommand
//==================================================================
function onInhibitCommand(message) {
    log.debug("======= onInhibitCommand ==========");
    if (message.Parameters.Device) {
        log.debugFormat("Device Name: {0}", message.Parameters.Device.Name);
    }
}

//==================================================================
//Generic Events 
//==================================================================
function onSwitchInteraction(message) {
    log.debug("Called onSwitchInteraction: " + message);
}

function onWdeSwitchInteraction(message) {
    log.debug("Called onWdeSwitchInteraction: " + message);
}
//static-content-hash-trigger-YUI