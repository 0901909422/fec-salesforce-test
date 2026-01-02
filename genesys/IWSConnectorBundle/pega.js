//Custom Script specific to CSS Project

function dummycall() {
    alert("Reached Dummy Call");
    var CSMSessionId = window.parent.getSessionId();
    alert(CSMSessionId);
}
function createNewWorkFromIVR(message) {



    //calling create new work
    if (message.CallType == "Inbound") {

        var PhoneNum = message.attachdata.PhoneNo;
        if (!PhoneNum) {
            PhoneNum = "";
        }

        var NationalID = message.attachdata.CustNationalID;
        if (!NationalID) {
            NationalID = "";
        }
        var AgentID = message.AgentID;
        if (!AgentID) {
            AgentID = "";
        }
        var ANI = message.ANI;
        if (!ANI) {
            ANI = "";
        }
        var DNIS = message.DNIS;
        if (!DNIS) {
            DNIS = "";
        }
        var CallID = message.CallID;
        if (!CallID) {
            CallID = "";
        }
        var Place = message.Place;
        if (!Place) {
            Place = "";
        }
        var ThisQueue = message.ThisQueue;
        if (!ThisQueue) {
            ThisQueue = "";
        }
        var CallUuid = message.CallUuid;
        if (!CallUuid) {
            CallUuid = "";
        }
        /*CSM-7759: Add AttachDataCallUUID */
        var AttachDataCALLUUID = message.attachdata.CallUUID;
        if (!AttachDataCALLUUID) {
            AttachDataCALLUUID = "";
        }

        var Duration = message.Duration;
        if (!Duration) {
            Duration = "";
        }
        var TimeStamp = message.TimeStamp;
        if (!TimeStamp) {
            TimeStamp = "";
        }
        var CSR_SKILL_TO_BU = message.attachdata.CSR_SKILL_TO_BU;
        if (!CSR_SKILL_TO_BU) {
            CSR_SKILL_TO_BU = "";
        }
        var IVRPath = message.attachdata.IVRPath;
        if (!IVRPath) {
            IVRPath = "";
        }

        var GenesysInteractionID = message.InteractionID;
        var GenesysConnectionID = getSessionId();
        var messageJSON = JSON.stringify(message.attachdata);

        //building paramets for createnewwork

        var flowparams = "&ChanServInsName=&NationalID=" + NationalID + "&PhoneNum=" + PhoneNum + "&GenesysInteractionID=" + GenesysInteractionID + "&message=" + messageJSON + "&GenesysConnectionID=" + GenesysConnectionID + "&AgentID=" + AgentID + "&ANI=" + ANI + "&DNIS=" + DNIS + "&CallID=" + CallID + "&Place=" + Place + "&ThisQueue=" + ThisQueue + "&CallUuid=" + CallUuid + "&Duration=" + Duration + "&TimeStamp=" + TimeStamp + "&CSR_SKILL_TO_BU=" + CSR_SKILL_TO_BU + "&IVRPath=" + IVRPath + "&AttachDataCALLUUID=" + AttachDataCALLUUID;

        log.debug("Param ANI:" + message.ANI);

        //calling create new work

        pega.desktop.createNewWork("FECredit-Base-CS-Work-Interaction-Call", "", "CPMInteraction", flowparams, "", "", "");
    }

    if (message.CallType == "Outbound") {

        var PhoneNum = message.attachdata.GSW_PHONE;
        if (!PhoneNum) {
            PhoneNum = "";
        }

        var NationalID = message.attachdata.CustNationalID;
        if (!NationalID) {
            NationalID = "";
        }

        var ContractNum = message.attachdata.ContractId;

        if (!ContractNum) {
            ContractNum = "";
        }

        var ProductType = message.attachdata.ProductType;

        if (!ProductType) {
            ProductType = "";
        }

        var ProductSubType = message.attachdata.ProductSubType;

        if (!ProductSubType) {
            ProductSubType = "";
        }

        var CardAccountNum = message.attachdata.CardAccountNumber;

        if (!CardAccountNum) {
            CardAccountNum = "";
        }

        var MaskedCardNum = message.attachdata.MaskedCardNumber;

        if (!MaskedCardNum) {
            MaskedCardNum = "";
        }

        var DisbursalDate = message.attachdata.DisbursalDate;

        if (!DisbursalDate) {
            DisbursalDate = "";
        }

        var CardOpenDate = message.attachdata.CardOpenDate;

        if (!CardOpenDate) {
            CardOpenDate = "";
        }

        var CardPlasticID = message.attachdata.CardPlasticID;

        if (!CardPlasticID) {
            CardPlasticID = "";
        }

        var CampaignName = message.attachdata.GSW_CAMPAIGN_NAME;

        if (!CampaignName) {
            CampaignName = "";
        }

        var CallingList = message.attachdata.GSW_CALLING_LIST;

        if (!CallingList) {
            CallingList = "";
        }
        var AgentID = message.AgentID;
        if (!AgentID) {
            AgentID = "";
        }
        var ANI = message.ANI;
        if (!ANI) {
            ANI = "";
        }
        var DNIS = message.DNIS;
        if (!DNIS) {
            DNIS = "";
        }
        var CallID = message.CallID;
        if (!CallID) {
            CallID = "";
        }
        var Place = message.Place;
        if (!Place) {
            Place = "";
        }
        var ThisQueue = message.ThisQueue;
        if (!ThisQueue) {
            ThisQueue = "";
        }
        var CallUuid = message.CallUuid;
        if (!CallUuid) {
            CallUuid = "";
        }
        /*CSM-7759: Add AttachDataCallUUID */
        var AttachDataCallUUID = message.attachdata.CallUUID;
        if (!AttachDataCallUUID) {
            AttachDataCallUUID = "";
        }
        var Duration = message.Duration;
        if (!Duration) {
            Duration = "";
        }
        var TimeStamp = message.TimeStamp;
        if (!TimeStamp) {
            TimeStamp = "";
        }
        var CSR_SKILL_TO_BU = message.attachdata.CSR_SKILL_TO_BU;
        if (!CSR_SKILL_TO_BU) {
            CSR_SKILL_TO_BU = "";
        }
        var IVRPath = message.attachdata.IVRPath;
        if (!IVRPath) {
            IVRPath = "";
        }

        /*CSM-7836: Add Condition & Code when Click To Call */
        if (message.attachdata.ClickToCall != null && message.attachdata.ClickToCall == "true") {
            var PhoneNum = message.attachdata.PhoneNumber;
            if (!PhoneNum) {
                PhoneNum = "";
            }

            var NationalID = message.attachdata.NationalId;
            if (!NationalID) {
                NationalID = "";
            }

            var ContractNum = message.attachdata.ContractNumber;
            if (!ContractNum) {
                ContractNum = "";
            }

            var CardAccountNum = message.attachdata.AccountNumber;
            if (!CardAccountNum) {
                CardAccountNum = "";
            }
        }

        var GenesysInteractionID = message.InteractionID;
        var GenesysConnectionID = getSessionId();
        var messageJSON = JSON.stringify(message.attachdata);
        //building paramets for createnewwork

        var flowparams = "&ChanServInsName=&NationalID=" + NationalID + "&PhoneNum=" + PhoneNum + "&GenesysInteractionID=" + GenesysInteractionID + "&GenesysConnectionID=" + GenesysConnectionID + "&ProductType=" + ProductType + "&ProductSubType=" + ProductSubType + "&CardAccountNum=" + CardAccountNum + "&MaskedCardNum=" + MaskedCardNum + "&DisbursalDate=" + DisbursalDate + "&CardOpenDate=" + CardOpenDate + "&CardPlasticID=" + CardPlasticID + "&message=" + messageJSON + "&ContractNum=" + ContractNum + "&CampaignName=" + CampaignName + "&CallingList=" + CallingList + "&AgentID=" + AgentID + "&ANI=" + ANI + "&DNIS=" + DNIS + "&CallID=" + CallID + "&Place=" + Place + "&ThisQueue=" + ThisQueue + "&CallUuid=" + CallUuid + "&Duration=" + Duration + "&TimeStamp=" + TimeStamp + "&CSR_SKILL_TO_BU=" + CSR_SKILL_TO_BU + "&IVRPath=" + IVRPath + "&AttachDataCALLUUID=" + AttachDataCallUUID;



        //var flowparams = //"&ChanServInsName=&NationalID="+NationalID+"&PhoneNum="+PhoneNum+"&GenesysInteractionID="+GenesysInteractionID+"&GenesysConnectionID="+GenesysConnectionID+"&ProductType="+ProductType+"&ProductSubT//ype="+ProductSubType+"&CardAccountNum="+CardAccountNum+"&MaskedCardNum"+MaskedCardNum+"&DisbursalDate"+DisbursalDate+"&CardOpenDate="+CardOpenDate+"&CardPlasticID="+CardPlasticID;

        pega.desktop.createNewWork("FECredit-Base-CS-Work-Interaction-Outbound-Call", "", "CPMInteraction", flowparams, "", "", "");

    }

}
function SetCTCGenesysId(message) {
    var GenesysInteractionID = message.InteractionID;

    var GenesysConnectionID = getSessionId();

    var IsInteractionDone = "No";

    var InteractionId = message.attachdata.InteractionId;

    var oSafeURL = new SafeURL("FECredit-FW-CSFW-Work-Outbound.SetGenesysInteractionId");
    oSafeURL.put("GenesysInteractionId", GenesysInteractionID);
    oSafeURL.put("GenesysConnectionId", GenesysConnectionID);
    oSafeURL.put("IsInteractionDone", IsInteractionDone);
    oSafeURL.put("InteractionId", InteractionId);

    var strUrl = oSafeURL.toURL();

    httpRequestAsynch(strUrl, "", 50, 100);
}

