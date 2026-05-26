@RestResource(urlMapping='/fec/*')
global with sharing class FEC_IntegrationFraudCaseApi {
    public static final Boolean DEBUG_LOG = true;    
    public static final String userLang = UserInfo.getLanguage();
    public static String REQUESTOR_DATA = null;
    // Error messages (from Custom Labels)  
    public static final String MSG_MISSING_DETAIL =
    System.Label.LBL_API_Missing_Detail;
    public static final String MSG_CASEID_REQUIRED =
    System.Label.LBL_API_CaseId_Required;
    public static final String MSG_MISSING_XML =
    System.Label.LBL_API_Missing_XML;
    public static final String MSG_INVALID_CASE_FORMAT =
    System.Label.LBL_API_Invalid_Case_Format;
    public static final String MSG_FRAUD_UPDATE_SUCCESS =
    System.Label.LBL_API_Invalid_Fraud_Case_Update_Success;
    public static final String MSG_INVALID_FRAUD_NOT_FOUND =
    System.Label.LBL_API_Invalid_Fraud_Case_Not_Found;

    public static final String MSG_INVALID_CASE_EXISTING =
    System.Label.LBL_API_Invalid_Service_Case_Existing;
    public static final String MSG_INVALID_CASE_CUSTOMER_INFO =
    System.Label.LBL_API_Invalid_Case_Customer_Info;
    public static final String MSG_INVALID_CASE_CREATOR_INFO =
    System.Label.LBL_API_Invalid_Case_Creator_Info;
    public static final String MSG_INVALID_CASE_REQUEST_INFO =
    System.Label.LBL_API_Invalid_Case_Request_Info;
    public static final String MSG_INVALID_CASE_RESULT_INFO =
    System.Label.LBL_API_Invalid_Case_Result_Info;
    public static final String MSG_INVALID_PARENT_CASE =
    System.Label.LBL_API_Invalid_Fraud_Case_Not_Found_Parent;
    public static final String MSG_INVALID_CASE_ORIGINAL_REQUEST =
    System.Label.LBL_API_Invalid_Fraud_Case_Original_Request;
    
    
    
   

    

    /**
     * Entry point for updating fraud case status from external systems.
     *
     * This method:
     *  1. Reads and parses the incoming REST request body (XML + extracted data)
     *  2. Validates mandatory business fields
     *  3. Determines fraud case type (FH / BU / TK)
     *  4. Routes processing to the appropriate handler
     *  5. Returns standardized XML success or error response
     *
     * @return XML response string indicating success or failure
     */
    @HttpPost
    global static String UpdateFraudCaseStatus() {

        Dom.Document responseDoc;
        String responseStr;
        FEC_FraudConstantCommon.IntegrationField caseField = new FEC_FraudConstantCommon.IntegrationField();
    
        String requestBody = RestContext.request.requestBody.toString();
        String serviceName = FEC_FraudConstantCommon.FRAUD_CASE_SERVICE_NAME;
    
        String caseId;
        String serviceCaseId;
        String channelId = '';
        String messageStatus = null;
        String requestor = null;
        String description = null;
        String xmlInput = null;
    
        try {
            FEC_IntegrationFraudCaseUtil.FraudExtractResult extractData =
                FEC_IntegrationFraudCaseUtil.extractFraudPayload(requestBody);
    
            Map<String, Object> detail = extractData.detail;
            String xmlData = extractData.xmlData;
    
            //Validate detail
            if (detail == null) {
                responseDoc =
                    FEC_IntegrationFraudCaseUtil.errorResponseXml(
                        MSG_MISSING_DETAIL,
                        FEC_FraudConstantCommon.CLIENT_ERROR
                    );
                return responseDoc.toXmlString();
            }
    
            // Extract fields
            caseId        = (String) detail.get(caseField.CASEID_FIELD);
            serviceCaseId = (String) detail.get(caseField.REFERENCE_FIELD);
            channelId     = (String) detail.get(caseField.CHANNEL_ID_FIELD);
    
            //Validate caseId
            if (String.isBlank(caseId)) {
                responseDoc =
                    FEC_IntegrationFraudCaseUtil.errorResponseXml(
                        MSG_CASEID_REQUIRED,
                        FEC_FraudConstantCommon.CLIENT_ERROR
                    );
                return responseDoc.toXmlString();
            }
    
            //Validate XML
            if (String.isBlank(xmlData)) {
                responseDoc =
                    FEC_IntegrationFraudCaseUtil.errorResponseXml(
                        MSG_MISSING_XML,
                        FEC_FraudConstantCommon.CLIENT_ERROR
                    );
                return responseDoc.toXmlString();
            }
    
            String normalized = caseId.trim().toUpperCase();
            xmlInput   =
                FEC_IntegrationFraudCaseUtil.normalizeXml(xmlData);
    
            //Route case
            if (normalized.startsWith(caseField.CASEFH)) {
                responseStr = processFHCase(detail, xmlInput);
    
            } else if (normalized.startsWith(caseField.CASEBU)) {
                responseStr = processBUCase(detail, xmlInput);
    
            } else if (normalized.startsWith(caseField.CASETK)) {
                responseStr = processTKCase(detail, xmlInput);
    
            } else {
                responseDoc =
                    FEC_IntegrationFraudCaseUtil.errorResponseXml(
                        MSG_INVALID_CASE_FORMAT,
                        FEC_FraudConstantCommon.NOT_FOUND
                    );
                responseStr = responseDoc.toXmlString();
            }
    
            return responseStr;
    
        } catch (Exception ex) {
            log('UpdateFraudCaseStatus - Exception: ' + ex.getMessage());
    
            responseDoc =
                FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    ex.getMessage(),
                    FEC_FraudConstantCommon.SERVER_ERROR
                );
            return responseDoc.toXmlString();
    
        } finally {
            try {
                FEC_IntegrationFraudCaseUtil.UpdateCaseResponse res = FEC_IntegrationFraudCaseUtil.extractCaseIdFromResponse(responseStr);
                if (String.isBlank(caseId) && responseStr != null) {                    
                    caseId = res.caseId;                    
                }
                messageStatus = res.caseMessage;
                description = res.caseCode;
                requestor = REQUESTOR_DATA;

    
                FEC_IntegrationFraudCaseUtil.logIntegrationService(
                    serviceName,
                    channelId,
                    caseId,
                    serviceCaseId,
                    requestBody,
                    responseStr,
                    messageStatus,
                    requestor,
                    description
                );
            } catch (Exception logEx) {
                log('Logging failed: ' + logEx.getMessage());
            }
        }
    }
    
   

    /**
     * Extracts and prepares request data from a raw integration payload.
     *
     * This method performs the following steps:
     * 1. Extracts the embedded XML content from the raw request string.
     * 2. Removes the XML portion from the JSON body to produce a clean JSON payload.
     * 3. Safely deserializes the cleaned JSON into an untyped Apex map.
     * 4. Retrieves the "detail" section of the request.
     * 5. Returns both the extracted XML and parsed JSON detail in a unified structure.
     *
     * @param raw The original raw request body containing both JSON and embedded XML.
     * @return A map containing:
     *         - 'detail' : Parsed request detail data as Map<String, Object>
     *         - 'xml'    : Extracted XML string content
     */
    private static Map<String,Object> extractRequestData(String raw) {
        // Extract XML string from "data": "....."
        String xmlData = FEC_IntegrationFraudCaseUtil.extractXml(raw);
        log('EXTRACTED XML:\n' + xmlData);

        // Clean JSON body by replacing XML with ""
        String jsonClean = FEC_IntegrationFraudCaseUtil.cleanJson(raw);
        log('CLEAN JSON FOR PARSING:\n' + jsonClean);

        // Now safe to deserialize
        Map<String,Object> wrapper =
            (Map<String,Object>) JSON.deserializeUntyped(jsonClean);

        Map<String,Object> detail =
            (Map<String,Object>) wrapper.get('detail');

        log('DETAIL MAP:\n' + JSON.serializePretty(detail));

        // Final combined return
        return new Map<String,Object>{
            'detail' => detail,
            'xml'    => xmlData
        };
    }

    
    /**
     * Processes a Fraud Handling (FH) case update request by combining JSON detail data
     * with XML payload information and synchronizing it into Salesforce.
     *
     * Processing flow:
     * 1. Parses the provided XML data and validates required nodes.
     * 2. Extracts case identifiers and status fields from the JSON detail map.
     * 3. Locates the existing parent fraud case record and updates its main fields.
     * 4. Converts and maps date/time values from both JSON and XML formats.
     * 5. Deletes existing child case info records linked to the parent case.
     * 6. Extracts all <AdditionalInfo> nodes from the XML payload and recreates
     *    corresponding child records.
     * 7. Returns a structured XML response indicating success or failure.
     *
     * @param detail  Parsed request detail data from the inbound integration message.
     * @param xmlData Extracted XML content associated with the fraud case.
     * @return XML response string indicating the processing result.
     */
    private static String processFHCase(Map<String,Object> detail, String xmlData) {
        String msg = null;
        FEC_FraudConstantCommon.IntegrationField caseField = new FEC_FraudConstantCommon.IntegrationField();
        FEC_FraudConstantCommon.IntegrationFieldType caseFileType = new FEC_FraudConstantCommon.IntegrationFieldType();
        try {
            // 2) Parse XML
            Dom.Document doc = new Dom.Document();            
            doc.load(xmlData);

            Dom.XmlNode root = doc.getRootElement();
            Dom.XmlNode caseNode = FEC_IntegrationFraudCaseUtil.find(root, caseField.CASE_RESULT_INFO);

            if (caseNode == null)
            {
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    MSG_INVALID_CASE_RESULT_INFO,
                    FEC_FraudConstantCommon.CLIENT_ERROR
                    ).toXmlString();                
            }                
            Dom.XmlNode originalRequestNode = FEC_IntegrationFraudCaseUtil.find(caseNode, caseField.ORIGINAL_REQUEST);
            Dom.XmlNode requestInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, caseField.REQUEST_INFO);
            if (requestInfoNode == null)
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    MSG_INVALID_CASE_REQUEST_INFO,
                    FEC_FraudConstantCommon.CLIENT_ERROR
                    ).toXmlString();
            
            Dom.XmlNode creatorInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, caseField.CREATOR_INFO);
            if (creatorInfoNode == null){
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    MSG_INVALID_CASE_CREATOR_INFO,
                    FEC_FraudConstantCommon.CLIENT_ERROR
                    ).toXmlString();
            }

            Dom.XmlNode customerInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, caseField.CUSTOMER_INFO);
            if (customerInfoNode == null) {
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    MSG_INVALID_CASE_CUSTOMER_INFO,
                    FEC_FraudConstantCommon.CLIENT_ERROR
                    ).toXmlString();
            }
        

            String caseStatus     = (String) detail.get(caseField.CASE_STATUS_FIELD);
            String parentId       = (String) detail.get(caseField.PARENT_ID_FIELD);
            String referenceId    = (String) detail.get(caseField.REFERENCE_FIELD);
            String caseId         = (String) detail.get(caseField.CASEID_FIELD);
            String channelID      = (String) detail.get(caseField.CHANNEL_ID_FIELD);
            //Check Service Case Existing
            if (parentId == null) {
                msg = String.format(
                    MSG_INVALID_CASE_EXISTING,
                    new List<String>{ caseId, referenceId, channelID }
                );
                log(msg);
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    msg,
                    FEC_FraudConstantCommon.CLIENT_ERROR
                    ).toXmlString();
            }
            Long messageTime = (Long) detail.get(caseField.MESSAGE_TIME);
            Datetime messageDateTime = null;
            if (messageTime != null) {
                Integer secondsInt = Integer.valueOf(messageTime / 1000);
                messageDateTime = Datetime.newInstance(1970, 1, 1, 0, 0, 0).addSeconds(secondsInt);
            }

            String investigationConclusion = (String) detail.get(caseField.INVESTIGATION_CONCLUSION_FIELD);   

            // Parse XML fields
            String xmlRemark      = FEC_IntegrationFraudCaseUtil.val(caseNode, caseField.REMARKS_FIELD);
            String xmlCreated     = FEC_IntegrationFraudCaseUtil.val(caseNode, caseField.CREATEDTIME_FIELD);
            String xmlUpdated     = FEC_IntegrationFraudCaseUtil.val(caseNode, caseField.UPDATEDTIME_FIELD);
            String xmlCreatorEmail      = FEC_IntegrationFraudCaseUtil.val(creatorInfoNode, caseField.CREATOR_EMAIL_FIELD);
            REQUESTOR_DATA = xmlCreatorEmail;

            log('XML Fields:\ninvestigationConclusion='+investigationConclusion+'\nCreated='+xmlCreated+'\nUpdated='+xmlUpdated);

            // 3) UPSERT parent
            FEC_Integration_Case__c rec;

            List<FEC_Integration_Case__c> exist = [
                SELECT Id 
                FROM FEC_Integration_Case__c 
                WHERE FEC_CaseID__c = :caseId 
                AND FEC_Service_Case_ID__c = :referenceId  
                AND FEC_Sys_Channel__c = :channelID
                LIMIT 1
            ];
            //Check Fraud Case Existing
            if (exist.isEmpty()) {
                msg = String.format(
                    MSG_INVALID_FRAUD_NOT_FOUND,
                    new List<String>{ caseId, referenceId, channelID }
                );
                log(msg);
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    msg,
                    FEC_FraudConstantCommon.CLIENT_ERROR
                    ).toXmlString();
            }


            rec = exist.isEmpty() ? new FEC_Integration_Case__c() : exist[0];

            rec.FEC_CaseID__c          = caseId;
            rec.FEC_Case_Status__c     = FEC_IntegrationFraudCaseUtil.mapCaseStatus(caseStatus);
            rec.FEC_Parent_CaseID__c   = parentId;
            rec.FEC_Service_Case_ID__c = referenceId;
            rec.FEC_Remark__c          = xmlRemark;
            rec.FEC_Sys_Channel__c = channelID;
            rec.FEC_Sys_Creator_Email__c = xmlCreatorEmail;

            rec.FEC_Created_Time__c = FEC_IntegrationFraudCaseUtil.parsePegaDatetime(xmlCreated);
            rec.FEC_Updated_Time__c = FEC_IntegrationFraudCaseUtil.parsePegaDatetime(xmlUpdated);
            rec.FEC_Message_Time__c = messageDateTime;
            rec.FEC_Investigation_Conclusion__c = investigationConclusion;

            upsert rec;

            //Update child info
            Map<String, FEC_Integration_Case_Info__c> existingInfoMap = new Map<String, FEC_Integration_Case_Info__c>();
            
            Map<String, FEC_Master_Data_Integration__c> sourceConfigMap = new Map<String, FEC_Master_Data_Integration__c>();

            for (FEC_Master_Data_Integration__c recMaster : [
                SELECT FEC_Source_Id__c, FEC_Source_Type__c, FEC_Source_Is_Mandatory__c,FEC_Source_Field_Type__c
                FROM FEC_Master_Data_Integration__c
                WHERE FEC_Channel__c = :channelID
            ]) {
                sourceConfigMap.put(recMaster.FEC_Source_Id__c, recMaster);
            }

            for (FEC_Integration_Case_Info__c info : [
                SELECT Id, FEC_Info_ID__c, FEC_Info_Value__c
                FROM FEC_Integration_Case_Info__c
                WHERE FEC_Parent_Case__c = :rec.Id
            ]) {
                existingInfoMap.put(info.FEC_Info_ID__c, info);
            }

            List<FEC_Integration_Case_Info__c> toInsert = new List<FEC_Integration_Case_Info__c>();
            List<FEC_Integration_Case_Info__c> toUpdate = new List<FEC_Integration_Case_Info__c>();

            List<Dom.XmlNode> additionalInfoNodes =
                FEC_IntegrationFraudCaseUtil.findAllDeep(root, caseField.ADDITIONAL_INFO);

            log('Found AdditionalInfo count = ' + additionalInfoNodes.size());

            for (Dom.XmlNode ai : additionalInfoNodes) {
                String idVal  = FEC_IntegrationFraudCaseUtil.val(ai, caseField.ID_FIELD);
                String valVal = FEC_IntegrationFraudCaseUtil.val(ai, caseField.VALUE_FIELD);  
                if (String.isBlank(idVal)) {
                    continue; // nothing to process
                }
                FEC_Master_Data_Integration__c config = sourceConfigMap.get(idVal);
                String fileType = config != null ? config.FEC_Source_Field_Type__c : null;
                Boolean sourceMandatory = config != null ? config.FEC_Source_Is_Mandatory__c : false;

                FEC_Integration_Case_Info__c existing = existingInfoMap.get(idVal);
                if (existing != null) {
                    // Update                    
                    Boolean isFile = (fileType != null && fileType.equalsIgnoreCase(caseFileType.TYPE_FILE));
            
                    if (!isFile && existing.FEC_Info_Value__c != valVal) {
                        existing.FEC_Info_Value__c = valVal;
                        toUpdate.add(existing);
                    }
            
                } else {
                    // Insert
                    toInsert.add(new FEC_Integration_Case_Info__c(
                        FEC_Parent_Case__c = rec.Id,
                        FEC_Info_ID__c     = idVal,
                        FEC_Info_Value__c  = valVal,
                        FEC_Property_Type__c = fileType,
                        FEC_Source_Is_Mandatory__c = sourceMandatory
                    ));
                }        

            }

            if (!toInsert.isEmpty()) {
                insert toInsert;
            }
            if (!toUpdate.isEmpty()) {
                update toUpdate;      
            }      
            log('Inserted: ' + toInsert.size() + ', Updated: ' + toUpdate.size());           
            return FEC_IntegrationFraudCaseUtil.successResponseXml(
                caseId, MSG_FRAUD_UPDATE_SUCCESS ).toXmlString();

        } catch (Exception ex) {
            return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                ex.getMessage(),
                FEC_FraudConstantCommon.CLIENT_ERROR
            ).toXmlString();
        }
        

    }

    
    /**
     * Processes a Business Unit (BU) fraud case update request by combining
     * structured JSON detail data with nested XML request information and
     * synchronizing the result into Salesforce.
     *
     * Processing flow:
     * 1. Parses the XML payload and validates required XML nodes.
     * 2. Extracts case identifiers, status, and message timestamps from the JSON detail map.
     * 3. Reads creator, customer, and request metadata from the XML structure.
     * 4. Locates or creates the corresponding parent fraud case record.
     * 5. Maps and converts all required fields and timestamps.
     * 6. Persists the updated fraud case data using an upsert operation.
     * 7. Returns a standardized XML response indicating success or failure.
     *
     * @param detail  Parsed request detail data from the inbound integration message.
     * @param xmlData Extracted XML content associated with the fraud case.
     * @return XML response string representing the processing outcome.
     */
    private static String processBUCase(Map<String,Object> detail, String xmlData) {
        log('Enter processBUCase');
        String msg = null;
        FEC_FraudConstantCommon.IntegrationField caseField = new FEC_FraudConstantCommon.IntegrationField();
        try {
            // 2) Parse XML
            Dom.Document doc = new Dom.Document();
            doc.load(xmlData);

            Dom.XmlNode root = doc.getRootElement();
            Dom.XmlNode caseNode = FEC_IntegrationFraudCaseUtil.find(root, caseField.CASE_RESULT_INFO);

            if (caseNode == null) {
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    MSG_INVALID_CASE_RESULT_INFO,
                    FEC_FraudConstantCommon.CLIENT_ERROR
                    ).toXmlString(); 
            }
                        
            Dom.XmlNode originalRequestNode = FEC_IntegrationFraudCaseUtil.find(caseNode, caseField.ORIGINAL_REQUEST);
            Dom.XmlNode requestInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, caseField.REQUEST_INFO);
            if (requestInfoNode == null) {
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    MSG_INVALID_CASE_REQUEST_INFO,
                    FEC_FraudConstantCommon.CLIENT_ERROR
                    ).toXmlString();
            }
        
            Dom.XmlNode creatorInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, caseField.CREATOR_INFO);
            if (creatorInfoNode == null) {
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    MSG_INVALID_CASE_CREATOR_INFO,
                    FEC_FraudConstantCommon.CLIENT_ERROR
                    ).toXmlString();
            }

            Dom.XmlNode customerInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, caseField.CUSTOMER_INFO);
            if (customerInfoNode == null) {
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    MSG_INVALID_CASE_CUSTOMER_INFO,
                    FEC_FraudConstantCommon.CLIENT_ERROR
                    ).toXmlString();
            }
            String caseStatus     = (String) detail.get(caseField.CASE_STATUS_FIELD);
            String parentId       = (String) detail.get(caseField.PARENT_ID_FIELD);
            String referenceId    = (String) detail.get(caseField.REFERENCE_FIELD);
            String caseId         = (String) detail.get(caseField.CASEID_FIELD);
            String channelID      = (String) detail.get(caseField.CHANNEL_ID_FIELD);
            Long messageTime = (Long) detail.get(caseField.MESSAGE_TIME);
            Datetime messageDateTime = null;

            List<FEC_Integration_Case__c> existParent = [
                SELECT Id 
                FROM FEC_Integration_Case__c 
                WHERE FEC_CaseID__c = :parentId                 
                AND FEC_Sys_Channel__c = :channelID
                LIMIT 1
            ];
            //Check Parent Case Existing
            if (existParent.isEmpty()) {               
                msg = String.format(
                    MSG_INVALID_PARENT_CASE,
                    new List<String>{ parentId, channelID }
                );
                log(msg);
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    msg,
                    FEC_FraudConstantCommon.NOT_FOUND
                    ).toXmlString();
            }
            if (messageTime != null) {
                Integer secondsInt = Integer.valueOf(messageTime / 1000);
                messageDateTime = Datetime.newInstance(1970, 1, 1, 0, 0, 0).addSeconds(secondsInt);
            }

            String investigationConclusion = (String) detail.get(caseField.INVESTIGATION_CONCLUSION_FIELD);   

            // Parse XML fields
            String xmlCreatorEmail      = FEC_IntegrationFraudCaseUtil.val(creatorInfoNode, caseField.CREATOR_EMAIL_FIELD);
            String xmlUserType      = FEC_IntegrationFraudCaseUtil.val(customerInfoNode, caseField.USER_TYPE_FIELD);
          
            String xmlRemark      = FEC_IntegrationFraudCaseUtil.val(requestInfoNode, caseField.REMARKS_FIELD);


            String xmlCreated     = FEC_IntegrationFraudCaseUtil.val(caseNode, caseField.CREATEDTIME_FIELD);
            String xmlUpdated     = FEC_IntegrationFraudCaseUtil.val(caseNode, caseField.UPDATEDTIME_FIELD);
            REQUESTOR_DATA = xmlCreatorEmail;
            log('XML Fields:\nRemark='+xmlRemark+'\nCreated='+xmlCreated+'\nUpdated='+xmlUpdated);
            
             

            // 3) UPSERT parent
            FEC_Integration_Case__c rec;

            List<FEC_Integration_Case__c> exist = [
                SELECT Id FROM FEC_Integration_Case__c WHERE FEC_CaseID__c = :caseId LIMIT 1
            ];

            rec = exist.isEmpty() ? new FEC_Integration_Case__c() : exist[0];

            rec.FEC_CaseID__c          = caseId;
            rec.FEC_Case_Status__c     = FEC_IntegrationFraudCaseUtil.mapCaseStatus(caseStatus);
            rec.FEC_Parent_CaseID__c   = parentId;
            rec.FEC_Service_Case_ID__c = referenceId;
            rec.FEC_Remark__c          = xmlRemark;
            rec.FEC_Sys_Creator_Email__c   = xmlCreatorEmail;
            rec.FEC_Case_Type__c       = xmlUserType;
            rec.FEC_Sys_Channel__c = channelID;

            rec.FEC_Created_Time__c = FEC_IntegrationFraudCaseUtil.parsePegaDatetime(xmlCreated);
            rec.FEC_Updated_Time__c = FEC_IntegrationFraudCaseUtil.parsePegaDatetime(xmlUpdated);
            rec.FEC_Message_Time__c = messageDateTime;
            rec.FEC_Investigation_Conclusion__c = investigationConclusion;
            upsert rec;
           
            return FEC_IntegrationFraudCaseUtil.successResponseXml(
                caseId, MSG_FRAUD_UPDATE_SUCCESS ).toXmlString();
        } catch (Exception ex) {
            return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                ex.getMessage(),
                FEC_FraudConstantCommon.CLIENT_ERROR
            ).toXmlString();
        }        
       
    }

    /**
     * Processes a TK fraud case update request by combining structured JSON detail data
     * with a complex XML payload and synchronizing the results into Salesforce.
     *
     * Processing flow:
     * 1. Parses the XML payload and validates all required XML nodes.
     * 2. Extracts case identifiers, status, channel, and message timestamp from the JSON detail map.
     * 3. Reads creator, customer, and request metadata from the XML structure.
     * 4. Locates or creates the corresponding parent fraud case record and preserves
     *    existing service case linkage when present.
     * 5. Maps and converts all required fields and timestamps.
     * 6. Deletes existing child case info records and recreates them from all
     *    <AdditionalInfo> nodes in the XML payload.
     * 7. Detects special SFT cases based on business rules (UIC = CS) and triggers
     *    additional SFT processing when applicable.
     * 8. Persists all changes and returns a standardized XML response.
     *
     * @param detail  Parsed request detail data from the inbound integration message.
     * @param xmlData Extracted XML content associated with the fraud case.
     * @return XML response string representing the processing outcome.
     */    
    
    private static String processTKCase(Map<String,Object> detail, String xmlData) {
        log('Enter processTKCase');
        String msg = null;
        FEC_FraudConstantCommon.IntegrationField caseField = new FEC_FraudConstantCommon.IntegrationField();
        try {
            Boolean isUicCS = false;
            Boolean isResultDetailCode = false;
    
            // =======================
            // 1. Parse XML
            // =======================
            Dom.Document doc = new Dom.Document();
            doc.load(xmlData);
            Dom.XmlNode root = doc.getRootElement();
    
            Dom.XmlNode caseNode = FEC_IntegrationFraudCaseUtil.find(root, caseField.CASE_RESULT_INFO);
            if (caseNode == null) {
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    MSG_INVALID_CASE_RESULT_INFO,
                    FEC_FraudConstantCommon.CLIENT_ERROR
                    ).toXmlString();
            }
    
            Dom.XmlNode originalRequestNode = FEC_IntegrationFraudCaseUtil.find(caseNode, caseField.ORIGINAL_REQUEST);
            if (originalRequestNode == null) {
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    MSG_INVALID_CASE_ORIGINAL_REQUEST,
                    FEC_FraudConstantCommon.CLIENT_ERROR).toXmlString();
            }
            Dom.XmlNode requestInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, caseField.REQUEST_INFO);
            if (requestInfoNode == null) {
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    MSG_INVALID_CASE_REQUEST_INFO,
                    FEC_FraudConstantCommon.CLIENT_ERROR
                    ).toXmlString();
            }
         
            Dom.XmlNode creatorInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, caseField.CREATOR_INFO);
            if (creatorInfoNode == null) {
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    MSG_INVALID_CASE_CREATOR_INFO,
                    FEC_FraudConstantCommon.CLIENT_ERROR
                    ).toXmlString();
            }         
            Dom.XmlNode customerInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, caseField.CUSTOMER_INFO);
            if (customerInfoNode == null) {
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    MSG_INVALID_CASE_CUSTOMER_INFO,
                    FEC_FraudConstantCommon.CLIENT_ERROR
                    ).toXmlString();
            }
            // =======================
            // 2. Load input data
            // =======================
          
            String investigationConclusion = (String) detail.get(caseField.INVESTIGATION_CONCLUSION_FIELD); 
            String caseStatus     = (String) detail.get(caseField.CASE_STATUS_FIELD);
            String parentId       = (String) detail.get(caseField.PARENT_ID_FIELD);
            String referenceId    = (String) detail.get(caseField.REFERENCE_FIELD);
            String caseId         = (String) detail.get(caseField.CASEID_FIELD);
            String channelID      = (String) detail.get(caseField.CHANNEL_ID_FIELD);
            Long messageTime = (Long) detail.get(caseField.MESSAGE_TIME);

    
            Datetime messageDateTime;
            if (messageTime != null && messageTime > 0) {
                messageDateTime = Datetime.newInstance(1970,1,1,0,0,0)
                    .addSeconds((Integer)(messageTime / 1000));
            }
    
            // =======================
            // 3. Validate parent
            // =======================
            List<FEC_Integration_Case__c> existParent = [
                SELECT Id, FEC_Parent_CaseID__c
                FROM FEC_Integration_Case__c
                WHERE FEC_CaseID__c = :parentId
                  AND FEC_Sys_Channel__c = :channelID
                LIMIT 1
            ];
    
            if (existParent.isEmpty()) {
                msg = String.format(
                    MSG_INVALID_PARENT_CASE,
                    new List<String>{ parentId, channelID }
                );
                log(msg);
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    msg,
                    FEC_FraudConstantCommon.NOT_FOUND
                    ).toXmlString();
            }
    
            String fraudCaseFH = existParent[0].FEC_Parent_CaseID__c;
            String fraudCaseFHId = null;
             List<FEC_Integration_Case__c> existFraudCase = [
                SELECT Id, 
                FEC_Category__c, 
                FEC_Sub_Category__c, 
                FEC_Sub_Code__c, 
                FEC_Product_Type__c, 
                FEC_Case_Type__c
                FROM FEC_Integration_Case__c
                WHERE FEC_CaseID__c = :fraudCaseFH
                AND FEC_Sys_Channel__c = :channelID
                LIMIT 1
            ];
    
            // =======================
            // 4. Parse XML values
            // =======================
            String xmlRemark      = FEC_IntegrationFraudCaseUtil.val(requestInfoNode, caseField.REMARKS_FIELD);
            String xmlCreated     = FEC_IntegrationFraudCaseUtil.val(caseNode, caseField.CREATEDTIME_FIELD);
            String xmlUpdated     = FEC_IntegrationFraudCaseUtil.val(caseNode, caseField.UPDATEDTIME_FIELD);
            String xmlCreatorEmail = FEC_IntegrationFraudCaseUtil.val(creatorInfoNode, caseField.CREATOR_EMAIL_FIELD);
            String xmlUserType     = FEC_IntegrationFraudCaseUtil.val(customerInfoNode, caseField.USER_TYPE_FIELD);
            REQUESTOR_DATA = xmlCreatorEmail;
            // =======================
            // 5. Upsert main record
            // =======================
            FEC_Integration_Case__c rec;
            List<FEC_Integration_Case__c> exist = 
            [ 
                SELECT Id,FEC_Service_Case_ID__c 
                FROM FEC_Integration_Case__c 
                WHERE FEC_CaseID__c = :caseId 
                AND FEC_Sys_Channel__c = :channelID
                LIMIT 1 
            ];
           
    
            Boolean isCreateSFTCase = true;
            rec = exist.isEmpty() ? new FEC_Integration_Case__c() : exist[0];
    
            if (!exist.isEmpty() && rec.FEC_Service_Case_ID__c != null)
            {
                isCreateSFTCase = false;
                rec.FEC_Service_Case_ID__c = exist[0].FEC_Service_Case_ID__c;
            }
            if(!existFraudCase.isEmpty()) 
            { 
                rec.FEC_Category__c = existFraudCase[0].FEC_Category__c; 
                rec.FEC_Sub_Category__c = existFraudCase[0].FEC_Sub_Category__c; 
                rec.FEC_Sub_Code__c = existFraudCase[0].FEC_Sub_Code__c; 
                fraudCaseFHId = existFraudCase[0].Id; 
            }
                
    
            rec.FEC_CaseID__c        = caseId;
            rec.FEC_Case_Status__c  = FEC_IntegrationFraudCaseUtil.mapCaseStatus(caseStatus);
            rec.FEC_Parent_CaseID__c= parentId;
            rec.FEC_Remark__c       = xmlRemark;
            rec.FEC_Creator_Email__c= xmlCreatorEmail;
            rec.FEC_Sys_Creator_Email__c= xmlCreatorEmail;
            rec.FEC_Case_Type__c    = xmlUserType;
            rec.FEC_Sys_Channel__c  = channelID;
            rec.FEC_Created_Time__c = FEC_IntegrationFraudCaseUtil.parsePegaDatetime(xmlCreated);
            rec.FEC_Updated_Time__c = FEC_IntegrationFraudCaseUtil.parsePegaDatetime(xmlUpdated);
            rec.FEC_Message_Time__c = messageDateTime;
            rec.FEC_Investigation_Conclusion__c = investigationConclusion;
    
            upsert rec;
    
            // =======================
            // 6. Child records
            // =======================
            Map<String,FEC_Integration_Case_Info__c> existingInfoMap = new Map<String,FEC_Integration_Case_Info__c>();
            for (FEC_Integration_Case_Info__c i : [
                SELECT Id, FEC_Info_ID__c, FEC_Info_Value__c
                FROM FEC_Integration_Case_Info__c
                WHERE FEC_Parent_Case__c = :rec.Id
            ]) {
                existingInfoMap.put(i.FEC_Info_ID__c, i);
            }
    
            List<FEC_Integration_Case_Info__c> toInsert = new List<FEC_Integration_Case_Info__c>();
            List<FEC_Integration_Case_Info__c> toUpdate = new List<FEC_Integration_Case_Info__c>();
            Set<String> processed = new Set<String>();
    
            for (Dom.XmlNode ai : FEC_IntegrationFraudCaseUtil.findAllDeep(root, caseField.ADDITIONAL_INFO)) {
    
                String idVal  = FEC_IntegrationFraudCaseUtil.val(ai, 'ID');
                String valVal = FEC_IntegrationFraudCaseUtil.val(ai, 'Value');
    
                if (String.isBlank(idVal) || processed.contains(idVal)) continue;
                processed.add(idVal);
    
                String idUpper  = idVal.toUpperCase();
                String valUpper = String.valueOf(valVal).toUpperCase();
    
                if (idUpper == caseField.UIC && valUpper == caseField.UIC_VALUE)
                {
                    isUicCS = true;
                }
                if (idUpper == caseField.RESULTDETAILCODE && valUpper == caseField.RESULTDETAILCODE_VALUE)
                {
                    isResultDetailCode = true;
                }
    
                if (existingInfoMap.containsKey(idVal)) {
                    FEC_Integration_Case_Info__c e = existingInfoMap.get(idVal);
                    if (e.FEC_Info_Value__c != valVal) {
                        e.FEC_Info_Value__c = valVal;
                        toUpdate.add(e);
                    }
                } else {
                    toInsert.add(new FEC_Integration_Case_Info__c(
                        FEC_Parent_Case__c = rec.Id,
                        FEC_Info_ID__c = idVal,
                        FEC_Info_Value__c = valVal
                    ));
                }
            }
    
            if (!toInsert.isEmpty()) {
                insert toInsert;
            }
            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }
    
            // =======================
            // 7. SFT Case
            // =======================
            log('[processTKCase] isCreateSFTCase=' + isCreateSFTCase 
                + ' | isUicCS=' + isUicCS 
                + ' | isResultDetailCode=' + isResultDetailCode);
            if (isCreateSFTCase && isUicCS && isResultDetailCode) {
                List<FEC_Integration_Case_Info__c> getFHCaseInfo = 
                [ 
                    SELECT Id,FEC_Info_ID__c, FEC_Parent_Case__c, FEC_Info_Value__c 
                    FROM FEC_Integration_Case_Info__c 
                    WHERE FEC_Parent_Case__c = :fraudCaseFHId                     
                ];
                processSFTCase(caseId, rec, getFHCaseInfo);
            }
            return FEC_IntegrationFraudCaseUtil.successResponseXml(
                caseId, MSG_FRAUD_UPDATE_SUCCESS ).toXmlString();
        }
        catch (Exception ex) {
            return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                ex.getMessage(),
                FEC_FraudConstantCommon.CLIENT_ERROR
            ).toXmlString();
        }
    }
    
    
    /**
     * Creates an SFT Interaction Case in Salesforce from Fraud Integration data.
     *
     * This method:
     *  1. Builds an InteractionCaseDTO from the parent integration record
     *  2. Calls the Interaction Case service to create the Case
     *  3. Stores the created Service Case Id back to the parent integration record
     *
     * @param caseId    External fraud case identifier
     * @param parentRec Parent integration case record
     * @param newInfos  Newly inserted integration info records
     * @return          Success or error XML response
     */
    private static String processSFTCase(
        String caseId,
        FEC_Integration_Case__c parentRec,
        List<FEC_Integration_Case_Info__c> newInfos
    ) {
        FEC_FraudConstantCommon.IntegrationField caseField = new FEC_FraudConstantCommon.IntegrationField();
        try {
            log('==================== processSFTCase START ====================');
            log('Input caseId        = ' + caseId);
            log('Parent record Id   = ' + parentRec.Id);
            log('Channel            = ' + parentRec.FEC_Sys_Channel__c);
            // 2. Create SFT Case (standard Case + FEC_Additional_Info__c)
            log('Creating SFT Case...');
             List<FEC_Category__c> sftCategories = [
                SELECT Id FROM FEC_Category__c
                WHERE FEC_Code__c = :FEC_FraudConstantCommon.SFT_CATEGORY_CODE
                LIMIT 1
            ];
            String sftCaseCategory = null;
            if (!sftCategories.isEmpty()) {
                sftCaseCategory = sftCategories[0].Id;
            }
            String sftCaseSubCategory = null;
            List<FEC_Sub_Category__c> sftSubCategories = [
                SELECT Id FROM FEC_Sub_Category__c
                WHERE FEC_Code__c = :FEC_FraudConstantCommon.SFT_SUB_CATEGORY_CODE
                LIMIT 1
            ];
            if (!sftSubCategories.isEmpty()) {
                sftCaseSubCategory = sftSubCategories[0].Id;
            }
           List<FEC_Sub_Code__c> sftSubCodes = [
                SELECT Id FROM FEC_Sub_Code__c
                WHERE FEC_Code__c = :FEC_FraudConstantCommon.SFT_SUB_CODE
                LIMIT 1
            ];
             String sftCaseSubCode = null;
            if (!sftSubCodes.isEmpty()) {
                sftCaseSubCode = sftSubCodes[0].Id;
            }
            Case sftCase = createSFTCase(
                parentRec.FEC_Service_Case_ID__c,
                parentRec.FEC_Sys_Channel__c,
                caseId,
                sftCaseCategory,
                sftCaseSubCategory,
                sftCaseSubCode
            );

            if (sftCase == null || sftCase.Id == null) {
                log('Failed to create SFT Case');
                return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                    'Failed to create SFT Case',
                    FEC_FraudConstantCommon.CLIENT_ERROR
                ).toXmlString();
            }

            String sftCaseId = sftCase.FEC_ID_Search__c;
            log('SFT Case created: Id=' + sftCase.Id + ', FEC_ID_Search__c=' + sftCaseId);

            // Update parent integration record with SFT Case Id
            if (String.isNotBlank(sftCaseId)) {
                parentRec.FEC_Service_Case_ID__c = sftCaseId;
                parentRec.FEC_Integrate_Case_ID__c = sftCase.Id;
                update parentRec;
            }

            log('Parent integration record updated with SFT Case Id: ' + sftCaseId);
            log('==================== processSFTCase SUCCESS ====================');
            return FEC_IntegrationFraudCaseUtil.successResponseXml(
                sftCaseId, MSG_FRAUD_UPDATE_SUCCESS).toXmlString();
        }
        catch (Exception ex) {
            log('==================== processSFTCase ERROR ====================');
            log('Error message: ' + ex.getMessage());
            log('Stack trace  : ' + ex.getStackTraceString());
            return FEC_IntegrationFraudCaseUtil.errorResponseXml(
                ex.getMessage(),
                FEC_FraudConstantCommon.CLIENT_ERROR
            ).toXmlString();
        }
    }


    private static String randomSFTCaseId() {
        Integer raw = Math.abs(Crypto.getRandomInteger());
        Integer rnd = Math.mod(raw, 1000000);  // 0–999999, no error
        return 'SFT-' + String.valueOf(rnd).leftPad(6, '0');
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
    /**
     * Creates a new SFT (Service Fraud Task) case record.
     *
     * Generates FEC_Case_ID__c in format: SFT-XXXXXXXXXXXXXXXX
     * Sequence starts from 5000000 and auto-increments.
     * Also creates a corresponding standard Case record in Salesforce.
     *
     * @param serviceCaseId  The service case reference ID (FEC_ID_Search__c from Case)
     * @param channelId      The integration channel ID
     * @param parentCaseId   The parent fraud case ID (FH case)
     * @return The created FEC_Integration_Case__c record
     */
    public static Case createSFTCase(
        String serviceCaseId,
        String channelId,
        String parentCaseId
    ) {
        return createSFTCase(serviceCaseId, channelId, parentCaseId, null, null, null);
    }

    /**
     * Creates a new SFT (Service Fraud Task) case record with category info.
     *
     * @param serviceCaseId  The service case reference ID
     * @param channelId      The integration channel ID
     * @param parentCaseId   The parent fraud case ID
     * @param category       The fraud category
     * @param subCategory    The fraud sub-category
     * @param subCode        The fraud sub-code
     * @return The created Case record
     */
    public static Case createSFTCase(
        String serviceCaseId,
        String channelId,
        String parentCaseId,
        String category,
        String subCategory,
        String subCode
    ) {
        try {
            String sftCaseId = generateSFTCaseId();
            log('[createSFTCase] Generated SFT Case ID: ' + sftCaseId);

            // 1. Create standard Case record with SFT_Case record type
            Id recordTypeId = FEC_CommonUltils.getRecordTypeIdByDev(FEC_FraudConstantCommon.CASE_SFT_RECORD_TYPE_DEV_NAME);
            List<FEC_Product_Type__c> productTypes = [
                SELECT Id 
                FROM FEC_Product_Type__c 
                WHERE FEC_Code__c = :FEC_FraudConstantCommon.CASE_SFT_REQUEST
                LIMIT 1
            ];
            log('recordTypeId: '+ recordTypeId);

            Case sfCase = new Case();
            sfCase.Subject = 'SFT - ' + sftCaseId;
            //sfCase.FEC_Channel__c = channelId;
            sfCase.Status = FEC_FraudConstantCommon.INITIAL;
            sfCase.FEC_ID_Search__c = sftCaseId;
            sfCase.RecordTypeId = recordTypeId;
            sfCase.FEC_Customer_Type__c = FEC_ConstantCommon.CASE_ALL_REQUEST;
            sfCase.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE;
            sfCase.FEC_Skip_Search_Internal_Case__c = true;
            //sfCase.FEC_Case_Status__c = FEC_FraudConstantCommon.INITIAL;
            //sfCase.FEC_Case_Created_On__c = Datetime.now();
            //sfCase.FEC_Case_ID__c  = sftCaseId;
            if (!productTypes.isEmpty()) {
                sfCase.FEC_Product_Type__c = productTypes.get(0).Id;
            }

            // Set category: use passed value or default to SFT category
            if (String.isNotBlank(category)) {
                sfCase.FEC_Category__c = category;
            } else {
                List<FEC_Category__c> sftCategories = [
                    SELECT Id FROM FEC_Category__c
                    WHERE FEC_Code__c = :FEC_FraudConstantCommon.SFT_CATEGORY_CODE
                    LIMIT 1
                ];
                if (!sftCategories.isEmpty()) {
                    sfCase.FEC_Category__c = sftCategories[0].Id;
                }
            }

            // Set subcategory: use passed value or default to SFT subcategory
            if (String.isNotBlank(subCategory)) {
                sfCase.FEC_SubCategory__c = subCategory;
            } else {
                List<FEC_Sub_Category__c> sftSubCategories = [
                    SELECT Id FROM FEC_Sub_Category__c
                    WHERE FEC_Code__c = :FEC_FraudConstantCommon.SFT_SUB_CATEGORY_CODE
                    LIMIT 1
                ];
                if (!sftSubCategories.isEmpty()) {
                    sfCase.FEC_SubCategory__c = sftSubCategories[0].Id;
                }
            }

            if (String.isNotBlank(subCode)) {
                sfCase.FEC_SubCode__c = subCode;
            } else {
                List<FEC_Sub_Code__c> sftSubCodes = [
                    SELECT Id FROM FEC_Sub_Code__c
                    WHERE FEC_Code__c = :FEC_FraudConstantCommon.SFT_SUB_CODE
                    LIMIT 1
                ];
                if (!sftSubCodes.isEmpty()) {
                    sfCase.FEC_SubCode__c = sftSubCodes[0].Id;
                }
            }
            log('[createSFTCase] RecordTypeId=' + recordTypeId + ' | ProductType=' + (productTypes.isEmpty() ? 'NONE' : productTypes[0].Id));
            log('[createSFTCase] Category=' + sfCase.FEC_Category__c + ' | SubCategory=' + sfCase.FEC_SubCategory__c + ' | SubCode=' + sfCase.FEC_SubCode__c);

            // Determine owner: assign to current user if they created the parent FH case, otherwise assign to queue
            Id currentUserId = UserInfo.getUserId();
            Boolean assignToCurrentUser = false;

            if (String.isNotBlank(parentCaseId)) {
                 List<FEC_Integration_Case__c> parentCasesBU = [
                    SELECT Id, FEC_Parent_CaseID__c
                    FROM FEC_Integration_Case__c
                    WHERE FEC_CaseID__c = :parentCaseId
                    LIMIT 1
                ];
                if (!parentCasesBU.isEmpty() && String.isNotBlank(parentCasesBU[0].FEC_Parent_CaseID__c)) {
                    
                    List<FEC_Integration_Case__c> parentCases = [
                        SELECT Id, CreatedById
                        FROM FEC_Integration_Case__c
                        WHERE FEC_CaseID__c = :parentCasesBU[0].FEC_Parent_CaseID__c
                        LIMIT 1
                    ];
                    if (!parentCases.isEmpty() && parentCases[0].CreatedById == currentUserId) {
                        assignToCurrentUser = true;
                    }
                }
               

            }

            if (assignToCurrentUser) {
                sfCase.OwnerId = currentUserId;
                log('[createSFTCase] Assigned to current user: ' + currentUserId);
            } else {
                // Assign to SFT queue
                List<Group> queues = [
                    SELECT Id FROM Group
                    WHERE Type = 'Queue'
                    AND DeveloperName = :FEC_FraudConstantCommon.SFT_QUEUE_NAME
                    LIMIT 1
                ];
                if (!queues.isEmpty()) {
                    sfCase.OwnerId = queues[0].Id;
                    log('[createSFTCase] Assigned to queue: ' + queues[0].Id);
                } else {
                    log('[createSFTCase] SFT queue not found, using default owner');
                }
            }

            insert sfCase;
            FEC_Additional_Info__c newInfo = new FEC_Additional_Info__c(
                    FEC_Case__c = sfCase.Id
                );
            insert newInfo;
            log('[createSFTCase] Created SF Case: ' + sfCase.Id);

            return sfCase;
        } catch (Exception ex) {
            log('[createSFTCase] ERROR: ' + ex.getMessage());
            log('[createSFTCase] Stack: ' + ex.getStackTraceString());
            throw ex;
        }
    }

    /**
     * Generates the next SFT case ID in format: SFT-XXXXXXXXXXXXXXXX
     * Starts from SFT-5000000, increments sequentially.
     */
    private static String generateSFTCaseId() {
        Long startNumber = FEC_FraudConstantCommon.START_NUMBER_CASE_SFT;
        String prefix = 'SFT-';

        // Find the highest existing SFT case number
        List<FEC_Integration_Case__c> lastCase = [
            SELECT FEC_Service_Case_ID__c
            FROM FEC_Integration_Case__c
            WHERE FEC_Service_Case_ID__c LIKE 'SFT-%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!lastCase.isEmpty()) {
            String lastId = lastCase[0].FEC_Service_Case_ID__c;
            String numberPart = lastId.replace(prefix, '');
            try {
                Long lastNumber = Long.valueOf(numberPart);
                if (lastNumber >= startNumber) {
                    startNumber = lastNumber + 1;
                }
            } catch (Exception e) {
                log('[generateSFTCaseId] Could not parse last SFT number: ' + numberPart);
            }
        }

        return prefix + String.valueOf(startNumber);
    }

    private static void log(String msg) {
        if (DEBUG_LOG) {
            System.debug(LoggingLevel.INFO, msg);
        }
    }   



}