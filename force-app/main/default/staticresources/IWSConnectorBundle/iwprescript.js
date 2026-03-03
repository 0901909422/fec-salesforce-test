///========================================
/// SoftPhone s.r.l
/// IWSConnector release 1.7.1.0
/// Date: 19/01/2017
///========================================
function onPreConnectedSession(message)
{
	if(message.IwsApplicationName)
	{
		setIwsApplicationName(message.IwsApplicationName);
	}
	showConnectedState();
}

function onPreDisconnectedSession(message)
{
	showDisconnectedState();
}

function onPreActivateSession(message)
{
	showActivedState();
	//load combo interactions
	if(message.interactions)
	{
		var i;
		log.debugFormat("[onPreActivateSession] received [{0}] interaction", message.interactions.length);
		//addEmptyOption() removeEmptyOption()
		//if((!isMultyInteractions()) && (isEnablePlaceHolder()))
		//	addEmptyOption();
		
		if(isEnablePlaceHolder())
			addEmptyOption();
		
		for(i = 0; i< message.interactions.length; i++)
		{
			if(
				(message.interactions[i].State == 8)
				||
				(message.interactions[i].State == 1)
				||
				(message.interactions[i].State == 2)
				)
				continue;
			
			log.debug("[onPreActivateSession] Check if the interaction is a Campaign");
			if(isCampaign(message.interactions[i]))
			{
				log.debug("[onPreActivateSession] The interaction is a Campaign");
				if(isEnablePlaceHolder())
					addJSONObjectInMemoryCampaign(message.interactions[i], isEnablePlaceHolderInteraction(message.interactions[i]));
				else
					addJSONObjectInMemoryCampaign(message.interactions[i], false);
			}
			else
			{
				log.debug("[onPreActivateSession] The interaction not is a Campaign");
				//if(isMultyInteractions())
				//	addJSONObjectInMemory(message.interactions[i]);
				//related the attach-data
				if(isEnablePlaceHolder())
					addJSONObjectInMemory(message.interactions[i], isEnablePlaceHolderInteraction(message.interactions[i]));
				else
					addJSONObjectInMemory(message.interactions[i], false);
			}
			//message.interactions[i].State == 5 means released
		}
		
		//if((!isMultyInteractions()) && (isEnablePlaceHolder()))
		if(isEnablePlaceHolder())
			removeEmptyOption();
		if(countInteractions() > 0)
		{
			removeDefaultOption();
		}

	}
}

function onPreDeactivateSession(message)
{
	showConnectedState();
}

function onSynchInteractions(message)
{	
	for(var key in mapInteractions)
	{
		log.debugFormat("[onSynchInteractions] Check [{0}] in IWS", key);
		if(!message.interactions[key])
		{
			log.warnFormat("[onSynchInteractions] Remove [{0}]", key);
			removeJSONObjectInMemory(key);
		}
		else
		{
			log.debugFormat("[onSynchInteractions] Valid [{0}]", key);
		}
	}
}

/**
 * get the id from DelegateCommand
 * @param message
 * @returns {String}
 */
function getIdFromDelegateCommand(message)
{
	var id = "";
	try
	{
		var sapp = message.Parameters.CommandParameter;
		var n = sapp.indexOf("/");
		id = sapp.substring(n+1).slice(0, -1);
	}catch (e) {
		log.warn("getIdFromDelegateCommand: " + e.message);
	}
	log.debugFormat("[getIdFromDelegateCommand] id[{0}]", id);
	return id;
}

function onPreDelegateCommand(message) {
	try
	{
		var id = getMessageId(message);
		if(id)
		{
			log.debugFormat("[onPreDelegateCommand] with ConnectionID [{0}]", id);
		}
		else
		{
			id = getIdFromDelegateCommand(message);
			if(id)
			{
				log.debugFormat("[onPreDelegateCommand] with ConnectionID [{0}]", id);
				message.ConnectionID = id;
				message.InteractionID = id;
			}
		}
	}catch(e)
	{
		log.warn("[onPreDelegateCommand]: " + e.message);
	}
}

function onPreEventAgentReady(message)
{
}

function onPreEventEstablishedInternal(message)
{
	addJSONObjectInMemory(message);
}

function onPreEventEstablishedConsult(message)
{
	addJSONObjectInMemory(message);
}

function onPreEventEstablishedInbound(message)
{
	addJSONObjectInMemory(message);
}

function onPreEventReleasedInbound(message)
{
	//removeJSONObjectInMemory(message.ConnectionID);
}

function onPostEventReleasedConsult(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}

function onPreEventReleasedInternal(message)
{
	//removeJSONObjectInMemory(message.ConnectionID);
}