function ResetCTCGenesysId(message) {

    var IsInteractionDone = "Yes";


    var oSafeURL = new SafeURL("FECredit-FW-CSFW-Work-Outbound.SetGenesysInteractionId");
    var InteractionId = message.attachdata.InteractionId;

    oSafeURL.put("IsInteractionDone", IsInteractionDone);
    oSafeURL.put("InteractionId", InteractionId);


    var strUrl = oSafeURL.toURL();

    httpRequestAsynch(strUrl, "", 50, 100);
}


function createNewWorkFromIVREmail(message) {

    //var GenesysInteractionID = message.Interaction.InteractionID;
    //var GenesysConnectionID = getSessionId();

    var Subject = message.attachdata.Subject;

    if (!Subject) {
        Subject = "";
    }
    var From = message.attachdata.FromAddress;
    if (!From) {
        From = "";
    }

    var MessageText = ""
    /*var MessageText=message.EntrepriseInteractionCurrent.MessageText;
    if(!MessageText) {
      MessageText = "";
    }*/

    var StructuredText = message.EntrepriseInteractionCurrent.StructuredText;
    if (!StructuredText) {
        StructuredText = "";
    }
    StructuredText = encodeURIComponent(encodeURIComponent(StructuredText));

    var GenesysInteractionID = message.InteractionID;
    if (!GenesysInteractionID) {
        GenesysInteractionID = "";
    }
    var GenesysConnectionID = getSessionId();
    if (!GenesysConnectionID) {
        GenesysConnectionID = "";
    }
    //added additional params for Email -

    var PhoneNum = message.attachdata.GSW_PHONE;
    if (!PhoneNum) {
        PhoneNum = "";
    }

    var NationalID = message.attachdata.CustNationalID;
    if (!NationalID) {
        NationalID = "";
    }

    var ContractNum = message.attachdata.ContractId;

    if (!ContractNum) {
        ContractNum = "";
    }

    var ProductType = message.attachdata.ProductType;

    if (!ProductType) {
        ProductType = "";
    }

    var ProductSubType = message.attachdata.ProductSubType;

    if (!ProductSubType) {
        ProductSubType = "";
    }

    var CardAccountNum = message.attachdata.CardAccountNumber;

    if (!CardAccountNum) {
        CardAccountNum = "";
    }

    var MaskedCardNum = message.attachdata.MaskedCardNumber;

    if (!MaskedCardNum) {
        MaskedCardNum = "";
    }

    var DisbursalDate = message.attachdata.DisbursalDate;

    if (!DisbursalDate) {
        DisbursalDate = "";
    }

    var CardOpenDate = message.attachdata.CardOpenDate;

    if (!CardOpenDate) {
        CardOpenDate = "";
    }

    var CardPlasticID = message.attachdata.CardPlasticID;

    if (!CardPlasticID) {
        CardPlasticID = "";
    }
    // CSM-3771 : Added LandingEmailDatetime
    var LandingEmailDatetime = message.attachdata.LandingEmailDatetime;

    if (!LandingEmailDatetime) {
        LandingEmailDatetime = "";
    }

    pega.web.config.cmd.pegaAction.httpMethod = "POST";

    //var message = JSON.stringify(message.attachdata);
    //building paramets for createnewwork
    var flowparams = "&Subject=" + Subject + "&From=" + From + "&StructuredText=" + StructuredText + "&MessageText=" + MessageText + "&GenesysInteractionID=" + GenesysInteractionID + "&GenesysConnectionID=" + GenesysConnectionID + "&NationalID=" + NationalID + "&PhoneNum=" + PhoneNum + "&ProductType=" + ProductType + "&ProductSubType=" + ProductSubType + "&CardAccountNum=" + CardAccountNum + "&MaskedCardNum=" + MaskedCardNum + "&DisbursalDate=" + DisbursalDate + "&CardOpenDate=" + CardOpenDate + "&CardPlasticID=" + CardPlasticID + "&ContractNum=" + ContractNum + "&LandingEmailDatetime=" + LandingEmailDatetime;
    //calling create new work
    pega.desktop.createNewWork("FECredit-Base-CS-Work-Interaction-InCorr", "", "CPMInteraction", flowparams, "", "", "");

}

