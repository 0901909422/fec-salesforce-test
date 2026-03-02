//Custom Script specific to CSS Project - CHUYỂN ĐỔI SANG SALESFORCE LWC
// Hàm gửi sự kiện tùy chỉnh đến LWC Component
function dispatchSalesforceEvent(eventType, data) {
    try {
        log.debugFormat("Dispatching Salesforce Event: [{0}] with data: {1}", eventType, JSON.stringify(data));
        // GỌI HÀM postMessageToLWC ĐƯỢC ĐỊNH NGHĨA TRONG VF PAGE
        if (typeof window.postMessageToLWC === 'function') {
            window.postMessageToLWC(eventType, data);
        } else {
            log.error("Error: window.postMessageToLWC is not defined in VF Host.");
        }
    } catch (e) {
        log.error("Error dispatching Salesforce Event: " + e.message);
    }
}
function dummycall()
{
  alert("Reached Dummy Call");
  dispatchSalesforceEvent('GetSessionId', { sessionId: sessionid });
}

/**
 * Xử lý sự kiện Ringing Inbound và Established Outbound (tạo Case)
 */
function createNewWorkFromIVR(message){
    
    console.log("createNewWorkFromIVR called");

    var callData = {}; // Đối tượng chứa tất cả tham số để gửi đến Salesforce
    var eventType = '';

    //========================================
    // INBOUND CALL HANDLING
    //========================================
    if(message.CallType == "Inbound"){
        eventType = "InboundRinging";
        
        var PhoneNum = message.attachdata.PhoneNo || "";
        var NationalID = message.attachdata.CustNationalID || "";
        var AgentID = message.AgentID || "";
        var ANI = message.ANI || "";
        var DNIS = message.DNIS || "";
        var CallID = message.CallID || "";
        var Place = message.Place || "";
        var ThisQueue = message.ThisQueue || "";
        var CallUuid = message.CallUuid || ""; 
        var AttachDataCALLUUID = message.attachdata.CallUUID || ""; // CSM-7759
        var Duration = message.Duration || "";
        var TimeStamp = message.TimeStamp || "";
        var CSR_SKILL_TO_BU = message.attachdata.CSR_SKILL_TO_BU || "";
        var IVRPath = message.attachdata.IVRPath || "";
        
        var GenesysInteractionID = message.InteractionID;
        var GenesysConnectionID = getSessionId();
        var messageJSON = JSON.stringify(message.attachdata);
        
        // Gán tham số vào đối tượng callData
        callData = {
            "PhoneNum": PhoneNum,
            "NationalID": NationalID,
            "GenesysInteractionID": GenesysInteractionID,
            "GenesysConnectionID": GenesysConnectionID,
            "AgentID": AgentID,
            "ANI": ANI,
            "DNIS": DNIS,
            "CallID": CallID,
            "Place": Place,
            "ThisQueue": ThisQueue,
            "CallUuid": CallUuid,
            "Duration": Duration,
            "TimeStamp": TimeStamp,
            "CSR_SKILL_TO_BU": CSR_SKILL_TO_BU,
            "IVRPath": IVRPath,
            "AttachDataCALLUUID": AttachDataCALLUUID,
            "AttachDataJSON": messageJSON
        };
        
        log.debug( "Param ANI:" + message.ANI);
    }
    
    //========================================
    // OUTBOUND CALL HANDLING
    //========================================
    if(message.CallType == "Outbound"){
        eventType = "OutboundEstablished";
        
        // Khởi tạo các biến với giá trị mặc định
        var PhoneNum = message.attachdata.GSW_PHONE || "";
        var NationalID = message.attachdata.CustNationalID || "";
        var ContractNum = message.attachdata.ContractId || "";
        var ProductType = message.attachdata.ProductType || "";
        var ProductSubType = message.attachdata.ProductSubType || "";
        var CardAccountNum = message.attachdata.CardAccountNumber || "";
        var MaskedCardNum = message.attachdata.MaskedCardNumber || "";
        var DisbursalDate = message.attachdata.DisbursalDate || "";
        var CardOpenDate = message.attachdata.CardOpenDate || "";
        var CardPlasticID = message.attachdata.CardPlasticID || "";
        var CampaignName = message.attachdata.GSW_CAMPAIGN_NAME || "";
        var CallingList = message.attachdata.GSW_CALLING_LIST || "";
        var AgentID = message.AgentID || "";
        var ANI = message.ANI || "";
        var DNIS = message.DNIS || "";
        var CallID = message.CallID || "";
        var Place = message.Place || "";
        var ThisQueue = message.ThisQueue || "";
        var CallUuid = message.CallUuid || ""; 
        var AttachDataCallUUID = message.attachdata.CallUUID || ""; // CSM-7759
        var Duration = message.Duration || "";
        var TimeStamp = message.TimeStamp || "";
        var CSR_SKILL_TO_BU = message.attachdata.CSR_SKILL_TO_BU || "";
        var IVRPath = message.attachdata.IVRPath || "";

        // CSM-7836: Xử lý khi Click To Call
        if(message.attachdata.ClickToCall != null && message.attachdata.ClickToCall == "true") {
            PhoneNum = message.attachdata.PhoneNumber || "";
            NationalID = message.attachdata.NationalId || "";
            ContractNum = message.attachdata.ContractNumber || "";
            CardAccountNum = message.attachdata.AccountNumber || "";
        }
        
        var GenesysInteractionID = message.InteractionID;
        var GenesysConnectionID = getSessionId();
        var messageJSON = JSON.stringify(message.attachdata);
        
        // Gán tham số vào đối tượng callData
        callData = {
            "PhoneNum": PhoneNum,
            "NationalID": NationalID,
            "GenesysInteractionID": GenesysInteractionID,
            "GenesysConnectionID": GenesysConnectionID,
            "ProductType": ProductType,
            "ProductSubType": ProductSubType,
            "CardAccountNum": CardAccountNum,
            "MaskedCardNum": MaskedCardNum,
            "DisbursalDate": DisbursalDate,
            "CardOpenDate": CardOpenDate,
            "CardPlasticID": CardPlasticID,
            "ContractNum": ContractNum,
            "CampaignName": CampaignName,
            "CallingList": CallingList,
            "AgentID": AgentID,
            "ANI": ANI,
            "DNIS": DNIS,
            "CallID": CallID,
            "Place": Place,
            "ThisQueue": ThisQueue,
            "CallUuid": CallUuid,
            "Duration": Duration,
            "TimeStamp": TimeStamp,
            "CSR_SKILL_TO_BU": CSR_SKILL_TO_BU,
            "IVRPath": IVRPath,
            "AttachDataCALLUUID": AttachDataCallUUID,
            "AttachDataJSON": messageJSON
        };
    }
    
    // Gửi sự kiện chung để LWC Component xử lý việc tạo Case
    if (eventType) {
        dispatchSalesforceEvent(eventType, callData);
    }
}