function onPreEventPartyChangedInbound(message)
{
	//release the consult...
	//PreviousConnID
	//add the new Inbound
	removeJSONObjectInMemory(message.PreviousConnID);
	addJSONObjectInMemory(message);
}
function onPreEventPartyChangedInternal(message)
{
	removeJSONObjectInMemory(message.PreviousConnID);
	addJSONObjectInMemory(message);
}
function onPreEventPartyChangedOutbound(message)
{
	removeJSONObjectInMemory(message.PreviousConnID);
	addJSONObjectInMemory(message);
}
function onPreEventEstablishedOutbound(message)
{
	if(isCampaign(message))
	{
		addJSONObjectInMemoryCampaign(message);
		if(isEnablePlaceHolder() && isSelectedInteraction(message))
		{
			SetInteractionOnWde(message.ConnectionID);
		}
	}
	else		
		addJSONObjectInMemory(message);
}

function onPreEventReleasedOutbound(message)
{
}

function onPreEventMarkDoneInbound(message)
{
	//EventPartyChanged
	log.debugFormat("onPreEventMarkDoneInbound State [{0}] Name[{1}]", message.State, message.Name);
	if(message.Name != "EventReleased")		
		return false;
}

function onPostEventMarkDoneInbound(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}

function onPreEventMarkDoneInternal(message)
{	
}

function onPostEventMarkDoneInternal(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}

function onPreEventMarkDoneConsult(message)
{
}

function onPostEventMarkDoneConsult(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}

function onPreEventMarkDoneOutbound(message)
{
}

function onPostEventMarkDoneOutbound(message)
{
	if(!isCampaign(message))
	{
		removeJSONObjectInMemory(message.ConnectionID);
	}
	else
	{
		var recordhandle = "" + getRecordHandle(message);
		removeJSONObjectInMemory(recordhandle);
	}
		
}

//==============================================
// Chat Section 
//==============================================

function onPreChatEventEstablishedInbound(message)
{
	addJSONObjectInMemory(message);
}

function onPreChatEventReleasedInbound(message)
{
	
}

function onPostChatEventMarkDoneInbound(message)
{
	removeJSONObjectInMemory(message.ConnectionID);	
}
//==============================================
//Workitem Section 
//==============================================

function onPreWorkitemEventEstablishedInbound(message)
{
	addJSONObjectInMemory(message);
}

function onPreWorkitemEventOpenedInbound(message)
{
	addJSONObjectInMemory(message);
}

function onPreWorkitemEventReleasedInbound(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}

//Added in release 1.5.0.0
function onPostWorkitemEventRevokedInbound(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}
//==============================================
//Email Section 
//==============================================

function onPreEmailEventEstablishedInbound(message)
{
	addJSONObjectInMemory(message);
}
		 		
function onPreEmailEventReleasedInbound(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}

function onPreEmailEventOpenedInbound(message)
{
	addJSONObjectInMemory(message);
}

function onPreEmailEventReplyEstablishedOutbound(message)
{
	addJSONObjectInMemory(message);
}

function onPreEmailEventReplyEstablished(message)
{
	addJSONObjectInMemory(message);
}

function onPreEmailEventReplyReleasedOutbound(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}

function onPreEmailEventReplyReleased(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}

function onPreEmailEventReplyCancelled(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}

function onPreEmailEventReplyOpened(message)
{
	addJSONObjectInMemory(message);
}
function onPreEmailEventReplyOpenedOutbound(message)
{
	addJSONObjectInMemory(message);
}

//==============================================
// Workbin Section 
//==============================================

function onPreWorkbinPlacedIn(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}

function onPreWorkbinTakenOut(message)
{
}

//==============================================
//SMS Section 
//==============================================

function onPreSMSEventEstablishedInbound(message)
{
	addJSONObjectInMemory(message);
}

function onPreSMSEventReleasedInbound(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}

function onPreSMSEventEstablishedOutbound(message)
{
	addJSONObjectInMemory(message);
}

function onPreSMSEventReleasedOutbound(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}

//==================================================================
//Events UserEvent
//==================================================================
function onPreEventUserEvent(message)
{
	try
	{
		var eventname = message.attachdata.GSW_USER_EVENT;
		log.debugFormat("onPreEventUserEvent: the event is {0}", eventname);
		callSafetyFunction("onPre"+ eventname + "(message);", message);
		if(checkFunction("on" + eventname))
		{
			callSafetyFunction("on"+ eventname + "(message);", message);
			//return false;
		}
						
	}catch(e)
	{
		log.error("onPreEventUserEvent: " + e.message);
	}
	return true;
}

function onPostEventUserEvent(message)
{
	try
	{
		var eventname = message.attachdata.GSW_USER_EVENT;
		log.debugFormat("onPostEventUserEvent: the event is {0}", eventname);
		callSafetyFunction("onPost"+ eventname + "(message);", message);
	}catch(e)
	{
		log.error("onPostEventUserEvent: " + e.message);
	}
	return true;
}