//function WrapupCall(genesysinteractionid, interactioncaseid, servicecaseids, businessresult)
function WrapupCall(genesysinteractionid, interactioncaseid, servicecaseids, businessresult) {

    var csmwrapupcoll = createUserData();

    csmwrapupcoll.put("InteractionCaseID", interactioncaseid);
    csmwrapupcoll.put("ServiceCaseID", servicecaseids);
    csmwrapupcoll.put("Business Result", businessresult);

    window.parent.SetAttachdataById(genesysinteractionid, csmwrapupcoll);
    //window.parent.setattachdata(csmwrapupcoll);
    window.parent.InteractionMarkDone(genesysinteractionid);

}

function SetConnectSuccessClickToCall(message) {
    var oSafeURL = new SafeURL("FECredit-FW-CSFW-Work-SCM.SetConnectMessageClickToCall");
    var ServiceCaseId = message.attachdata.ServiceCaseId;
    oSafeURL.put("ServiceCaseId", ServiceCaseId);
    oSafeURL.put("Message", "Success");

    var strUrl = oSafeURL.toURL();
    //httpRequestAsynch(strUrl, "", 50, 100);
    pega.u.d.asyncRequest("POST", SafeURL_createFromURL(strUrl), {
        success: function (oResponse) {
            RefreshClickToCallMessageErrorSection(ServiceCaseId);
        },
        failure: function () { },
        scope: this
    }, null);
}

