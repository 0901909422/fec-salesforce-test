///========================================
/// SoftPhone s.r.l
/// IWSConnector release 1.7.1.0
/// Date: 19/01/2017
///========================================
/**
 * Possible log levels:
 * 	enumloglevel.debug
 * 	enumloglevel.info
 * 	enumloglevel.warn
 * 	enumloglevel.error
 * 	enumloglevel.none 
 */
setLogLevel(enumloglevel.debug);

/* if the sip disaster-recovery is enabled, please uncomment the row below */
//setSipDisasterRecovery(true);

/*
 * if equals false, means that you want manage an interaction at time (not valid for SAP) 
 * in other words, the switch event not happen if is already present an interaction in the combo 
 */
//setMultyInteractions(false);
//setMultyInteractionsEvents(true);

/*
 * Set a place-holder in WDE, to know the selected Interaction in the CRM side
 * (useful in CRM crash/refresh scenario)
 */
setPlaceHolder(true);



/*
 * Remove the "session exit command", when the document-unload is catch.  
 * The "session exit command" break the Connector communication. 
 */
removeExitOnDocumentUnload();

/*
* Set the Compact menu, instead of the dropdown multi-interaction
*/
//enableCompactMenu();

/*
 * If your web application, use the $ sign as a shortcut, the replace the row below:
 * - $(document).ready(function() {
 * with the following rows:
 * - var $connector = $.noConflict();
 * - $connector(document).ready(function() {
 */
$(document).ready(function() {
	addFormatInteraction("voice", "{0} {1} {2}", "message.CallType, message.MediaName, (message.ANI?message.ANI:message.DNIS)");
	addFormatInteraction("voice, instant messaging", "{0} {1} {2}", "message.CallType, message.MediaName, (message.ANI?message.ANI:message.DNIS)");
	addFormatInteraction("email", "{0} {1} {2}", "message.CallType, message.MediaName, ((message.CallType=='Inbound')?message.attachdata.FromAddress:message.attachdata.To)");
	addFormatInteraction("chat", "{0} {1} {2}", "message.CallType, message.MediaName, message.attachdata.EmailAddress");
	addFormatInteraction("workitem", "{0} {1} from {2}", "message.CallType, message.MediaName, message.ExternalId");
	addFormatInteraction("sms", "{0} {1} from {2}", "message.CallType, message.MediaName, (message.EntrepriseInteractionCurrent ? message.EntrepriseInteractionCurrent.From : message.attachdata.From)");
	addFormatInteraction("facebook", "{0} {1} from {2}", "message.CallType, message.MediaName, message.attachdata.From");
	addFormatInteraction("preview", "{0} agent {1}", "message.attachdata.GSW_CAMPAIGN_NAME, message.attachdata.GSW_AGENT_ID");
	//addFormatInteraction("preview", "preview: {0}", "(message.ConnectionID ? message.ConnectionID : message.attachdata.GSW_CAMPAIGN_NAME )");
	//Initialize the context
	//initIWSToolBar(window.parent.frames['FrameIWSConnector'] ,'#IWSConnectorToolbar', 'images');
	//show the IWSTollBar toolbar with wished controls
	//showIWSToolBar(true, true, true);
	//start the connection with IWS

    //HTTP
  	//createConnection('127.0.0.1', '6969', {});
  
    //HTTPS  
	console.log("createSecureConnection ...");
    createSecureConnection('127.0.0.1', '6969', {});
  
    addFilters();
	
	});

function addFilters()
{
	addFilter("onEventRingingInbound", "action");
	addFilter("onEventRingingConsult", "action");
	addFilter("onEventEstablishedInbound", "action");
	addFilter("onEventEstablishedConsult", "action");
	addFilter("onEventEstablishedOutbound", "action");
	addFilter("onEventDialingOutbound", "action");
	addFilter("onEventPartyChangedInbound", "action");
	
}

function action(message)
{
	log.debug("Called action function...");
	//if the attach is defined
	if(message.attachdata.CRM)
	{
		log.debugFormat("action - message.attachdata.CRM [{0}] ", message.attachdata.CRM);
		return (message.attachdata.CRM == "siebel");
	}
	else	
		return true;
}
//static-content-hash-trigger-YUI