/**
 * Xử lý khi cuộc gọi Click-to-Call được thiết lập
 * Thay thế cho việc gọi SetGenesysInteractionId trong Pega
 */
function SetCTCGenesysId(message){
    
    var GenesysInteractionID = message.InteractionID;
    var GenesysConnectionID = getSessionId();
    var IsInteractionDone = "No";
    var InteractionId = message.attachdata.InteractionId; // ID của bản ghi Outbound trong Salesforce/Pega cũ
    
    var data = {
        "GenesysInteractionId": GenesysInteractionID,
        "GenesysConnectionId": GenesysConnectionID,
        "IsInteractionDone": IsInteractionDone,
        "InteractionId": InteractionId
    };
    
    // Gửi sự kiện để LWC Component gọi Apex cập nhật bản ghi CTC trong Salesforce
    dispatchSalesforceEvent("SetCTCGenesysId", data);
}

/**
 * Xử lý khi cuộc gọi Click-to-Call kết thúc (Reset)
 */
function ResetCTCGenesysId(message){
    
    var IsInteractionDone = "Yes";
    var InteractionId = message.attachdata.InteractionId;
    
    var data = {
        "IsInteractionDone": IsInteractionDone,
        "InteractionId": InteractionId
    };
    
    // Gửi sự kiện để LWC Component gọi Apex cập nhật bản ghi CTC trong Salesforce
    dispatchSalesforceEvent("ResetCTCGenesysId", data);
}