function SetConnectFailClickToCall(ServiceCaseId) {
    var oSafeURL = new SafeURL("FECredit-FW-CSFW-Work-SCM.SetConnectMessageClickToCall");
    oSafeURL.put("ServiceCaseId", ServiceCaseId);
    oSafeURL.put("Message", "Fail");

    var strUrl = oSafeURL.toURL();
    //httpRequestAsynch(strUrl, "", 50, 100);
    pega.u.d.asyncRequest("POST", SafeURL_createFromURL(strUrl), {
        success: function (oResponse) {
            RefreshClickToCallMessageErrorSection(ServiceCaseId);
        },
        failure: function () { },
        scope: this
    }, null);
}

function RefreshClickToCallMessageErrorSection(ServiceCaseId) {
    //refresh the section
    var iframes = window.parent.document.getElementsByTagName('iframe');
    for (var i = 0; i < iframes.length; i++) {
        try {
            var iframeWindow = iframes[i].contentWindow;
            if (typeof iframeWindow.checkForRefreshClickToCall === 'function') {
                var res = iframeWindow.checkForRefreshClickToCall(ServiceCaseId);
                if (res === true) {
                    break;
                }
            }
        } catch (e) { }
    }
    //end refresh
}

function MakeCallWrapper(accountnumber, contractnumber, producttype, nationalid, number, clicktocall, interactionid, ctcgenesysid, servicecaseid) {
    var makecallparam = createUserData();

    makecallparam.put("AccountNumber", accountnumber);
    makecallparam.put("ContractNumber", contractnumber);
    makecallparam.put("ProductType", producttype);
    makecallparam.put("NationalId", nationalid);
    makecallparam.put("PhoneNumber", number);
    makecallparam.put("ClickToCall", clicktocall);
    makecallparam.put("InteractionId", interactionid);
    makecallparam.put("CTCGenesysId", ctcgenesysid);
    makecallparam.put("ServiceCaseId", servicecaseid);

    //console.table("MakeCallWrapper");
    //console.table(makecallparam['toJsonObject']());
    if (ctcgenesysid == "") {
        //window.parent.MakeCall(number, makecallparam);
        MakeCallClickToCall(number, makecallparam);
        // Fail if no response within 5 minutes
        setTimeout(function () {
            SetConnectFailClickToCall(servicecaseid);
        }, 300000);
    }
    else {
        alert("You are already on a call with the customer. Please close the current interaction to place a new call!!!");
    }
}

