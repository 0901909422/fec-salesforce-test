@RestResource(urlMapping='/fec/*')
global with sharing class FEC_IntegrationFraudCaseApi {
    public static final Boolean DEBUG_LOG = true;

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
        String responseXml = null;
        String requestBody = RestContext.request.requestBody.toString();
        String caseId;
        String sericeName = 'UpdateFraudCaseStatus';
        String channelId = '';
        String serviceCaseId;
        try { 

            // Map<String,Object> extractData = extractRequestData(
            //     RestContext.request.requestBody.toString()
            // );
            FEC_IntegrationFraudCaseUtil.FraudExtractResult extractData =
            FEC_IntegrationFraudCaseUtil.extractFraudPayload(requestBody);
        
            Map<String, Object> detail = extractData.detail;
            String xmlData = extractData.xmlData;
            
            //log('FINAL DETAIL:\n' + JSON.serializePretty(detail));
            //log('FINAL XML:\n' + xmlData);
        
            if (detail == null) {
                responseXml = FEC_IntegrationFraudCaseUtil.errorXml('Missing detail object');
            }            
             // extract business fields
             caseId = (String) detail.get('caseID');
             serviceCaseId = (String) detail.get('referenceID');
             channelId = (String) detail.get('channelID');
            if (String.isBlank(caseId)) {
                responseXml = FEC_IntegrationFraudCaseUtil.errorXml('caseID is required');
            }

            if (String.isBlank(xmlData)) {
                responseXml = FEC_IntegrationFraudCaseUtil.errorXml('Missing XML data');
            }
            
            // Check FH, BU, TK case
            String normalized = caseId.trim().toUpperCase();
            String xmlInput = FEC_IntegrationFraudCaseUtil.normalizeXml(xmlData);
           
            log('xmlInput: '+ xmlInput);

            if (normalized.startsWith('FH-')) {
                responseXml = processFHCase(detail, xmlInput);

            } else if (normalized.startsWith('BU-')) {
                responseXml = processBUCase(detail, xmlInput);

            } else if (normalized.startsWith('TK-')) {
                responseXml = processTKCase(detail, xmlInput);  // TK same handling

            } else {
                responseXml = FEC_IntegrationFraudCaseUtil.errorXml('Not found fraud case format');
            }
            return responseXml;

        } catch (Exception ex) {
            log('UpdateFraudCaseStatus - Exception: ' + ex.getMessage());
            responseXml = FEC_IntegrationFraudCaseUtil.errorXml(ex.getMessage());
            return responseXml;
        }
        finally {           
            try {
                // If request caseId missing, recover from response
                if (String.isBlank(caseId) && !String.isBlank(responseXml)) {
                    caseId = FEC_IntegrationFraudCaseUtil.extractCaseIdFromResponse(responseXml);
                }
                FEC_IntegrationFraudCaseUtil.logIntegrationService(
                    sericeName,
                    channelId,
                    caseId,
                    serviceCaseId,
                    requestBody,
                    responseXml
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
        try {
            // 2) Parse XML
            Dom.Document doc = new Dom.Document();            
            doc.load(xmlData);

            Dom.XmlNode root = doc.getRootElement();
            Dom.XmlNode caseNode = FEC_IntegrationFraudCaseUtil.find(root, 'CaseResultInfo');

            if (caseNode == null)
                return FEC_IntegrationFraudCaseUtil.errorXml('CaseResultInfo not found');

            String caseStatus     = (String) detail.get('caseStatus');
            String parentId       = (String) detail.get('parentID');
            String referenceId    = (String) detail.get('referenceID');
            String caseId         = (String) detail.get('caseID');
            String channelID      = (String) detail.get('channelID');
            //Check Service Case Existing
            if (parentId == null) {
                String msg = 'Parent ID not found for CaseID=' + caseId +
                            ', ServiceCase=' + referenceId + ', Channel= ' + channelID;
                log(msg);
                return FEC_IntegrationFraudCaseUtil.errorXml(msg);
            }
            Long messageTime = (Long) detail.get('messageTime');
            Datetime messageDateTime = null;
            if (messageTime != null) {
                Integer secondsInt = Integer.valueOf(messageTime / 1000);
                messageDateTime = Datetime.newInstance(1970, 1, 1, 0, 0, 0).addSeconds(secondsInt);
            }

            String investigationConclusion = (String) detail.get('investigationConclusion');   

            // Parse XML fields
            String xmlRemark      = FEC_IntegrationFraudCaseUtil.val(caseNode, 'Remarks');
            String xmlCreated     = FEC_IntegrationFraudCaseUtil.val(caseNode, 'CreatedTime');
            String xmlUpdated     = FEC_IntegrationFraudCaseUtil.val(caseNode, 'UpdatedTime');

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
                String msg = 'Fraud case not found for CaseID: ' + caseId +
                            ', ServiceCase: ' + referenceId + ', Channel: ' + channelID;
                log(msg);
                return FEC_IntegrationFraudCaseUtil.errorXml(msg);
            }


            rec = exist.isEmpty() ? new FEC_Integration_Case__c() : exist[0];

            rec.FEC_CaseID__c          = caseId;
            rec.FEC_Case_Status__c     = FEC_IntegrationFraudCaseUtil.mapCaseStatus(caseStatus);
            rec.FEC_Parent_CaseID__c   = parentId;
            rec.FEC_Service_Case_ID__c = referenceId;
            rec.FEC_Remark__c          = xmlRemark;
            rec.FEC_Sys_Channel__c = channelID;

            rec.FEC_Created_Time__c = parsePegaDatetime(xmlCreated);
            rec.FEC_Updated_Time__c = parsePegaDatetime(xmlUpdated);
            rec.FEC_Message_Time__c = messageDateTime;
            rec.FEC_Investigation_Conclusion__c = investigationConclusion;

            upsert rec;

            //Update child info
            Map<String, FEC_Integration_Case_Info__c> existingInfoMap = new Map<String, FEC_Integration_Case_Info__c>();

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
                FEC_IntegrationFraudCaseUtil.findAllDeep(root, 'AdditionalInfo');

            log('Found AdditionalInfo count = ' + additionalInfoNodes.size());

            for (Dom.XmlNode ai : additionalInfoNodes) {

                String idVal  = FEC_IntegrationFraudCaseUtil.val(ai, 'ID');
                String valVal = FEC_IntegrationFraudCaseUtil.val(ai, 'Value');     
                if (String.isBlank(idVal)) {
                    continue; // nothing to process
                }
                FEC_Integration_Case_Info__c existing = existingInfoMap.get(idVal);
                if (existing != null) {
                    // Update
                    String fileType = getFileType(idVal, channelID);
                    Boolean isFile = (fileType != null && fileType.equalsIgnoreCase('file'));
            
                    if (!isFile && existing.FEC_Info_Value__c != valVal) {
                        existing.FEC_Info_Value__c = valVal;
                        toUpdate.add(existing);
                    }
            
                } else {
                    // Insert
                    toInsert.add(new FEC_Integration_Case_Info__c(
                        FEC_Parent_Case__c = rec.Id,
                        FEC_Info_ID__c     = idVal,
                        FEC_Info_Value__c  = valVal
                    ));
                }        

                // if (existingInfoMap.containsKey(idVal)) {
                //     String fileType = getFileType(idVal, channelID);
                //     //Update
                //     FEC_Integration_Case_Info__c existing = existingInfoMap.get(idVal);
                //     if (existing.FEC_Info_Value__c != valVal) {
                //         Boolean isFile = (fileType != null && fileType.equalsIgnoreCase('file'));
                //         if (!isFile) {
                //             existing.FEC_Info_Value__c = valVal;
                //             toUpdate.add(existing);
                //         }
                //     }
                // } else {
                //     //Insert
                //     toInsert.add(new FEC_Integration_Case_Info__c(
                //         FEC_Parent_Case__c = rec.Id,
                //         FEC_Info_ID__c     = idVal,
                //         FEC_Info_Value__c  = valVal
                //     ));
                // }
            }

            if (!toInsert.isEmpty()) insert toInsert;
            if (!toUpdate.isEmpty()) update toUpdate;            
            log('Inserted: ' + toInsert.size() + ', Updated: ' + toUpdate.size());
            
           
            return FEC_IntegrationFraudCaseUtil.successXml(caseId, 'Fraud case updated successfully');
        } catch (Exception ex) {
            return FEC_IntegrationFraudCaseUtil.errorXml(ex.getMessage());
        }
        

    }

    /**
     * Retrieves the file type for a given file name and integration channel.
     *
     * This method looks up the FEC_Master_Data_Integration__c configuration table
     * to determine the source type associated with the provided file name and
     * channel ID. It returns the corresponding FEC_Source_Type__c value if found.
     *
     * @param fileName              The name or identifier of the file to look up.
     * @param integrationChannelId The integration channel in which the file is used.
     * @return The file type (FEC_Source_Type__c) if a matching record is found;
     *         otherwise returns null.
     */
    private static String getFileType(String fieldName, String integrationChannelId) {
        log('getFileType.fieldName: ' + fieldName);
        log('getFileType.integrationChannelId: ' + integrationChannelId);
        List<FEC_Master_Data_Integration__c> records = [
            SELECT FEC_Source_Type__c
            FROM FEC_Master_Data_Integration__c
            WHERE FEC_Channel__c = :integrationChannelId
            AND FEC_Source_Id__c = :fieldName
            LIMIT 1
        ];

        if (!records.isEmpty()) {
            return records[0].FEC_Source_Type__c;
        }

        return null;
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
        try {
            // 2) Parse XML
            Dom.Document doc = new Dom.Document();
            doc.load(xmlData);

            Dom.XmlNode root = doc.getRootElement();
            Dom.XmlNode caseNode = FEC_IntegrationFraudCaseUtil.find(root, 'CaseResultInfo');

            if (caseNode == null)
                return FEC_IntegrationFraudCaseUtil.errorXml('CaseResultInfo not found');
            
            Dom.XmlNode originalRequestNode = FEC_IntegrationFraudCaseUtil.find(caseNode, 'OriginalRequest');
            Dom.XmlNode requestInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, 'RequestInfo');
            if (requestInfoNode == null)
                return FEC_IntegrationFraudCaseUtil.errorXml('RequestInfo not found');
            
            Dom.XmlNode creatorInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, 'CreatorInfo');
            if (creatorInfoNode == null)
                return FEC_IntegrationFraudCaseUtil.errorXml('CreatorInfo not found');

            Dom.XmlNode customerInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, 'CustomerInfo');
            if (customerInfoNode == null)
                return FEC_IntegrationFraudCaseUtil.errorXml('CustomerInfo not found');

            String caseStatus     = (String) detail.get('caseStatus');
            String parentId       = (String) detail.get('parentID');
            String referenceId    = (String) detail.get('referenceID');
            String caseId         = (String) detail.get('caseID');
            String channelID      = (String) detail.get('channelID');
            Long messageTime = (Long) detail.get('messageTime');
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
                String msg = 'Not found parentID: ' + parentId +
                            ', Channel: ' + channelID;
                log(msg);
                return FEC_IntegrationFraudCaseUtil.errorXml(msg);
            }
            if (messageTime != null) {
                Integer secondsInt = Integer.valueOf(messageTime / 1000);
                messageDateTime = Datetime.newInstance(1970, 1, 1, 0, 0, 0).addSeconds(secondsInt);
            }

            String investigationConclusion = (String) detail.get('investigationConclusion');   

            // Parse XML fields
            String xmlCreatorEmail      = FEC_IntegrationFraudCaseUtil.val(creatorInfoNode, 'CreatorEmail');
            String xmlUserType      = FEC_IntegrationFraudCaseUtil.val(customerInfoNode, 'UserType');
            String xmlRemark      = FEC_IntegrationFraudCaseUtil.val(requestInfoNode, 'Remarks');

            String xmlCreated     = FEC_IntegrationFraudCaseUtil.val(caseNode, 'CreatedTime');
            String xmlUpdated     = FEC_IntegrationFraudCaseUtil.val(caseNode, 'UpdatedTime');

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
            rec.FEC_Creator_Email__c   = xmlCreatorEmail;
            rec.FEC_Case_Type__c       = xmlUserType;
            rec.FEC_Sys_Channel__c = channelID;

            rec.FEC_Created_Time__c = parsePegaDatetime(xmlCreated);
            rec.FEC_Updated_Time__c = parsePegaDatetime(xmlUpdated);
            rec.FEC_Message_Time__c = messageDateTime;
            rec.FEC_Investigation_Conclusion__c = investigationConclusion;
            upsert rec;
           
            //log('infoToInsert = ' + infoToInsert.size());
            return FEC_IntegrationFraudCaseUtil.successXml(caseId, 'Fraud case updated successfully');
        } catch (Exception ex) {
            return FEC_IntegrationFraudCaseUtil.errorXml(ex.getMessage());
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
        try {            
            Boolean isUicCS = false;
            Boolean isResultDetailCode = false;
            // 2) Parse XML
            Dom.Document doc = new Dom.Document();
            doc.load(xmlData);
            Dom.XmlNode root = doc.getRootElement();
            Dom.XmlNode caseNode = FEC_IntegrationFraudCaseUtil.find(root, 'CaseResultInfo');
            if (caseNode == null)
                return FEC_IntegrationFraudCaseUtil.errorXml('CaseResultInfo not found');
            
            Dom.XmlNode originalRequestNode = FEC_IntegrationFraudCaseUtil.find(caseNode, 'OriginalRequest');
            Dom.XmlNode requestInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, 'RequestInfo');
            if (requestInfoNode == null)
                return FEC_IntegrationFraudCaseUtil.errorXml('RequestInfo not found');
            
            Dom.XmlNode creatorInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, 'CreatorInfo');
            if (creatorInfoNode == null)
                return FEC_IntegrationFraudCaseUtil.errorXml('CreatorInfo not found');

            Dom.XmlNode customerInfoNode = FEC_IntegrationFraudCaseUtil.find(originalRequestNode, 'CustomerInfo');
            if (customerInfoNode == null)
                return FEC_IntegrationFraudCaseUtil.errorXml('CustomerInfo not found');

            String caseStatus     = (String) detail.get('caseStatus');
            String parentId       = (String) detail.get('parentID');
            String referenceId    = (String) detail.get('referenceID');
            String caseId         = (String) detail.get('caseID');
            String channelID      = (String) detail.get('channelID');
            Long messageTime = (Long) detail.get('messageTime');            
            Datetime messageDateTime = null;
            //Check Parent Case Existing
            List<FEC_Integration_Case__c> existParent = [
                SELECT Id, FEC_Parent_CaseID__c
                FROM FEC_Integration_Case__c 
                WHERE FEC_CaseID__c = :parentId                 
                AND FEC_Sys_Channel__c = :channelID
                LIMIT 1
            ];
            if (existParent.isEmpty()) {
                String msg = 'Not found parentID: ' + parentId +
                            ', Channel: ' + channelID;
                log(msg);
                return FEC_IntegrationFraudCaseUtil.errorXml(msg);
            }
            String fraudCaseFH = existParent[0].FEC_Parent_CaseID__c;
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
            
            if (messageTime != null) {
                Integer secondsInt = Integer.valueOf(messageTime / 1000);
                messageDateTime = Datetime.newInstance(1970, 1, 1, 0, 0, 0).addSeconds(secondsInt);
            }

            String investigationConclusion = (String) detail.get('investigationConclusion');   

            // Parse XML fields
            String xmlCreatorEmail      = FEC_IntegrationFraudCaseUtil.val(creatorInfoNode, 'CreatorEmail');
            String xmlUserType      = FEC_IntegrationFraudCaseUtil.val(customerInfoNode, 'UserType');
            String xmlRemark      = FEC_IntegrationFraudCaseUtil.val(requestInfoNode, 'Remarks');

            String xmlCreated     = FEC_IntegrationFraudCaseUtil.val(caseNode, 'CreatedTime');
            String xmlUpdated     = FEC_IntegrationFraudCaseUtil.val(caseNode, 'UpdatedTime');

            log('XML Fields:\nRemark='+xmlRemark+'\nCreated='+xmlCreated+'\nUpdated='+xmlUpdated);

            // 3) UPSERT parent
            FEC_Integration_Case__c rec;

            List<FEC_Integration_Case__c> exist = [
                SELECT Id,FEC_Service_Case_ID__c FROM FEC_Integration_Case__c WHERE FEC_CaseID__c = :caseId LIMIT 1
            ];

            rec = exist.isEmpty() ? new FEC_Integration_Case__c() : exist[0];
            if (!exist.isEmpty() && exist[0].FEC_Service_Case_ID__c != null) {
                rec.FEC_Service_Case_ID__c = exist[0].FEC_Service_Case_ID__c;
            }
            if(!existFraudCase.isEmpty()) {
                rec.FEC_Category__c = existFraudCase[0].FEC_Category__c;
                rec.FEC_Sub_Category__c = existFraudCase[0].FEC_Sub_Category__c;
                rec.FEC_Sub_Code__c = existFraudCase[0].FEC_Sub_Code__c;
            }

            rec.FEC_CaseID__c          = caseId;
            rec.FEC_Case_Status__c     = FEC_IntegrationFraudCaseUtil.mapCaseStatus(caseStatus);
            rec.FEC_Parent_CaseID__c   = parentId;            
            rec.FEC_Remark__c          = xmlRemark;
            rec.FEC_Creator_Email__c   = xmlCreatorEmail;
            rec.FEC_Case_Type__c       = xmlUserType;
            rec.FEC_Sys_Channel__c = channelID;
            rec.FEC_Created_Time__c = parsePegaDatetime(xmlCreated);
            rec.FEC_Updated_Time__c = parsePegaDatetime(xmlUpdated);
            rec.FEC_Message_Time__c = messageDateTime;
            rec.FEC_Investigation_Conclusion__c = investigationConclusion;
            log('Record before UPSERT: ' + JSON.serializePretty(rec));
            upsert rec;

            //Update child info
            Map<String, FEC_Integration_Case_Info__c> existingInfoMap = new Map<String, FEC_Integration_Case_Info__c>();

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
                FEC_IntegrationFraudCaseUtil.findAllDeep(root, 'AdditionalInfo');

            log('Found AdditionalInfo count = ' + additionalInfoNodes.size());

            for (Dom.XmlNode ai : additionalInfoNodes) {

                String idVal  = FEC_IntegrationFraudCaseUtil.val(ai, 'ID');
                String valVal = FEC_IntegrationFraudCaseUtil.val(ai, 'Value');  
                if (String.isBlank(idVal)) {
                    continue; // nothing to process
                }
                // Check SFT case                
                if ('UIC'.equals(idVal == null ? null : idVal.toUpperCase()) &&
                    'CS'.equals(valVal == null ? null : valVal.toUpperCase())) {
                        isUicCS = true;
                }
                if ('RESULTDETAILCODE'.equals(idVal == null ? null : idVal.toUpperCase()) &&
                    'CUS'.equals(valVal == null ? null : valVal.toUpperCase())) {
                    isResultDetailCode = true;
                }

                FEC_Integration_Case_Info__c existing = existingInfoMap.get(idVal);
                if (existing != null) {
                    // Update
                    String fileType = getFileType(idVal, channelID);
                    Boolean isFile = (fileType != null && fileType.equalsIgnoreCase('file'));
            
                    if (!isFile && existing.FEC_Info_Value__c != valVal) {
                        existing.FEC_Info_Value__c = valVal;
                        toUpdate.add(existing);
                    }
            
                } else {
                    // Insert
                    toInsert.add(new FEC_Integration_Case_Info__c(
                        FEC_Parent_Case__c = rec.Id,
                        FEC_Info_ID__c     = idVal,
                        FEC_Info_Value__c  = valVal
                    ));
                }
            }

            if (!toInsert.isEmpty()) insert toInsert;
            if (!toUpdate.isEmpty()) update toUpdate;

            //Process SFT Case
            if(isUicCS && isResultDetailCode) {
                processSFTCase(caseId);
            }
            
            return FEC_IntegrationFraudCaseUtil.successXml(caseId, 'Fraud case updated successfully');
        } catch (Exception ex) {
            return FEC_IntegrationFraudCaseUtil.errorXml(ex.getMessage());
        }
    }
    
    private static String processSFTCase(String caseId) {
        try {
            log('processSFTCase = ');
            return FEC_IntegrationFraudCaseUtil.successXml(caseId, 'Fraud case updated successfully');            
        } catch (Exception ex) {
            return FEC_IntegrationFraudCaseUtil.errorXml(ex.getMessage());
        }
    }


    /**
     * Converts a Pega-formatted ISO 8601 datetime string into a Salesforce Datetime value.
     *
     * This method normalizes the incoming datetime string by:
     * 1. Removing the trailing 'Z' (UTC designator).
     * 2. Replacing the 'T' separator with a space.
     * 3. Stripping off millisecond precision.
     * 4. Parsing the cleaned value as a GMT-based Salesforce Datetime.
     *
     * Example:
     *   Input : 2025-09-10T10:07:22.263Z
     *   Output: 2025-09-10 10:07:22 (GMT)
     *
     * @param reqDt The datetime string received from the Pega system.
     * @return Parsed Salesforce Datetime value in GMT, or null if input is blank.
     */
    private static Datetime parsePegaDatetime(String reqDt) {
        if (String.isBlank(reqDt)) return null;
    
        // Example input: 2025-09-10T10:07:22.263Z → remove Z
        String cleaned = reqDt.replace('Z','');
    
        // Replace "T" with space
        cleaned = cleaned.replace('T', ' ');
    
        // Remove milliseconds (.263)
        Integer dotIndex = cleaned.indexOf('.');
        if (dotIndex > 0) {
            cleaned = cleaned.substring(0, dotIndex);
        }
    
        log('Cleaned datetime for Salesforce = ' + cleaned);
    
        return Datetime.valueOfGmt(cleaned);
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



}