/**
 * Xử lý sự kiện Email (tạo Case)
 */
function createNewWorkFromIVREmail(message){
    
    var Subject= message.attachdata.Subject || "";
    var From=message.attachdata.FromAddress || "";
    var StructuredText=message.EntrepriseInteractionCurrent.StructuredText || "";
  
    var GenesysInteractionID = message.InteractionID || "";
    var GenesysConnectionID = getSessionId() || "";
  
    //added additional params for Email -
    var PhoneNum = message.attachdata.GSW_PHONE || "";
    var NationalID = message.attachdata.CustNationalID || "";
    var ContractNum = message.attachdata.ContractId || "";
    var ProductType = message.attachdata.ProductType || "";
    var ProductSubType = message.attachdata.ProductSubType || "";
    var CardAccountNum = message.attachdata.CardAccountNumber || "";
    var MaskedCardNum = message.attachdata.MaskedCardNumber || "";
    var DisbursalDate = message.attachdata.DisbursalDate || "";
    var CardOpenDate = message.attachdata.CardOpenDate || "";
    var CardPlasticID = message.attachdata.CardPlasticID || "";
    var LandingEmailDatetime = message.attachdata.LandingEmailDatetime || ""; // CSM-3771
  
    var emailData = {
        "Subject": Subject,
        "From": From,
        "StructuredText": StructuredText,
        "GenesysInteractionID": GenesysInteractionID,
        "GenesysConnectionID": GenesysConnectionID,
        "PhoneNum": PhoneNum,
        "NationalID": NationalID,
        "ContractNum": ContractNum,
        "ProductType": ProductType,
        "ProductSubType": ProductSubType,
        "CardAccountNum": CardAccountNum,
        "MaskedCardNum": MaskedCardNum,
        "DisbursalDate": DisbursalDate,
        "CardOpenDate": CardOpenDate,
        "CardPlasticID": CardPlasticID,
        "LandingEmailDatetime": LandingEmailDatetime
    };
    
    // Gửi sự kiện để LWC Component xử lý việc tạo Email Case
    dispatchSalesforceEvent("EmailInboundEstablished", emailData);
}

/**
 * Gửi dữ liệu Wrap-up đến Genesys và kết thúc cuộc gọi
 * (LƯU Ý: Việc cập nhật Case trong Salesforce cần được gọi riêng từ LWC/Apex)
 */
function WrapupCall(genesysinteractionid, interactioncaseid, servicecaseids, businessresult)
{
    // >>> BƯỚC 1: GỬI SỰ KIỆN ĐỂ CẬP NHẬT CASE TRONG SALESFORCE <<<
    var wrapupData = {
        "InteractionCaseID": interactioncaseid,
        "ServiceCaseID": servicecaseids,
        "BusinessResult": businessresult,
        "GenesysInteractionID": genesysinteractionid
    };
    dispatchSalesforceEvent("WrapupCall", wrapupData);

    // >>> BƯỚC 2: GỬI DỮ LIỆU WRAP-UP ĐẾN GENESYS VÀ KẾT THÚC CUỘC GỌI <<<
    var csmwrapupcoll = createUserData();
    
    // Lưu ý: Chỉ gửi các tham số Genesys cần thiết để đính kèm vào tương tác (ví dụ: cho báo cáo Genesys)
    csmwrapupcoll.put("InteractionCaseID", interactioncaseid);
    csmwrapupcoll.put("ServiceCaseID", servicecaseids);
    csmwrapupcoll.put("Business Result", businessresult);
    
    // Đính kèm dữ liệu wrap-up vào tương tác Genesys
    SetAttachdataById(genesysinteractionid, csmwrapupcoll);
    
    // Gửi lệnh kết thúc cuộc gọi/interaction cho Genesys
    InteractionMarkDone(genesysinteractionid);
}