//clone MakeCall function in iwcommandmin.js to add error handling
function MakeCallClickToCall(number, params) {
    var servicecaseid = params.get("ServiceCaseId");
    log['debug']('try to make a call:' + number);
    var command = {
        "\x63\x6F\x6D\x6D\x61\x6E\x64": 'MAKEACALL',
        "\x73\x65\x73\x73\x69\x6F\x6E\x69\x64": sessionid,
        "\x6E\x75\x6D\x62\x65\x72": number,
        "\x61\x74\x74\x61\x63\x68\x64\x61\x74\x61": (params ? params['toJsonObject']() : {})
    };

    var myparams = JSON['stringify'](command);
    log['debug']('try to call executeStandardCommand:' + myparams);

    var mycommand = 'EXECUTECOMMAND';
    myparams = 'message=' + encodeURIComponent(myparams);
    if (!myurl) {
        log['error']('Server url not initialized');
        return
    }
    var myjsonp = getWdeJsonp();
    myjsonp({
        url: myurl + mycommand,
        data: myparams,
        dataType: 'jsonp',
        callbackParameter: 'jsonp_callback',
        timeout: 10000,
        success: function (data, status) {
            log['debug']('success ' + data)
        },
        error: function (XHR, textStatus, errorThrown) {
            SetConnectFailClickToCall(servicecaseid);
            log['error']('status: ' + textStatus + '\x0Aerror: ' + errorThrown)
        }
    })
}


/*
Agreed Parameters witth Genesys
Incoming:

IVRPath
IVRExitTag
IVRSelectedLanguage
IVRSelectedProductType
IVRContractID
SurveyOptIn
SurveyLanguage
PhoneNo
CustNationalID
CustEmailAddress

OutGoing:
ServiceCaseID
InteractionCaseID
Business Result

*/
//static-content-hash-trigger-NON