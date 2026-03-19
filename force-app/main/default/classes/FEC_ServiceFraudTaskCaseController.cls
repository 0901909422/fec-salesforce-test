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
    
        FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto = initBaseDTO();
    
        FEC_Integration_Case__c serviceCase = getServiceCase(caseId);
        if (serviceCase == null) {
            return dto;
        }
    
        populateCaseAndTask(dto, serviceCase, caseId);
        populateFraudHierarchy(dto, serviceCase);
    
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

            
 
             // 3. Call SOAP service
             FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType apiRes =
             FEC_IntegrationFraudService.callProcessFraudCaseService(reqWrapper, sys, caseInfo, creator);
             log('LOG-callProcessFraudCaseService: '+ apiRes);
             // 4. Handle response
             response = handleProcessCaseResponse(apiRes, reqWrapper, sys, caseInfo, creator);
             log('LOG-handleProcessCaseResponse: '+ response);          
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
    private static FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO initBaseDTO() {

        FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto =
            new FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO();
    
        dto.customer = FEC_FraudCaseMockData.getCustomerMockData();
        dto.fraud = new FEC_IntegrationFraudCaseUtil.FraudInfo();
        dto.task = new FEC_IntegrationFraudCaseUtil.TaskInfo();
        dto.caseInfo = new FEC_IntegrationFraudCaseUtil.CaseInfo();
        dto.remarksInfo = new List<FEC_IntegrationFraudCaseUtil.RemarksInfo>{
            FEC_FraudCaseMockData.getRemarksMockData()
        };
        dto.notificationInfo = new List<FEC_IntegrationFraudCaseUtil.NotificationInfo>{
            FEC_FraudCaseMockData.getNotificationMockData()
        };
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
            WHERE FEC_Service_Case_ID__c = :caseId            
            LIMIT 1
        ];
    
        return records.isEmpty() ? null : records[0];
    }

    private static void populateCaseAndTask(
    FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto,
    FEC_Integration_Case__c serviceCase,
    String caseId
    ) {

        dto.caseInfo = FEC_FraudCaseMockData.getCaseInfoMockData();
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
        dto.fraud.remarks = fhCase.FEC_Remark__c;
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

        FEC_IntegrationFraudCaseUtil.ServiceCasesInfo info =
            FEC_FraudCaseMockData.getServiceCasesInfoMockData();

        info.serviceCaseId = serviceCaseId;

        dto.serviceCasesInfo.add(info);
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