function onPrePreviewRecord(message)
{
	log.debug("======= onPrePreviewRecord ==========");
	addJSONObjectInMemoryCampaign(message); //false);
}

function onPreRecordProcessedAcknowledge(message)
{
	log.debug("======= onPreRecordProcessedAcknowledge ==========");
	//var recordhandle = "" + getRecordHandle(message);
	//removeJSONObjectInMemory(recordhandle);	
}

function onPostRecordProcessedAcknowledge(message)
{
	log.debug("======= onPostRecordProcessedAcknowledge ==========");
	var recordhandle = "" + getRecordHandle(message);
	removeJSONObjectInMemory(recordhandle);	
}

function onPreRecordRejectAcknowledge(message)
{
	log.debug("======= onPreRecordRejectAcknowledge ==========");
	var recordhandle = "" + getRecordHandle(message);
	removeJSONObjectInMemory(recordhandle);
}
function onPreRecordCancelAcknowledge(message)
{
	log.debug("======= onPreRecordCancelAcknowledge ==========");
	var recordhandle = "" + getRecordHandle(message);
	removeJSONObjectInMemory(recordhandle);
}
function onPreScheduledCall(message)
{
	log.debug("======= onPreScheduledCall ==========");
	addJSONObjectInMemoryCampaign(message); //false);
}
function onPreChainedRecordsDataEnd(message)
{
	log.debug("======= onPreChainedRecordsDataEnd ==========");
	addJSONObjectInMemoryCampaign(message); //false);
}

//==================================================================
// PushPreview
//==================================================================
function onPreOutboundpreviewEventEstablished(message)
{
	log.debug("======= onPreOutboundpreviewEventEstablished ==========");
	addJSONObjectInMemoryCampaign(message); //false);
}

function onPreOutboundpreviewEventEstablishedInternal(message)
{
	log.debug("======= onPreOutboundpreviewEventEstablishedInternal ==========");
	addJSONObjectInMemoryCampaign(message); //false);
}

function onPostOutboundpreviewEventReleasedInternal(message)
{
	onPostOutboundpreviewEventReleased(message);
}

function onPostOutboundpreviewEventReleased(message)
{
	log.debug("======= onPostOutboundpreviewEventReleased ==========");
	var recordhandle = "" + getRecordHandle(message);
	removeJSONObjectInMemory(recordhandle);
}

//==================================================================
//Events Twitter
//==================================================================
function onPreTwitterEventEstablishedInbound(message)
{
	addJSONObjectInMemory(message);
}
function onPostTwitterEventReleasedInbound(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}

function onPreTwitterEventReplyOutbound(message)
{
	/*
	onTwitterEventReplyOutbound
	onTwitterEventRetweetOutbound
	onTwitterEventRetweetWithCommentsOutbound
	onTwitterEventDirectMessageOutbound
	*/
	try
	{
		var msgType = message.attachdata._twitterMsgType;
		log.debug("onPreTwitterEventReplyOutbound with " + msgType);
		if((msgType === "Retweet") || (msgType === "DirectMessage"))
		{
			log.debug("onPreTwitterEventReplyOutbound with " + msgType);
			var myevent = "TwitterEvent{0}Outbound".format(msgType);
			log.debugFormat("onPreTwitterEventReply: the new event is on{0}", myevent);
			callSafetyFunction("onPre"+ myevent + "(message);", message);
			if(checkFunction("on" + myevent))
			{
				callSafetyFunction("on"+ myevent + "(message);", message);
			}
			return false;
		}
	}catch(e)
	{
		log.error("onPreTwitterEventReply: " + e.message);
	}
	return true;
}
//==================================================================
//Events Facebook
//==================================================================
function onPreFacebookEventEstablishedInbound(message)
{
	addJSONObjectInMemory(message);
}
function onPostFacebookEventReleasedInbound(message)
{
	removeJSONObjectInMemory(message.ConnectionID);
}

//==================================================================
//Generic Events
//==================================================================
function onPreWdeSwitchInteraction(message)
{
	var mymessage = getInteraction(message.InteractionID);
	if(mymessage)
	{
		var curr_message = getSelectedInteraction();
		if(curr_message)
		{
			log.infoFormat("[onPreWdeSwitchInteraction] Selected Interaction [{0}] Switch Interaction[{1}] ======================", curr_message.InteractionID, mymessage.InteractionID );
			
			if(curr_message.InteractionID != mymessage.InteractionID)
			{
				selectInteractionOptionByMessage(mymessage);
			}
		}
	}
}

//alert("iwsprescript well formed!");