/**
 * Hàm gửi tin nhắn/lỗi khi kết nối Click-to-Call thành công
 * Thay thế cho việc gọi SetConnectMessageClickToCall trong Pega
 */
function SetConnectSuccessClickToCall(message) {
    var ServiceCaseId = message.attachdata.ServiceCaseId;
    var data = {
        "ServiceCaseId": ServiceCaseId,
        "Message": "Success"
    };

    // Gửi sự kiện để LWC Component gọi Apex cập nhật trạng thái
    dispatchSalesforceEvent("SetConnectMessageClickToCall", data);
}

/**
 * Hàm gửi tin nhắn/lỗi khi kết nối Click-to-Call thất bại
 * Thay thế cho việc gọi SetConnectMessageClickToCall trong Pega
 */
function SetConnectFailClickToCall(ServiceCaseId) {
    var data = {
        "ServiceCaseId": ServiceCaseId,
        "Message": "Fail"
    };

    // Gửi sự kiện để LWC Component gọi Apex cập nhật trạng thái
    dispatchSalesforceEvent("SetConnectMessageClickToCall", data);
}

/**
 * Thay thế cho RefreshClickToCallMessageErrorSection trong Pega
 * (Logic này hoàn toàn thuộc về Salesforce/LWC, không cần thiết ở đây)
 */
function RefreshClickToCallMessageErrorSection(ServiceCaseId) {
  // Logic refresh UI sẽ do LWC/Apex xử lý sau khi cập nhật trạng thái.
}


/**
 * Hàm bọc lệnh MakeCall cho Click-to-Call
 * (Giữ logic kiểm tra cuộc gọi đang hoạt động và gửi lệnh MakeCallClickToCall)
 */
function MakeCallWrapper(accountnumber,contractnumber,producttype,nationalid,number,clicktocall,interactionid,ctcgenesysid, servicecaseid)
{
    var makecallparam = createUserData();
    
    makecallparam.put("AccountNumber",accountnumber);
    makecallparam.put("ContractNumber",contractnumber);
    makecallparam.put("ProductType",producttype);
    makecallparam.put("NationalId",nationalid);
    makecallparam.put("PhoneNumber",number);
    makecallparam.put("ClickToCall",clicktocall);
    makecallparam.put("InteractionId",interactionid);
    makecallparam.put("CTCGenesysId",ctcgenesysid);
    makecallparam.put("ServiceCaseId",servicecaseid);
    
    if(ctcgenesysid == ""){
        // Gọi hàm MakeCall với xử lý lỗi tùy chỉnh (được định nghĩa dưới đây)
        MakeCallClickToCall(number, makecallparam);
        
        // Thiết lập timeout để xử lý trường hợp không có phản hồi từ Genesys (Fail if no response within 5 minutes)
        setTimeout(function() {
          SetConnectFailClickToCall(servicecaseid);
        }, 300000);
    }
    else {
      alert("You are already on a call with the customer. Please close the current interaction to place a new call!!!");
    }
}

/**
 * Hàm gọi lệnh MakeCall với xử lý lỗi tùy chỉnh
 * (Được clone từ iwcommandmin.js để thêm SetConnectFailClickToCall trong trường hợp lỗi)
 */
function MakeCallClickToCall(number, params) {
    var servicecaseid = params.get("ServiceCaseId");
    log['debug']('try to make a call:' + number);
    
    // Lệnh MakeCall gửi đến IWS Connector
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
        success: function(data, status) {
            log['debug']('success ' + data)
        },
        error: function(XHR, textStatus, errorThrown) {
            // Xử lý lỗi: Gọi hàm báo thất bại
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