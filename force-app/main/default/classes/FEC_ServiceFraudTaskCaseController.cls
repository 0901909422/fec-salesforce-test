public with sharing class FEC_ServiceFraudTaskCaseController {
    public static final Boolean DEBUG_LOG = true;
    public static final String ERR_MISS_FRAUD_CASE = System.Label.Err_Missing_Fraud_Case;
    public static final String MSG_CANCEL_SUCCESS = System.Label.Msg_Cancel_Success;
    public static final String MSG_CANCEL_FAILED  = System.Label.Msg_Cancel_Failed;
    public static final String MSG_CREATE_SUCCESS = System.Label.Msg_Create_Success;
    public static final String MSG_CREATE_FAILED  = System.Label.Msg_Create_Failed;
    public static final String MSG_UPDATE_SUCCESS = System.Label.Msg_Update_Success;
    public static final String MSG_UPDATE_FAILED  = System.Label.Msg_Update_Failed;
    public static final String ERR_SYSTEM         = System.Label.Err_System;

    


    @AuraEnabled(cacheable=true)
    public static FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO getCaseData(String caseId) {
    
        FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto = initBaseDTO(caseId);

        // Get FEC_ID_Search__c from Case record to find the integration case
        String integrateCaseId = null;
        if (String.isNotBlank(caseId)) {
            List<Case> cases = [
                SELECT FEC_ID_Search__c FROM Case WHERE Id = :caseId LIMIT 1
            ];
            if (!cases.isEmpty() && String.isNotBlank(cases[0].FEC_ID_Search__c)) {
                integrateCaseId = cases[0].FEC_ID_Search__c;
            }
        }
        log('[getCaseData] caseId=' + caseId + ' | integrateCaseId=' + integrateCaseId);

        FEC_Integration_Case__c serviceCase = getServiceCase(caseId);
        if (serviceCase == null) {
            return dto;
        }
       
    
        dto.customer = getCustomerData(caseId);
    
        populateCaseAndTask(dto, serviceCase, integrateCaseId);
        populateFraudHierarchy(dto, serviceCase);

        // Check if case is assigned to current user and get owner name
        if (String.isNotBlank(caseId)) {
            List<Case> ownerCheck = [SELECT OwnerId, Owner.Name, Owner.Type FROM Case WHERE Id = :caseId LIMIT 1];
            if (!ownerCheck.isEmpty()) {
                Case c = ownerCheck[0];
                dto.isAssignedToCurrentUser = c.OwnerId == UserInfo.getUserId();
                if (c.OwnerId.getSObjectType() == User.SObjectType) {
                    dto.assignedToName = c.Owner.Name;
                } else {
                    // Owner is a Queue
                    List<Group> queues = [SELECT Name FROM Group WHERE Id = :c.OwnerId LIMIT 1];
                    dto.assignedToName = !queues.isEmpty() ? queues[0].Name : c.Owner.Name;
                }
            }
        }
    
        return dto;
    }

    @AuraEnabled
    public static FEC_IntegrationFraudCaseUtil.FraudCaseResponse submitProcessCaseDecision(String caseId, String decision, String subDecision, String reason, String remarks) { 
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse response = new FEC_IntegrationFraudCaseUtil.FraudCaseResponse();
        String serviceName   = FEC_FraudConstantCommon.FRAUD_CASE_PROCESS_NAME;
        String requestBody   = '';
        String responseXml   = '';
        try {
            log('================= SUBMIT FRAUD CASE(TK) START =================');   
            FEC_Integration_Case__c serviceCaseInfo = getServiceCase(caseId);
            if(serviceCaseInfo != null) {
                String channel      = FEC_FraudConstantCommon.SYSTEM_CHANNEL;             
                String faudCaseId       = serviceCaseInfo.FEC_CaseID__c;
                String channelCode = FEC_FraudConstantCommon.DEFAULT_CHANNEL_INTEGRATION_CODE;
                //Check Fraud Case Id
                 if (String.isBlank(faudCaseId)) {
                   response.success =  false;
                   response.responseCode = 0;                
                   response.message = ERR_MISS_FRAUD_CASE;
                   return response;                
               }
                //Get current user
                String creatorEmail = UserInfo.getUserEmail();                
                // 2. Build SOAP Sys
                FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
                
                sys.Channel       = channel;
                sys.TransactionID = FEC_IntegrationFraudCaseUtil.generateUUID();
                sys.DateTime_x    = System.now();
      
                log('SYS: ' + JSON.serializePretty(sys));
      
                // 3. Build CaseInfo
                FEC_IntegrationSoapFraudcaseService.CaseInfoType4 caseInfo = new FEC_IntegrationSoapFraudcaseService.CaseInfoType4();
                caseInfo.CaseID = faudCaseId;
                caseInfo.Remarks = remarks;
                caseInfo.Decision = decision;
                caseInfo.SubDecision = subDecision;
                caseInfo.Reason = reason;
             
                log('CASEINFO: ' + JSON.serializePretty(caseInfo));  
    
                // 4. Build CreatorInfo
                FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
                creator.CreatorEmail = creatorEmail;
      
                log('CREATOR: ' + JSON.serializePretty(creator));
            //      requestBody = JSON.serializePretty(new Map<String, Object>{
            //        'Sys'        => sys,
            //        'CaseIfo'   => caseInfo,
            //        'Creator'    => creator
            //    });
           
             FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper reqWrapper = new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
             reqWrapper.caseId = faudCaseId;
             reqWrapper.serviceCaseId = serviceCaseInfo.FEC_Service_Case_ID__c;
             reqWrapper.channelCode = channelCode;

            
            log('FEC_IntegrationSoapFraudcaseService-callProcessFraudCaseService: ' + reqWrapper);
             // 3. Call SOAP service
             FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType apiRes = null;
             if (FEC_FraudConstantCommon.USE_MOCK_PROCESS_CASE) {
                 // Mock response for testing
                 apiRes = new FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType();
                 apiRes.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
                 apiRes.Sys.Code = '1';
                 apiRes.Sys.Description = 'Success';
                 apiRes.Sys.TransactionID = FEC_IntegrationFraudCaseUtil.generateUUID();
                 apiRes.Sys.DateTime_x = System.now();
                 log('[TEST] Using mock ProcessCaseResponse');
             } else {
                 apiRes = FEC_IntegrationFraudService.callProcessFraudCaseService(reqWrapper, sys, caseInfo, creator);
             }
            
             log('LOG-callProcessFraudCaseService: '+ apiRes);
             // 4. Handle response
             response = handleProcessCaseResponse(apiRes, reqWrapper, sys, caseInfo, creator);
             log('LOG-handleProcessCaseResponse: '+ response);

             // Insert case remark if successful
             if (response.success && String.isNotBlank(remarks)) {
                 try {
                     FEC_Case_Remarks__c remark = new FEC_Case_Remarks__c();
                     remark.FEC_Case__c = caseId;
                     remark.FEC_Case_Remarks__c = remarks;
                     remark.FEC_User__c = UserInfo.getUserId();
                     remark.FEC_User_Role__c = UserInfo.getUserRoleId();
                     remark.FEC_Stage_Name__c = decision;
                     insert remark;
                     log('[submitProcessCaseDecision] Case remark inserted: ' + remark.Id);
                 } catch (Exception remarkEx) {
                     log('[submitProcessCaseDecision] Failed to insert remark: ' + remarkEx.getMessage());
                 }
             }

             // Update Case status based on decision
             if (response.success) {
                 try {
                     Case caseToUpdate = new Case(Id = caseId);
                     String caseStatus = (decision == FEC_FraudConstantCommon.PROCESS_CASE_SUCCESS_STATUS)
                         ? FEC_FraudConstantCommon.RESOLVED_COMPLETED
                         : FEC_FraudConstantCommon.RESOLVED_CANCEL;
                     caseToUpdate.Status = caseStatus;
                     update caseToUpdate;

                     // Update FEC_Integration_Case__c status
                     if (serviceCaseInfo != null && serviceCaseInfo.Id != null) {
                         FEC_Integration_Case__c intCase = new FEC_Integration_Case__c(Id = serviceCaseInfo.Id);
                         intCase.FEC_Case_Status__c = caseStatus;
                         //FEC_IntegrationFraudCaseUtil.mapCaseStatus(caseStatus);
                         intCase.FEC_Updated_Time__c = System.now();
                         update intCase;
                         log('[submitProcessCaseDecision] Integration case updated: ' + serviceCaseInfo.Id);
                     }

                     log('[submitProcessCaseDecision] Case status updated to: ' + caseStatus);
                 } catch (Exception statusEx) {
                     log('[submitProcessCaseDecision] Failed to update case status: ' + statusEx.getMessage());
                 }
             }

            return response;

            } else {
                response.success =  false;
                response.responseCode = 0;                
                response.message = ERR_MISS_FRAUD_CASE;
                return response; 
            }
            
           
 
        } catch (Exception ex) {
            log('ERROR IN submitProcessFraudCase: ' + ex.getMessage());
            response.success = false;
            response.responseCode = 0;
            response.message = ex.getMessage();
            return response;
        }
    }

    private static FEC_IntegrationFraudCaseUtil.FraudCaseResponse 
    handleProcessCaseResponse(
        FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType apiRes,
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w,
        FEC_IntegrationSoapFraudcaseService.SysType sys,
        FEC_IntegrationSoapFraudcaseService.CaseInfoType4 req,
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator
    ) {

        // Initialize result wrapper returned to caller
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result =
            new FEC_IntegrationFraudCaseUtil.FraudCaseResponse();

        Integer responseCode = 0;
        String responseDescription = '';

        // Extract response code and description from API response
        if (apiRes != null && apiRes.Sys != null) {

            // Validate numeric response code
            if (String.isNotBlank(apiRes.Sys.Code) &&
                apiRes.Sys.Code.trim().isNumeric()) {

                responseCode = Integer.valueOf(apiRes.Sys.Code.trim());
            }

            responseDescription = apiRes.Sys.Description;
        }
        // Success condition:
        // - External system returned success code (1)
        // - Fraud Case ID is present
        if (responseCode == 1) {

            // Upsert fraud case service record locally
            Boolean isUpsert = true;
            result.success = isUpsert;
            result.responseCode = isUpsert ? 1 : 0;
            result.message = isUpsert ? MSG_UPDATE_SUCCESS : MSG_UPDATE_FAILED;
            result.fraudCaseId = w.caseId;

        } else {

            // Failure flow
            result.success = false;
            result.responseCode = 0;
            result.message = responseDescription;
        }

        return result;
    }

    public static List<FEC_IntegrationFraudCaseUtil.RemarksInfo> getRemarksData(String caseId) {
        List<FEC_IntegrationFraudCaseUtil.RemarksInfo> remarks = new List<FEC_IntegrationFraudCaseUtil.RemarksInfo>();

        for (FEC_Case_Remarks__c rec : [
            SELECT Id, FEC_Case_Remarks__c, FEC_Stage_Name__c,
                   FEC_User__c, FEC_User_Role__c, CreatedDate,
                   CreatedBy.Email, CreatedBy.Name, CreatedBy.UserRole.Name
            FROM FEC_Case_Remarks__c
            WHERE FEC_Case__c = :caseId
            ORDER BY CreatedDate DESC
        ]) {
            FEC_IntegrationFraudCaseUtil.RemarksInfo remark = new FEC_IntegrationFraudCaseUtil.RemarksInfo();
            remark.id = rec.Id;
            remark.actor = (rec.CreatedBy != null && rec.CreatedBy.UserRole != null)
                ? rec.CreatedBy.UserRole.Name
                : rec.FEC_User_Role__c;
            remark.remarks = rec.FEC_Case_Remarks__c;
            remark.decision = rec.FEC_Stage_Name__c;
            remark.processingStatus = '';
            remark.createdBy = rec.CreatedBy != null ? rec.CreatedBy.Email : rec.FEC_User__c;
            remark.createdDate = rec.CreatedDate != null
                ? FEC_IntegrationFraudCaseUtil.formatDateTime(rec.CreatedDate)
                : null;
            remarks.add(remark);
        }

        return remarks;
    }
    public static FEC_IntegrationFraudCaseUtil.CustomerInfo getCustomerData(String caseId) {
        FEC_IntegrationFraudCaseUtil.CustomerInfo cust = new FEC_IntegrationFraudCaseUtil.CustomerInfo();

        if (String.isBlank(caseId)) return cust;

        List<Case> cases = [
            SELECT Id,
                   FEC_Phone_Number__c,
                   FEC_National_ID_Passport_ID__c,
                   FEC_Contract_Number__c,
                   FEC_Account_Number__c,
                   FEC_Application_ID__c,
                   FEC_Product_Type__r.Name,
                   FEC_Account_or_Contract__r.FEC_Customer_Name__c,
                   FEC_Account_or_Contract__r.FEC_Account_Number__c,
                   FEC_Account_or_Contract__r.FEC_Contract_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (!cases.isEmpty()) {
            Case c = cases[0];
            cust.customerName = c.FEC_Account_or_Contract__r != null
                ? c.FEC_Account_or_Contract__r.FEC_Customer_Name__c
                : null;
            cust.contractNumber = c.FEC_Contract_Number__c != null
                ? c.FEC_Contract_Number__c
                : (c.FEC_Account_or_Contract__r != null ? c.FEC_Account_or_Contract__r.FEC_Contract_Number__c : null);
            cust.nationalId = c.FEC_National_ID_Passport_ID__c;
            cust.primaryPhone = c.FEC_Phone_Number__c;
            cust.applicationId = c.FEC_Application_ID__c;
            cust.accountNumber = c.FEC_Account_Number__c != null
                ? c.FEC_Account_Number__c
                : (c.FEC_Account_or_Contract__r != null ? c.FEC_Account_or_Contract__r.FEC_Account_Number__c : null);
            cust.productType = c.FEC_Product_Type__r != null ? c.FEC_Product_Type__r.Name : null;
        }

        return cust;
    }
    private static FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO initBaseDTO(String caseId) {

        FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto =
            new FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO();
        dto.fraud = new FEC_IntegrationFraudCaseUtil.FraudInfo();
        dto.task = new FEC_IntegrationFraudCaseUtil.TaskInfo();
        dto.caseInfo = new FEC_IntegrationFraudCaseUtil.CaseInfo();
        dto.remarksInfo = getRemarksData(caseId);
        dto.notificationInfo = getNotificationData(caseId);
        dto.serviceCasesInfo = new List<FEC_IntegrationFraudCaseUtil.ServiceCasesInfo>();
        dto.fraudCasesList = new List<FEC_IntegrationFraudCaseUtil.FraudInfo>();
    
        return dto;
    }

    private static FEC_Integration_Case__c getServiceCase(String caseId) {

        List<FEC_Integration_Case__c> records = [
            SELECT Id,
            FEC_Service_Case_ID__c,
            FEC_CaseID__c,
            FEC_Case_Status__c,
            FEC_Case_Type__c,
            FEC_Remark__c,
            FEC_Sys_Creator_Email__c,
            FEC_Sys_Channel__c,
            FEC_Updated_Time__c, 
            FEC_Category__c,
            FEC_Sub_Category__c,
            FEC_Sub_Code__c,
            FEC_Creator_Email__c,
            FEC_Investigation_Conclusion__c,
            FEC_CS_Remark__c,
            CreatedDate,
            FEC_Parent_CaseID__c 
            FROM FEC_Integration_Case__c 
            WHERE FEC_Integrate_Case_ID__c = :caseId            
            LIMIT 1
        ];
    
        return records.isEmpty() ? null : records[0];
    }

    private static FEC_IntegrationFraudCaseUtil.CaseInfo getCaseInfoData(FEC_Integration_Case__c  intCase) {
        FEC_IntegrationFraudCaseUtil.CaseInfo caseInfo = new FEC_IntegrationFraudCaseUtil.CaseInfo();

        if (intCase != null) {
            caseInfo.caseStatus = intCase.FEC_Case_Status__c;
            caseInfo.caseChannel = intCase.FEC_Sys_Channel__c;
            caseInfo.createdBy = intCase.FEC_Creator_Email__c != null
                ? intCase.FEC_Creator_Email__c
                : intCase.FEC_Sys_Creator_Email__c;
            caseInfo.createdDate = intCase.CreatedDate != null
                ? FEC_IntegrationFraudCaseUtil.formatDateTime(intCase.CreatedDate)
                : null;
            caseInfo.lastUpdateDate = intCase.FEC_Updated_Time__c != null
                ? FEC_IntegrationFraudCaseUtil.formatDateTime(intCase.FEC_Updated_Time__c)
                : null;
            caseInfo.lastUpdateBy = intCase.FEC_Sys_Creator_Email__c;
        } else {
            caseInfo.caseStatus = FEC_FraudConstantCommon.CASE_STATUS_PENDING_FRAUD_TASK;
            caseInfo.caseChannel = FEC_FraudConstantCommon.DEFAULT_CHANNEL_INTEGRATION_CODE;
        }

        return caseInfo;
    }

    private static void populateCaseAndTask(
    FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto,
    FEC_Integration_Case__c serviceCase,
    String caseId
    ) {

        dto.caseInfo = getCaseInfoData(serviceCase);
        dto.caseInfo.caseId = caseId;
        String deadline;
        String uicString = '';
        String taskName = '';
        String taskType = '';
        String taskConclusion = serviceCase.FEC_Investigation_Conclusion__c;
        String resultDetailCode = '';
        String applicationId = '';
        for (FEC_Integration_Case_Info__c info : [
            SELECT Id, FEC_Info_ID__c, FEC_Info_Value__c
            FROM FEC_Integration_Case_Info__c
            WHERE FEC_Parent_Case__c = :serviceCase.Id
        ]) {
        
            if (info.FEC_Info_ID__c == FEC_FraudConstantCommon.KEY_DEADLINE) {                    
                if (String.isNotBlank(info.FEC_Info_Value__c) && info.FEC_Info_Value__c.length() == 8) {
                    deadline =
                    info.FEC_Info_Value__c.substring(6, 8) + '/' +
                    info.FEC_Info_Value__c.substring(4, 6) + '/' +
                    info.FEC_Info_Value__c.substring(0, 4);
                }
            }
            else if (info.FEC_Info_ID__c == FEC_FraudConstantCommon.INFO_UIC) {
                uicString = info.FEC_Info_Value__c;
            }
            else if (info.FEC_Info_ID__c == FEC_FraudConstantCommon.TASK_NAME) {
                taskName = info.FEC_Info_Value__c;
            }
            else if (info.FEC_Info_ID__c == FEC_FraudConstantCommon.INFO_VIOLATIONTYPE) {
                taskType = info.FEC_Info_Value__c;
            }
            else if (info.FEC_Info_ID__c == FEC_FraudConstantCommon.INFO_RESULT_DETAIL_CODE) {
                resultDetailCode = info.FEC_Info_Value__c;
            }
            else if (info.FEC_Info_ID__c == FEC_FraudConstantCommon.INFO_APPLICATION_ID) {
                applicationId = info.FEC_Info_Value__c;
            }
        }
        dto.task.taskId = serviceCase.FEC_CaseID__c;
        dto.task.taskStatus = serviceCase.FEC_Case_Status__c;
        dto.task.urgency = '';
        dto.task.deadline = deadline;
        dto.task.createdDate = FEC_IntegrationFraudCaseUtil.formatDateTime(serviceCase.CreatedDate);
        dto.task.taskUIC = uicString;
        dto.task.taskName = taskName;
        dto.task.taskType = taskType;
        dto.task.applicationId = applicationId;
        dto.task.taskConclusion = taskConclusion;       
    }

    private static void populateFraudHierarchy(
    FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto,
    FEC_Integration_Case__c serviceCase
    ) {

        if (String.isBlank(serviceCase.FEC_Parent_CaseID__c)) {
            return;
        }

        FEC_Integration_Case__c buCase = getBUCase(serviceCase.FEC_Parent_CaseID__c);
        if (buCase == null) return;

        FEC_Integration_Case__c fhCase = getFHCase(buCase.FEC_Parent_CaseID__c);
        if (fhCase == null) return;

        populateFraudInfo(dto, fhCase);
        populateServiceCaseInfo(dto, fhCase);
        populateFraudCaseList(dto, fhCase.FEC_Service_Case_ID__c);
    }

    private static void populateFraudInfo(
    FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto,
    FEC_Integration_Case__c fhCase
    ) {
        dto.fraud.fraudCaseId = fhCase.FEC_CaseID__c;
        dto.fraud.fraudCategory = fhCase.FEC_Category__c;
        dto.fraud.fraudSubCategory = fhCase.FEC_Sub_Category__c;
        dto.fraud.createdDate = FEC_IntegrationFraudCaseUtil.formatDateTime(fhCase.CreatedDate);        
        dto.fraud.owner = fhCase.FEC_Creator_Email__c;
        dto.fraud.referenceId = fhCase.FEC_Service_Case_ID__c;
        dto.fraud.csOwner = fhCase.FEC_Creator_Email__c;
        dto.fraud.remarks = fhCase.FEC_CS_Remark__c;
        dto.fraud.subCode = fhCase.FEC_Sub_Code__c;
        dto.fraud.caseStatus = fhCase.FEC_Case_Status__c;
        dto.fraud.updateTime = FEC_IntegrationFraudCaseUtil.formatDateTime(fhCase.FEC_Updated_Time__c);

    }

    private static FEC_Integration_Case__c getBUCase(String buCaseId) {

        if (String.isBlank(buCaseId)) {
            return null;
        }
    
        List<FEC_Integration_Case__c> records = [
            SELECT Id, FEC_Parent_CaseID__c
            FROM FEC_Integration_Case__c
            WHERE FEC_CaseID__c = :buCaseId
            LIMIT 1
        ];
    
        return records.isEmpty() ? null : records[0];
    }

    private static FEC_Integration_Case__c getFHCase(String fhCaseId) {

        if (String.isBlank(fhCaseId)) {
            return null;
        }
    
        List<FEC_Integration_Case__c> records = [
            SELECT Id, 
            CreatedDate,
            FEC_Case_Status__c,
            FEC_Category__c, 
            FEC_Sub_Category__c, 
            FEC_Sub_Code__c, 
            FEC_Product_Type__c, 
            FEC_Created_Time__c,
            FEC_Creator_Email__c,
            FEC_Investigation_Conclusion__c,
            FEC_Remark__c,
            FEC_CS_Remark__c,
            FEC_Sys_Channel__c,
            FEC_Updated_Time__c,
            FEC_Service_Case_ID__c,
            FEC_Case_Type__c,
            FEC_CaseID__c
            FROM FEC_Integration_Case__c
            WHERE FEC_CaseID__c = :fhCaseId                   
            LIMIT 1
        ];
    
        return records.isEmpty() ? null : records[0];
    }

    private static void populateServiceCaseInfo(
    FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto,
    FEC_Integration_Case__c fhCase
    ) {

        String serviceCaseId = fhCase.FEC_Service_Case_ID__c;

        if (String.isBlank(serviceCaseId)) {
            return;
        }

        List<Case> cases = [
            SELECT Id, CaseNumber, Status, Type,
                   CreatedDate, CreatedBy.Email,
                   ClosedDate, FEC_Interaction_Resolved_By__r.Email
            FROM Case
            WHERE FEC_ID_Search__c = :serviceCaseId
            LIMIT 1
        ];

        if (cases.isEmpty()) {
            return;
        }

        Case c = cases[0];
        FEC_IntegrationFraudCaseUtil.ServiceCasesInfo info =
            new FEC_IntegrationFraudCaseUtil.ServiceCasesInfo();

        info.caseId = c.CaseNumber;
        info.serviceCaseId = serviceCaseId;
        info.caseType = c.Type;
        info.caseStatus = c.Status;
        info.createdBy = c.CreatedBy != null ? c.CreatedBy.Email : '';
        info.resolvedBy = c.FEC_Interaction_Resolved_By__r != null ? c.FEC_Interaction_Resolved_By__r.Email : '';
        info.createdOn = FEC_IntegrationFraudCaseUtil.formatDateTime(c.CreatedDate);
        info.resolvedOn = c.ClosedDate != null ? FEC_IntegrationFraudCaseUtil.formatDateTime(c.ClosedDate) : '';

        dto.serviceCasesInfo.add(info);
    }
     private static List<FEC_IntegrationFraudCaseUtil.NotificationInfo> getNotificationData(String caseId) {
        List<FEC_IntegrationFraudCaseUtil.NotificationInfo> results = new List<FEC_IntegrationFraudCaseUtil.NotificationInfo>();

        if (String.isBlank(caseId)) {
            return results;
        }

        List<FEC_Notification_History__c> records = [
            SELECT Id,
                   FEC_Notification_Type__c,
                   FEC_Notification_Template__c,
                   FEC_Notification_Channel__c,
                   FEC_Send_User__r.Email,
                   FEC_Send_Status__c,
                   FEC_Send_Date_Time__c,
                   FEC_Date_Time__c
            FROM FEC_Notification_History__c
            WHERE FEC_Related_Case_ID__c = :caseId
            ORDER BY FEC_Send_Date_Time__c DESC
        ];

        for (FEC_Notification_History__c rec : records) {
            FEC_IntegrationFraudCaseUtil.NotificationInfo info = new FEC_IntegrationFraudCaseUtil.NotificationInfo();
            info.id = rec.Id;
            info.notificationType = rec.FEC_Notification_Type__c;
            info.templateName = rec.FEC_Notification_Template__c;
            info.channel = rec.FEC_Notification_Channel__c;
            info.recipient = rec.FEC_Send_User__r != null ? rec.FEC_Send_User__r.Email : '';
            info.status = rec.FEC_Send_Status__c;
            info.sentTime = rec.FEC_Send_Date_Time__c != null ? FEC_IntegrationFraudCaseUtil.formatDateTime(rec.FEC_Send_Date_Time__c) : '';
            info.actualDeliveryTime = rec.FEC_Date_Time__c != null ? FEC_IntegrationFraudCaseUtil.formatDateTime(rec.FEC_Date_Time__c) : '';
            results.add(info);
        }

        return results;
    }

    private static void populateFraudCaseList(
    FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto,
    String serviceCaseId
    ) {

        if (String.isBlank(serviceCaseId)) {
            return;
        }

        List<FEC_Integration_Case__c> records = [
            SELECT Id,
                CreatedDate,
                FEC_CaseID__c,
                FEC_Case_Status__c,
                FEC_Category__c,
                FEC_Sub_Category__c,
                FEC_Sub_Code__c,
                FEC_Creator_Email__c,
                FEC_Remark__c,
                FEC_Updated_Time__c
            FROM FEC_Integration_Case__c
            WHERE FEC_Service_Case_ID__c = :serviceCaseId
        ];

        for (FEC_Integration_Case__c rec : records) {

            FEC_IntegrationFraudCaseUtil.FraudInfo fraud =
                new FEC_IntegrationFraudCaseUtil.FraudInfo();

            fraud.fraudCaseId = rec.FEC_CaseID__c;
            fraud.fraudCategory = rec.FEC_Category__c;
            fraud.fraudSubCategory = rec.FEC_Sub_Category__c;
            fraud.createdDate =
                FEC_IntegrationFraudCaseUtil.formatDateTime(rec.CreatedDate);
            fraud.owner = rec.FEC_Creator_Email__c;
            fraud.referenceId = serviceCaseId;
            fraud.remarks = rec.FEC_Remark__c;
            fraud.subCode = rec.FEC_Sub_Code__c;
            fraud.caseStatus = rec.FEC_Case_Status__c;
            fraud.updateTime =
                FEC_IntegrationFraudCaseUtil.formatDateTime(rec.FEC_Updated_Time__c);

            dto.fraudCasesList.add(fraud);
        }
    }

     /**
     * Writes a log message to the debug log if debugging is enabled.
     *
     * This method centralizes logging behavior and ensures that debug
     * messages are only printed when the DEBUG_LOG flag is set to true.
     * It helps control log noise and improves performance in production
     * environments by avoiding unnecessary debug statements.
     *
     * @param msg The message to be written to the debug log.
     */
    @AuraEnabled
    public static void assignCaseToMe(String caseId) {
        if (String.isBlank(caseId)) return;
        Case c = new Case(Id = caseId, OwnerId = UserInfo.getUserId());
        update c;
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_Decison_Reason__c> getCancelReasons() {
        return [
            SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c
            FROM FEC_Decison_Reason__c
            WHERE FEC_Status__c = true
            ORDER BY Name ASC
        ];
    }

    private static void log(String msg) {
        if (DEBUG_LOG) {
            System.debug(LoggingLevel.INFO, msg);
        }
    }
 
    /**
    * Writes integration log for Fraud Case service execution.
    *
    * This method is a safe wrapper around the main integration logger.
    * It ensures that any logging failure will NOT break the main business flow.
    *
    * @param serviceName     Name of the integration service (e.g. "CreateFraudCase")
    * @param channelId       Channel / source system identifier
    * @param caseId          Case ID returned from external system (FH Case)
    * @param serviceCaseId   Internal generated service case ID
    * @param requestBody     Serialized request payload sent to the service
    * @param responseXml     Serialized response payload received from the service
    */
    private static void writeLogIntegrationService(
        String serviceName,
        String channelId,
        String caseId,
        String serviceCaseId,
        String requestBody,
        String responseXml,
        String messageStatus,
        String requestor,
        String description
    ) {
        try {
            // Call centralized logging utility
            FEC_IntegrationFraudCaseUtil.logIntegrationService(
                serviceName,
                channelId,
                caseId,
                serviceCaseId,
                requestBody,
                responseXml,
                messageStatus,
                requestor,
                description
            );
 
            // Log success for debugging & monitoring
            log('SUCCESS - writeLogIntegrationService');
 
        } catch (Exception ex) {
            // Never allow logging errors to interrupt main transaction
            log('ERROR - writeLogIntegrationService: ' + ex.getMessage());
        }
    } 
    


}