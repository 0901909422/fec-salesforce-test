global with sharing class FEC_IntegrationFraudService {

    public static final Boolean DEBUG_LOG = true;
	public static final Integer BATCH_SIZE = 150;
	public static final String XML_NODE_BODY = 'Body';
	public static final String MADATORY_STR = 'true';   
    public static final String FIELD_TYPE_PRODUCT = 'Product';
	public static final String FIELD_TYPE_CASE_TYPE = 'CaseType';
	public static final String FIELD_TYPE_CATEGORY = 'Category';
	public static final String FIELD_TYPE_SUBCATEGORY = 'SubCategory';
	public static final String FIELD_TYPE_SUBCODE = 'SubCode';
    public static final String FIELD_TYPE_AVAILABELVAL = 'AvailableValues';
	public static final String FIELD_TYPE_ADDITIONALPROPERTY = 'AdditionalProperty';
    private static final String TEMPLATE_NAME =
        'Integration_MasterData_Job_Notification';

    public class IntegrationFraudField {
        public final String GET_FRAUD_MASTER_DATA_RESPONSE = 'GetFraudMasterDataResponse';
		public final String MASTER_DATA_ITEMS = 'MasterDataItems';
		public final String MASTER_DATA_ID = 'ID';
		public final String MASTER_DATA_NAME = 'Name';
		public final String MASTER_DATA_NAMEVN = 'NameVN';
		public final String MASTER_DATA_TYPE = 'Type';
		public final String MASTER_DATA_APPLY_TO = 'ApplyTo';
		public final String MASTER_DATA_POST_ORDER = 'PosOrder';
		public final String MASTER_DATA_ADDITIONAL_PROPERTIES = 'AdditionalProperties';
		public final String MASTER_DATA_CHILDRENT = 'Children';
		public final String MASTER_DATA_MANDATORY = 'Mandatory';
    }

    

    /**
     * Synchronizes Fraud Master Data from the external integration source into Salesforce.
     *
     * This method performs the complete integration flow:
     *  1. Loads all existing master data records for the integration channel.
     *  2. Retrieves and parses the external XML payload.
     *  3. Transforms the XML structure into Salesforce records.
     *  4. Performs an upsert operation to insert new records and update existing ones.
     *
     * @return The total number of records inserted or updated.
     */
    public static Integer syncMasterDataIntegration() {   
        IntegrationFraudField masterDataField = new IntegrationFraudField();
        String integrationChannelId = getIntegrationChannelCode(FEC_FraudConstantCommon.DEFAULT_CHANNEL_INTEGRATION_CODE);
        // 1) Load ALL existing mapping records into a map for upsert comparison
        Map<String, FEC_Master_Data_Integration__c> existingMap = loadExisting(integrationChannelId);        
       
        Boolean isConnectisConnected  = isConnectFraudSystem();
        log('LOG-syncMasterDataIntegration: ' + isConnectisConnected);
        
        String xml = null;
        if(isConnectisConnected) {
            xml = getFraudMasterData();
            log('LOG-XML_MASTER_DATA REAL: ' + xml);
        } else {
            //xml = FEC_FraudCaseMockData.getFraudMasterData();
            log('LOG-XML_MASTER_DATA MOCKUP: ');
        }
      
        // 2) Parse XML
       
        
        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode root = doc.getRootElement();
        Dom.XmlNode body = getChildIgnoreNS(root, XML_NODE_BODY);
        Dom.XmlNode response = findChildByEndsWith(body, masterDataField.GET_FRAUD_MASTER_DATA_RESPONSE);

        // Data to upsert
        Map<String, FEC_Master_Data_Integration__c> toUpsert = new Map<String, FEC_Master_Data_Integration__c>();

        for (Dom.XmlNode mdi : response.getChildElements()) {
            if (mdi.getName() == masterDataField.MASTER_DATA_ITEMS) {
                processMasterDataItem(mdi, null, '', toUpsert, existingMap, integrationChannelId);
            }
        }

        // 3) UPSERT records
        upsertMasterDataRecords(toUpsert);

        return toUpsert.size();
    }
    

    /**
     * Performs a bulk UPSERT operation for all prepared master data records.
     *
     * Records are processed in batches of 150 to:
     *  - Stay well within Salesforce governor limits
     *  - Improve performance and transaction reliability
     *
     * @param toUpsert A map containing all records that need to be inserted or updated.
     */
    private static void upsertMasterDataRecords(Map<String, FEC_Master_Data_Integration__c> toUpsert) {
        List<FEC_Master_Data_Integration__c> batch = new List<FEC_Master_Data_Integration__c>();

        for (FEC_Master_Data_Integration__c rec : toUpsert.values()) {
            batch.add(rec);

            if (batch.size() == BATCH_SIZE) {
                upsert batch;
                batch.clear();
            }
        }
        if (!batch.isEmpty()) upsert batch;
    }

     /**
     * Recursively processes a MasterDataItem node from the integration XML and
     * transforms it into Salesforce records for upsert.
     *
     * This method:
     *  • Extracts basic attributes from the current XML node
     *  • Builds a hierarchical path for UI display and traceability
     *  • Creates or updates the corresponding Salesforce record
     *  • Processes all nested Additional Properties
     *  • Recursively traverses child nodes to build the full data tree
     *
     * @param node                 Current XML node being processed
     * @param parentId             Parent source ID (used to build hierarchy)
     * @param path                 Hierarchical path string for the UI
     * @param upsertMap            Map of records pending insert/update
     * @param existingMap          Map of existing records loaded from Salesforce
     * @param integrationChannelId Integration channel identifier
     */
    private static void processMasterDataItem(
        Dom.XmlNode node,
        String parentId,
        String path,
        Map<String, FEC_Master_Data_Integration__c> upsertMap,
        Map<String, FEC_Master_Data_Integration__c> existingMap,
        String integrationChannelId
    ) {
        IntegrationFraudField masterDataField = new IntegrationFraudField();
        String id = text(node, masterDataField.MASTER_DATA_ID);
        String name = text(node, masterDataField.MASTER_DATA_NAME);
        String nameVN = text(node, masterDataField.MASTER_DATA_NAMEVN);
        String type = text(node, masterDataField.MASTER_DATA_TYPE);
        String newPath = (path == '' ? name : path + ' > ' + name);
        String applyTo = text(node, masterDataField.MASTER_DATA_APPLY_TO);
        applyTo = String.isBlank(applyTo) ? null : applyTo;
        String posOrderStr = text(node, masterDataField.MASTER_DATA_POST_ORDER);
        Integer posOrder = (posOrderStr != null && posOrderStr.trim() != '') ? Integer.valueOf(posOrderStr) : null;

        if (type != null && (
            type == FIELD_TYPE_PRODUCT ||
            type == FIELD_TYPE_CASE_TYPE ||
            type == FIELD_TYPE_CATEGORY ||
            type == FIELD_TYPE_SUBCATEGORY ||
            type == FIELD_TYPE_SUBCODE
        )) {
            upsertNode(
                type, id, parentId, name, nameVN, null, null, null, newPath,
                existingMap, upsertMap, integrationChannelId, applyTo, posOrder
            );
        }

        // AdditionalProperties
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == masterDataField.MASTER_DATA_ADDITIONAL_PROPERTIES) {
                processAdditionalProperty(child, id, newPath, upsertMap, existingMap, integrationChannelId);
            }
        }

        // Children
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == masterDataField.MASTER_DATA_CHILDRENT) {
                processMasterDataItem(child, id, newPath, upsertMap, existingMap, integrationChannelId);
            }
        }
    }

    /**
     * Processes an AdditionalProperty node and all of its Available Values
     * from the integration XML, transforming them into Salesforce records.
     *
     * This method:
     *  • Extracts Additional Property metadata
     *  • Creates or updates the corresponding Salesforce record
     *  • Iterates through and processes all child Available Values
     *  • Maintains hierarchical path information for UI rendering
     *
     * @param node                 The AdditionalProperty XML node
     * @param parentId             Parent source ID (typically the SubCode ID)
     * @param path                 Hierarchical path for UI display
     * @param upsertMap            Records prepared for upsert
     * @param existingMap          Existing Salesforce records
     * @param integrationChannelId Integration channel identifier
     */
    private static void processAdditionalProperty(
        Dom.XmlNode node,
        String parentId,
        String path,
        Map<String, FEC_Master_Data_Integration__c> upsertMap,
        Map<String, FEC_Master_Data_Integration__c> existingMap,
        String integrationChannelId
    ) {
        IntegrationFraudField masterDataField = new IntegrationFraudField();
        String fieldId = text(node, masterDataField.MASTER_DATA_ID);
        String fieldName = text(node, masterDataField.MASTER_DATA_NAME);
        String nameVN = text(node, masterDataField.MASTER_DATA_NAMEVN);
        String type = text(node, masterDataField.MASTER_DATA_TYPE);
        String mandStr = text(node, masterDataField.MASTER_DATA_MANDATORY);
        Boolean mandatory = (mandStr != null && mandStr.toLowerCase() == MADATORY_STR) ? true : false;
        String applyTo = text(node, masterDataField.MASTER_DATA_APPLY_TO);
        applyTo = String.isBlank(applyTo) ? null : applyTo;
        String posOrderStr = text(node, masterDataField.MASTER_DATA_POST_ORDER);
        Integer posOrder = (posOrderStr != null && posOrderStr.trim() != '') ? Integer.valueOf(posOrderStr) : null;



        // Upsert AdditionalProperty
        upsertNode(
            FIELD_TYPE_ADDITIONALPROPERTY, fieldId, parentId, fieldName, nameVN,
            type, mandatory, null, path + ' > ' + fieldName,
            existingMap, upsertMap, integrationChannelId, applyTo, posOrder
        );

        // Available Values
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == FIELD_TYPE_AVAILABELVAL) {
                String valId = text(child, masterDataField.MASTER_DATA_ID);
                String valName = text(child, masterDataField.MASTER_DATA_NAME);
                String valNameVN = text(child, masterDataField.MASTER_DATA_NAMEVN);
                applyTo = text(child, masterDataField.MASTER_DATA_APPLY_TO);
                applyTo = String.isBlank(applyTo) ? null : applyTo;
                posOrderStr = text(child, masterDataField.MASTER_DATA_POST_ORDER);
                posOrder = (posOrderStr != null && posOrderStr.trim() != '') ? Integer.valueOf(posOrderStr) : null;

                upsertNode(
                    FIELD_TYPE_AVAILABELVAL, valId, fieldId,
                    valName, valNameVN,
                    null, null, valId,
                    path + ' > ' + fieldName + ' > ' + valName,
                    existingMap, upsertMap, integrationChannelId, applyTo, posOrder
                );
            }
        }
    }
    
      
    /**
     * Loads all existing Master Data records for a given integration channel
     * and indexes them for fast lookup during the synchronization process.
     *
     * The returned map uses a composite key in the format:
     *   SourceType | SourceId | ParentSourceId
     *
     * This allows the integration engine to quickly determine whether
     * a record already exists (for update) or must be inserted.
     *
     * @param integrationChannelId The integration channel identifier
     * @return A map of existing records keyed by a composite business key
     */

    private static Map<String, FEC_Master_Data_Integration__c> loadExisting(String integrationChannelId) {
        Map<String, FEC_Master_Data_Integration__c> mapData = new Map<String, FEC_Master_Data_Integration__c>();

        for (FEC_Master_Data_Integration__c rec : [
            SELECT 
                FEC_Source_Type__c,
                FEC_Source_Id__c,
                FEC_Source_Parent_Id__c,
                FEC_Source_Name__c,
                FEC_Source_NameVN__c,
                FEC_Source_Field_Type__c,
                FEC_Source_Enum_Value__c,
                FEC_Source_Enum_Label__c,
                FEC_Source_Enum_LabelVN__c,
                FEC_Source_Is_Mandatory__c,
                FEC_Source_Path__c
            FROM FEC_Master_Data_Integration__c
            WHERE FEC_Channel__c = :integrationChannelId
        ]) {
            String key = rec.FEC_Source_Type__c + '|' + rec.FEC_Source_Id__c + '|' + rec.FEC_Source_Parent_Id__c;
            mapData.put(key, rec);
        }
        return mapData;
    }


    /**
     * Creates or updates a single Master Data record in memory for later UPSERT.
     *
     * This method:
     *  • Builds a composite business key for accurate matching
     *  • Reuses existing records when found
     *  • Applies incoming integration values
     *  • Enforces data consistency rules
     *  • Adds the record to the final UPSERT collection
     *
     * @param srcType              Source object type (Category, SubCategory, SubCode, etc.)
     * @param srcId                Unique source identifier
     * @param parentId             Parent source identifier (for hierarchy)
     * @param name                 English display name
     * @param nameVN               Vietnamese display name
     * @param fieldType            Field type for Additional Properties
     * @param mandatory            Mandatory flag for UI validation
     * @param enumValue            Enumeration value (for Available Values)
     * @param fullPath             Full hierarchical path for UI display
     * @param existingMap          Map of existing Salesforce records
     * @param upsertMap            Map collecting records for final UPSERT
     * @param integrationChannelId Integration channel identifier
     * @param applyTo              Optional context where this node applies
     * @param posOrder             Display ordering value
     */
    private static void upsertNode(
    String srcType,
    String srcId,
    String parentId,
    String name,
    String nameVN,
    String fieldType,
    Boolean mandatory,
    String enumValue,
    String fullPath,
    Map<String, FEC_Master_Data_Integration__c> existingMap,
    Map<String, FEC_Master_Data_Integration__c> upsertMap,
    String integrationChannelId,
    String applyTo,
    Integer posOrder
    ) {
        String key = srcType + '|' + srcId + '|' + parentId;
        FEC_Master_Data_Integration__c rec;

        if (existingMap.containsKey(key)) {
            rec = existingMap.get(key);
        } else {
            rec = new FEC_Master_Data_Integration__c();
            rec.FEC_Source_Type__c = srcType;
            rec.FEC_Source_Id__c = srcId;
            rec.FEC_Source_Parent_Id__c = parentId;
        }

        rec.FEC_Source_Name__c = name;
        rec.FEC_Source_NameVN__c = nameVN;
        rec.FEC_Source_Field_Type__c = fieldType;

        // ************* FIX START *************
        // Always enforce boolean
        if (mandatory == null) {
            rec.FEC_Source_Is_Mandatory__c = false;
        } else {
            rec.FEC_Source_Is_Mandatory__c = mandatory;
        }
        // ************* FIX END *************

        rec.FEC_Source_Enum_Value__c = enumValue;
        rec.FEC_Source_Path__c = fullPath;
        rec.FEC_Channel__c = integrationChannelId;
        rec.FEC_ApplyTo__c = applyTo;
        rec.FEC_PosOrder__c = posOrder;

        upsertMap.put(key, rec);
    }

   /**
     * Retrieves the text value of a direct child element by name.
     *
     * @param parent The parent XML node
     * @param name   The child element name to search for
     * @return The text value of the matching child element, or null if not found
     */
    private static String text(Dom.XmlNode parent, String name) {
        for (Dom.XmlNode c : parent.getChildElements())
            if (c.getName() == name) return c.getText();
        return null;
    }

    /**
     * Finds a child node by name while safely ignoring XML namespaces.
     *
     * This allows the parser to handle both:
     *   <Body> and <soap:Body>
     *
     * @param node The parent XML node
     * @param name The expected local name of the child
     * @return The matching child node, or null if not found
     */
    private static Dom.XmlNode getChildIgnoreNS(Dom.XmlNode node, String name) {
        for (Dom.XmlNode c : node.getChildElements())
            if (c.getName() == name ||
                (c.getName().contains(':') && c.getName().endsWith(name)))
                return c;
        return null;
    }

    /**
     * Finds the first child node whose name ends with the specified suffix.
     *
     * Useful for locating response elements that may include dynamic
     * or namespaced prefixes in their XML tag names.
     *
     * @param node   The parent XML node
     * @param suffix The expected ending of the node name
     * @return The matching child node, or null if not found
     */
    private static Dom.XmlNode findChildByEndsWith(Dom.XmlNode node, String suffix) {
        for (Dom.XmlNode c : node.getChildElements())
            if (c.getName().endsWith(suffix)) return c;
        return null;
    }

    /**
     * Retrieves the integration channel code if it is active.
     *
     * This method validates the provided code against active
     * channel configuration records in Salesforce.
     *
     * @param code The expected channel code (e.g. "FIMA")
     * @return The matching channel code if active, otherwise null
     */
    private static String getIntegrationChannelCode(String code) {
        List<FEC_Channel__c> chs = [

            SELECT FEC_Channel_ID__c, FEC_Code__c
            FROM FEC_Channel__c
            WHERE FEC_Channel_Status__c = true
        ];

        for (FEC_Channel__c c : chs) {
            if (c.FEC_Code__c == code) return c.FEC_Code__c;
        }
        return null;
    }

    public static void sendJobEmail(
        String status,
        String jobName,
        String triggerId,
        String cronExpr,
        Datetime nextRun,
        Integer importedCount,
        String durationText,
        Exception ex,
        List<String> recipients
    ) {
        EmailTemplate tpl = [
            SELECT Subject, Body
            FROM EmailTemplate
            WHERE DeveloperName = :TEMPLATE_NAME
            LIMIT 1
        ];

        String errorBlock = '';
        if (ex != null) {
            errorBlock =
                'ERROR:\n' + ex.getMessage() + '\n\n' +
                ex.getStackTraceString();
        }

        String subject = tpl.Subject
            .replace('{{STATUS}}', status)
            .replace('{{JOB_NAME}}', jobName);

        String body = tpl.Body
            .replace('{{JOB_NAME}}', jobName)
            .replace('{{TRIGGER_ID}}', triggerId)
            .replace('{{CRON}}', cronExpr)
            .replace('{{NEXT_RUN}}', String.valueOf(nextRun))
            .replace('{{STATUS}}', status)
            .replace('{{IMPORTED_COUNT}}',
                importedCount == null ? 'N/A' : String.valueOf(importedCount))
            .replace('{{DURATION}}', durationText)
            .replace('{{ERROR_BLOCK}}', errorBlock);

        sendEmail(subject, body, recipients);
    }
    private static void sendEmail(String subject, String body, List<String> toAddresses) {
        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(toAddresses);
            email.setSubject(subject);
            email.setPlainTextBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        } catch (Exception e) {
            System.debug('Email send failed: ' + e.getMessage());
        }
    }
    public static List<String> getAdminRecipients() {
        List<String> emails = new List<String>();
    
        for (FEC_Integration_Admin_Recipient__mdt rec :
            [SELECT FEC_Email__c FROM FEC_Integration_Admin_Recipient__mdt]
        ) {
            if (String.isNotBlank(rec.FEC_Email__c)) {
                emails.add(rec.FEC_Email__c);
            }
        }
        return emails;
    }


    /**
     * Calls external Fraud SOAP service to retrieve Fraud Master Data.
     *
     * This method:
     * 1. Builds a SOAP XML request body.
     * 2. Sets required HTTP headers (Content-Type, SOAPAction).
     * 3. Sends HTTP POST callout to Fraud service endpoint.
     * 4. Returns raw XML response body.
     *
     * @return String
     *         - SOAP XML response body if callout is successful.
     *         - <ERROR>message</ERROR> if exception occurs.
   /**
     * Calls CIF_CustomerInfo SOAP service to retrieve fraud master data.
     *
     * @return SOAP response body as String
     * @throws CalloutException if HTTP callout fails
     */
    public static String getFraudMasterData() {

        Http http = new Http();
        HttpRequest request = new HttpRequest();
    
        try {
            request.setEndpoint(FEC_FraudConstantCommon.SET_ENPOINT_FRAUD_SERVICE);
            request.setMethod('POST');
            request.setTimeout(FEC_FraudConstantCommon.REQUEST_TIMEOUT);

            request.setHeader(
                FEC_FraudConstantCommon.MIME_CONTENT_TYPE,
                FEC_FraudConstantCommon.MIME_TEXT_UTF8
            );
            request.setHeader(
                'SOAPAction',
                FEC_FraudConstantCommon.FRAUD_SERVICE_SOAP_GET_MASTER_ENDPOINT
            );
    
            // ---------------------------------------------------------
            // Build SOAP XML body
            // ---------------------------------------------------------
            String xmlBody =
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<soapenv:Envelope ' +
                    'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                    'xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
                    '<soapenv:Header/>' +
                    '<soapenv:Body>' +
                        '<ns1:GetFraudMasterDataRequest>' +
                            '<ns1:Sys>' +
                                '<ns1:Channel>' +
                                    FEC_FraudConstantCommon.SYSTEM_CHANNEL +
                                '</ns1:Channel>' +
                                '<ns1:TransactionID>' +
                                    FEC_IntegrationFraudCaseUtil.generateUUID() +
                                '</ns1:TransactionID>' +
                                '<ns1:DateTime>' +
                                    Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss') +
                                '</ns1:DateTime>' +
                            '</ns1:Sys>' +
                        '</ns1:GetFraudMasterDataRequest>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>';
            
            request.setBody(xmlBody);
            log('LOG-XML-REQUEST-MASTER-DATA: '+ xmlBody);

            // ---------------------------------------------------------
            // Callout
            // ---------------------------------------------------------
            HttpResponse response = http.send(request);
    
            // ---------------------------------------------------------
            // Return success response
            // ---------------------------------------------------------
            return response.getBody();
    
        } catch (CalloutException ce) {
            log('CalloutException in getFraudMasterData: ' + ce.getMessage()
            );
            return '<ERROR>' + ce.getMessage() + '</ERROR>';
           
    
        } catch (Exception ex) {
            log(
                'Unexpected error in getFraudMasterData: ' + ex.getMessage()
            );
            return '<ERROR>' + ex.getMessage() + '</ERROR>';
           
        }
    }


    /**
     * Calls the external Fraud Case SOAP service
     * to create a new fraud case.
     *
     * This method:
     * - Initializes the generated SOAP service stub
     * - Configures endpoint and timeout settings
     * - Invokes the CreateFraudCase operation
     * - Returns the service response
     *
     * @param sys     System-level metadata (channel, transaction ID, timestamp)
     * @param cust    Customer information section
     * @param req     Fraud case request details
     * @param creator Creator metadata (user initiating the request)
     *
     * @return FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType
     *         SOAP response returned by external system
     *
     * @throws CalloutException if the external service call fails
     */
    public static FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType
    callCreateFraudCaseService(
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper reqWrapper,
        FEC_IntegrationSoapFraudcaseService.SysType sys,
        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust,
        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req,
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator
    ) {
    
        Http http = new Http();
        HttpRequest request = new HttpRequest();
    
        try {
    
            // ---------------------------------------------------------
            // Configure HTTP request
            // ---------------------------------------------------------
            request.setEndpoint(FEC_FraudConstantCommon.SET_ENPOINT_FRAUD_SERVICE);
            request.setMethod('POST');
            request.setTimeout(FEC_FraudConstantCommon.REQUEST_TIMEOUT);
    
            request.setHeader(
                FEC_FraudConstantCommon.MIME_CONTENT_TYPE,
                FEC_FraudConstantCommon.MIME_TEXT_UTF8
            );
    
            request.setHeader(
                'SOAPAction',
                FEC_FraudConstantCommon.FRAUD_SERVICE_SOAP_CREATE_ENDPOINT
            );
    
            // ---------------------------------------------------------
            // Build SOAP XML body (FIXED CALL)
            // ---------------------------------------------------------
            String requestBody = buildCreateFraudCaseBody(
                sys,
                cust,
                req,
                creator
            );
    
            request.setBody(requestBody);
    
            log('SOAP CREATE REQUEST: ' + requestBody);
            Boolean isConnectisConnected  = isConnectFraudSystem();
            log('LOG-callCreateFraudCaseService: ' + isConnectisConnected);
            Integer statusCode = 0;
            String responseBody = null;
            HttpResponse response = null;
            //isConnectisConnected = false;
            if(isConnectisConnected) {
                 // ---------------------------------------------------------
                // Execute callout
                // ---------------------------------------------------------
                response = http.send(request);        
                statusCode = response.getStatusCode();
                responseBody = response.getBody();
        
            } else {
                //For Mockup data
                responseBody = FEC_FraudCaseMockData.responseFailedCreateConnectFraudCase();
                //responseBody = FEC_FraudCaseMockData.responseCreateFraudCase();
                
                statusCode = FEC_FraudConstantCommon.SUCCESSFULL;
                log('LOG-callCreateFraudCaseService MOCKUP: ');
            }
            //Central integration logging
            String serviceName = FEC_FraudConstantCommon.FRAUD_CASE_CREATE_NAME;
            writeLogIntegrationService(serviceName, reqWrapper.channelCode, reqWrapper.caseId, reqWrapper.serviceCaseId, requestBody, responseBody);
    
           
            log('SOAP CREATE STATUS: ' + statusCode);
            log('SOAP CREATE RESPONSE: ' + responseBody);
    
            // ---------------------------------------------------------
            // Validate HTTP status
            // ---------------------------------------------------------
            if (statusCode != FEC_FraudConstantCommon.SUCCESSFULL) {
                throw new CalloutException(
                    'HTTP Error: ' + statusCode + ' - ' + response.getStatus()
                );
            }
    
            // ---------------------------------------------------------
            // Parse SOAP XML Response → Convert to ResponseType
            // ---------------------------------------------------------
            return parseCreateFraudCaseResponse(responseBody);
    
        } catch (CalloutException ce) {
    
            log('CalloutException in callCreateFraudCaseService: ' + ce.getMessage());
            throw ce;
    
        } catch (Exception ex) {
    
            log('Unexpected error in callCreateFraudCaseService: ' + ex.getMessage());
            throw ex;
        }
    }

    public static FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType
    callProcessFraudCaseService(
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper reqWrapper,
        FEC_IntegrationSoapFraudcaseService.SysType sys,
        FEC_IntegrationSoapFraudcaseService.CaseInfoType4 caseInfo,
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator
    ) {
       
    
        Http http = new Http();
        HttpRequest request = new HttpRequest();
    
        try {
    
            // ---------------------------------------------------------
            // Configure HTTP request
            // ---------------------------------------------------------
            request.setEndpoint(FEC_FraudConstantCommon.SET_ENPOINT_FRAUD_SERVICE);
            request.setMethod('POST');
            request.setTimeout(FEC_FraudConstantCommon.REQUEST_TIMEOUT);
    
            request.setHeader(
                FEC_FraudConstantCommon.MIME_CONTENT_TYPE,
                FEC_FraudConstantCommon.MIME_TEXT_UTF8
            );
    
            request.setHeader(
                'SOAPAction',
                FEC_FraudConstantCommon.FRAUD_SERVICE_SOAP_PROCESS_CASE_ENDPOINT
            );
    
            // ---------------------------------------------------------
            // Build SOAP XML body (FIXED CALL)
            // ---------------------------------------------------------
            String requestBody = buildProcessFraudCaseBody(
                sys,
                caseInfo,
                creator
            );
    
            request.setBody(requestBody);
    
            log('SOAP CREATE REQUEST: ' + requestBody);
            Boolean isConnectisConnected  = isConnectFraudSystem();
            log('LOG-callCreateFraudCaseService: ' + isConnectisConnected);
            Integer statusCode = 0;
            String responseBody = null;
            HttpResponse response = null;
            if(isConnectisConnected) {
                 // ---------------------------------------------------------
                // Execute callout
                // ---------------------------------------------------------
                response = http.send(request);        
                statusCode = response.getStatusCode();
                responseBody = response.getBody();
        
            } else {
                //For Mockup data
                //responseBody = FEC_FraudCaseMockData.responseFailedCreateFraudCase();
                statusCode = FEC_FraudConstantCommon.SUCCESSFULL;
                log('LOG-callCreateFraudCaseService MOCKUP: ');
            }
            //Central integration logging
            String serviceName = FEC_FraudConstantCommon.FRAUD_CASE_PROCESS_NAME;
            writeLogIntegrationService(serviceName, reqWrapper.channelCode, reqWrapper.caseId, reqWrapper.serviceCaseId, requestBody, responseBody);
    
           
            log('SOAP CREATE STATUS: ' + statusCode);
            log('SOAP CREATE RESPONSE: ' + responseBody);
    
            // ---------------------------------------------------------
            // Validate HTTP status
            // ---------------------------------------------------------
            if (statusCode != FEC_FraudConstantCommon.SUCCESSFULL) {
                throw new CalloutException(
                    'HTTP Error: ' + statusCode + ' - ' + response.getStatus()
                );
            }
    
            // ---------------------------------------------------------
            // Parse SOAP XML Response → Convert to ResponseType
            // ---------------------------------------------------------
            return parseProcessFraudCaseResponse(responseBody);
    
        } catch (CalloutException ce) {
    
            log('CalloutException in callCreateFraudCaseService: ' + ce.getMessage());
            throw ce;
    
        } catch (Exception ex) {
    
            log('Unexpected error in callCreateFraudCaseService: ' + ex.getMessage());
            throw ex;
        }
    }

    public static FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType
    callUpdateFraudCaseService(
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper reqWrapper,
        FEC_IntegrationSoapFraudcaseService.SysType sys,
        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust,
        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req,
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator
    ) {
    
        Http http = new Http();
        HttpRequest request = new HttpRequest();
    
        try {
    
            // ---------------------------------------------------------
            // Configure HTTP request
            // ---------------------------------------------------------
            request.setEndpoint(FEC_FraudConstantCommon.SET_ENPOINT_FRAUD_SERVICE);
            request.setMethod('POST');
            request.setTimeout(FEC_FraudConstantCommon.REQUEST_TIMEOUT);
    
            request.setHeader(
                FEC_FraudConstantCommon.MIME_CONTENT_TYPE,
                FEC_FraudConstantCommon.MIME_TEXT_UTF8
            );
    
            request.setHeader(
                'SOAPAction',
                FEC_FraudConstantCommon.FRAUD_SERVICE_SOAP_CREATE_ENDPOINT
            );
    
            // ---------------------------------------------------------
            // Build SOAP XML body (FIXED CALL)
            // ---------------------------------------------------------
            String requestBody = buildCreateFraudCaseBody(
                sys,
                cust,
                req,
                creator
            );
    
            request.setBody(requestBody);
    
            log('SOAP UPDATE REQUEST: ' + requestBody);
            Boolean isConnectisConnected  = isConnectFraudSystem();
            log('LOG-callUpdateFraudCaseService: ' + isConnectisConnected);
            Integer statusCode = 0;
            String responseBody = null;
            HttpResponse response = null;
            if(isConnectisConnected) {
                 // ---------------------------------------------------------
                // Execute callout
                // ---------------------------------------------------------
                response = http.send(request);        
                statusCode = response.getStatusCode();
                responseBody = response.getBody();
        
            } else {
                //For Mockup data
                responseBody = FEC_FraudCaseMockData.responseFailedCreateConnectFraudCase();
                statusCode = FEC_FraudConstantCommon.SUCCESSFULL;
                log('LOG-callUpdateFraudCaseService MOCKUP: ');
            }
            //Central integration logging
            String serviceName = FEC_FraudConstantCommon.FRAUD_CASE_UPDATE_NAME;
            writeLogIntegrationService(serviceName, reqWrapper.channelCode, reqWrapper.caseId, reqWrapper.serviceCaseId, requestBody, responseBody);
    
           
            log('SOAP UPDATE STATUS: ' + statusCode);
            log('SOAP UPDATE RESPONSE: ' + responseBody);
    
            // ---------------------------------------------------------
            // Validate HTTP status
            // ---------------------------------------------------------
            if (statusCode != FEC_FraudConstantCommon.SUCCESSFULL) {
                throw new CalloutException(
                    'HTTP Error: ' + statusCode + ' - ' + response.getStatus()
                );
            }
    
            // ---------------------------------------------------------
            // Parse SOAP XML Response → Convert to ResponseType
            // ---------------------------------------------------------
            return parseCreateFraudCaseResponse(responseBody);
    
        } catch (CalloutException ce) {
    
            log('CalloutException in callUpdateFraudCaseService: ' + ce.getMessage());
            throw ce;
    
        } catch (Exception ex) {
    
            log('Unexpected error in callUpdateFraudCaseService: ' + ex.getMessage());
            throw ex;
        }
    }

    /**
     * Calls the external Fraud Case SOAP service to cancel an existing fraud case.
     *
     * This method:
     * - Builds SOAP XML request body
     * - Configures HTTP callout (endpoint, headers, timeout)
     * - Executes callout (or uses mock response if integration disabled)
     * - Validates HTTP status code
     * - Parses SOAP XML response into CancelFraudCaseResponseType
     *
     * Integration Flow:
     * 1. Build SOAP body via buildCancelFraudCaseBody(...)
     * 2. Send HTTP POST request
     * 3. Validate HTTP response code
     * 4. Parse SOAP response
     *
     * @param sys      System metadata (Channel, TransactionID, DateTime)
     * @param caseIfo  Case information to cancel
     * @param creator  User performing the cancel action
     *
     * @return FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType
     *         parsed SOAP response object
     *
     * @throws CalloutException when HTTP status is not successful
     * @throws Exception for unexpected processing errors
     */
    public static FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType
    callCancelFraudCaseService(
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper reqWrapper,
        FEC_IntegrationSoapFraudcaseService.SysType sys,
        FEC_IntegrationSoapFraudcaseService.CaseInfoType caseIfo,
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator
    ) {
    
        Http http = new Http();
        HttpRequest request = new HttpRequest();
    
        try {
    
            // ---------------------------------------------------------
            // Configure HTTP request
            // ---------------------------------------------------------
            request.setEndpoint(FEC_FraudConstantCommon.SET_ENPOINT_FRAUD_SERVICE);
            request.setMethod('POST');
            request.setTimeout(FEC_FraudConstantCommon.REQUEST_TIMEOUT);
    
            request.setHeader(
                FEC_FraudConstantCommon.MIME_CONTENT_TYPE,
                FEC_FraudConstantCommon.MIME_TEXT_UTF8
            );
    
            request.setHeader(
                'SOAPAction',
                FEC_FraudConstantCommon.FRAUD_SERVICE_SOAP_CANCEL_ENDPOINT
            );
    
            // ---------------------------------------------------------
            // Build SOAP XML body (FIXED CALL)
            // ---------------------------------------------------------
            String requestBody = buildCancelFraudCaseBody(
                sys,
                caseIfo,
                creator
            );
    
            request.setBody(requestBody);
    
            log('SOAP CANCEL REQUEST: ' + requestBody);
            Boolean isConnectisConnected  = isConnectFraudSystem();
            log('LOG-callCancelFraudCaseService: ' + isConnectisConnected);
            Integer statusCode = 0;
            String responseBody = null;
            HttpResponse response = null;
            if(isConnectisConnected) {
                 // ---------------------------------------------------------
                // Execute callout
                // ---------------------------------------------------------
                response = http.send(request);        
                statusCode = response.getStatusCode();
                responseBody = response.getBody();
        
            } else {
                //For Mockup data
                responseBody = FEC_FraudCaseMockData.responseFailedCancelConnectFraudCase();
                statusCode = FEC_FraudConstantCommon.SUCCESSFULL;
                log('LOG-callCancelFraudCaseService MOCKUP: ');
            }
            //Central integration logging
            String serviceName = FEC_FraudConstantCommon.FRAUD_CASE_CANCEL_NAME;
            writeLogIntegrationService(serviceName, reqWrapper.channelCode, reqWrapper.caseId, reqWrapper.serviceCaseId, requestBody, responseBody);
    
           
            log('SOAP CANCEL STATUS: ' + statusCode);
            log('SOAP CANCEL RESPONSE: ' + responseBody);
    
            // ---------------------------------------------------------
            // Validate HTTP status
            // ---------------------------------------------------------
            if (statusCode != FEC_FraudConstantCommon.SUCCESSFULL) {
                throw new CalloutException(
                    'HTTP Error: ' + statusCode + ' - ' + response.getStatus()
                );
            }
    
            // ---------------------------------------------------------
            // Parse SOAP XML Response → Convert to ResponseType
            // ---------------------------------------------------------
            return parseCancelFraudCaseResponse(responseBody);
    
        } catch (CalloutException ce) {
    
            log('CalloutException in callCancelFraudCaseService: ' + ce.getMessage());
            throw ce;
    
        } catch (Exception ex) {
    
            log('Unexpected error in callCancelFraudCaseService: ' + ex.getMessage());
            throw ex;
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
        String responseXml
    ) {
        try {
            // Call centralized logging utility
            FEC_IntegrationFraudCaseUtil.logIntegrationService(
                serviceName,
                channelId,
                caseId,
                serviceCaseId,
                requestBody,
                responseXml
            );
 
            // Log success for debugging & monitoring
            log('SUCCESS - writeLogIntegrationService');
 
        } catch (Exception ex) {
            // Never allow logging errors to interrupt main transaction
            log('ERROR - writeLogIntegrationService: ' + ex.getMessage());
        }
    } 

    private static FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType
    parseCreateFraudCaseResponse(String xmlResponse) {

        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType result =
            new FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType();
        FEC_FraudConstantCommon.IntegrationMappingField responseField = new FEC_FraudConstantCommon.IntegrationMappingField();

        String NS_SOAP = FEC_FraudConstantCommon.FRAUD_SERVICE_SOAP_NS_SOAP;
        String NS_URN  = FEC_FraudConstantCommon.FRAUD_SERVICE_SOAP_NS_URN;

        Dom.Document doc = new Dom.Document();
        doc.load(xmlResponse);

        Dom.XmlNode envelope = doc.getRootElement();
        Dom.XmlNode body = envelope.getChildElement('Body', NS_SOAP);

        if (body == null) return result;

        // Get CreateFraudCaseResponse node
        Dom.XmlNode responseNode =
            body.getChildElement('CreateFraudCaseResponse', NS_URN);

        if (responseNode == null) return result;

        // ======================
        // Parse CaseID
        // ======================
        Dom.XmlNode caseIdNode =
            responseNode.getChildElement('CaseID', NS_URN);

        if (caseIdNode != null) {
            result.CaseID = caseIdNode.getText();
        }

        // ======================
        // Parse Sys block
        // ======================
        Dom.XmlNode sysNode =
            responseNode.getChildElement('Sys', NS_URN);

        if (sysNode != null) {

            result.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();

            Dom.XmlNode codeNode =
                sysNode.getChildElement('Code', NS_URN);

            Dom.XmlNode descNode =
                sysNode.getChildElement('Description', NS_URN);

            if (codeNode != null) {
                result.Sys.Code = codeNode.getText();
            }

            if (descNode != null) {
                result.Sys.Description = descNode.getText();
            }
        }

        return result;
    }

    private static FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType
    parseProcessFraudCaseResponse(String xmlResponse) {

        FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType result =
            new FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType();
        FEC_FraudConstantCommon.IntegrationMappingField responseField = new FEC_FraudConstantCommon.IntegrationMappingField();

        // String NS_SOAP = FEC_FraudConstantCommon.FRAUD_SERVICE_SOAP_NS_SOAP;
        // String NS_URN  = FEC_FraudConstantCommon.FRAUD_SERVICE_SOAP_NS_URN;

        // Dom.Document doc = new Dom.Document();
        // doc.load(xmlResponse);

        // Dom.XmlNode envelope = doc.getRootElement();
        // Dom.XmlNode body = envelope.getChildElement('Body', NS_SOAP);

        // if (body == null) return result;

        // // Get CreateFraudCaseResponse node
        // Dom.XmlNode responseNode =
        //     body.getChildElement('CreateFraudCaseResponse', NS_URN);

        // if (responseNode == null) return result;

        // // ======================
        // // Parse CaseID
        // // ======================
        // Dom.XmlNode caseIdNode =
        //     responseNode.getChildElement('CaseID', NS_URN);

        // if (caseIdNode != null) {
        //     result.CaseID = caseIdNode.getText();
        // }

        // // ======================
        // // Parse Sys block
        // // ======================
        // Dom.XmlNode sysNode =
        //     responseNode.getChildElement('Sys', NS_URN);

        // if (sysNode != null) {

        //     result.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();

        //     Dom.XmlNode codeNode =
        //         sysNode.getChildElement('Code', NS_URN);

        //     Dom.XmlNode descNode =
        //         sysNode.getChildElement('Description', NS_URN);

        //     if (codeNode != null) {
        //         result.Sys.Code = codeNode.getText();
        //     }

        //     if (descNode != null) {
        //         result.Sys.Description = descNode.getText();
        //     }
        // }

        return result;
    }

    private static FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType
    parseCancelFraudCaseResponse(String xmlResponse) {

        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType result =
            new FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType();
        FEC_FraudConstantCommon.IntegrationMappingField responseField = new FEC_FraudConstantCommon.IntegrationMappingField();

        String NS_SOAP = FEC_FraudConstantCommon.FRAUD_SERVICE_SOAP_NS_SOAP;
        String NS_URN  = FEC_FraudConstantCommon.FRAUD_SERVICE_SOAP_NS_URN;

        Dom.Document doc = new Dom.Document();
        doc.load(xmlResponse);

        Dom.XmlNode envelope = doc.getRootElement();
        Dom.XmlNode body = envelope.getChildElement('Body', NS_SOAP);

        if (body == null) return result;

        // Get CancelFraudCaseResponse node
        Dom.XmlNode responseNode =
            body.getChildElement('CancelFraudCaseResponse', NS_URN);

        if (responseNode == null) return result;

        // ======================
        // Parse CaseID
        // ======================
        Dom.XmlNode caseIdNode =
            responseNode.getChildElement('CaseID', NS_URN);

        if (caseIdNode != null) {
            result.CaseID = caseIdNode.getText();
        }

        // ======================
        // Parse Sys block
        // ======================
        Dom.XmlNode sysNode =
            responseNode.getChildElement('Sys', NS_URN);

        if (sysNode != null) {

            result.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();

            Dom.XmlNode codeNode =
                sysNode.getChildElement('Code', NS_URN);

            Dom.XmlNode descNode =
                sysNode.getChildElement('Description', NS_URN);

            if (codeNode != null) {
                result.Sys.Code = codeNode.getText();
            }

            if (descNode != null) {
                result.Sys.Description = descNode.getText();
            }
        }

        return result;
    }

    
    /**
     * Builds the raw SOAP XML body for CreateFraudCase request.
     *
     * This method manually constructs the SOAP Envelope including:
     * - Sys block (Required)
     * - CustomerInfo block (Optional)
     * - RequestInfo block (Optional, including AdditionalInfo list)
     * - CreatorInfo block (Optional)
     *
     * Notes:
     * - Null values are handled via buildTag() helper method
     * - DateTime is formatted in GMT (ISO-8601 format)
     * - Optional sections are included only when data is present
     *
     * @param sys     System metadata (required block)
     * @param cust    Customer information (optional)
     * @param req     Fraud request information (optional)
     * @param creator Creator metadata (optional)
     *
     * @return Fully constructed SOAP XML request body as String
     */
    private static String buildCreateFraudCaseBody(
        FEC_IntegrationSoapFraudcaseService.SysType sys,
        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust,
        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req,
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator
    ) {

        // Initialize SOAP Envelope
        String xml = 
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope ' +
                'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
                '<soapenv:Header/>' +
                '<soapenv:Body>' +
                    '<ns1:CreateFraudCaseRequest>';

        // =========================
        // SYS (Required Section)
        // =========================
        xml += '<ns1:Sys>' +
                FEC_IntegrationFraudCaseUtil.buildTag('Channel', sys != null ? sys.Channel : null) +
                FEC_IntegrationFraudCaseUtil.buildTag('TransactionID', sys != null ? sys.TransactionID : null) +
                FEC_IntegrationFraudCaseUtil.buildTag(
                    'DateTime',
                    sys != null && sys.DateTime_x != null
                        ? sys.DateTime_x.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss')
                        : null
                ) +
            '</ns1:Sys>';

        // =========================
        // CUSTOMER INFO (Optional)
        // Included only when UserType exists
        // =========================
        if (cust != null && String.isNotBlank(cust.UserType)) {
            xml += '<ns1:CustomerInfo>' +
                    FEC_IntegrationFraudCaseUtil.buildTag('UserType', cust.UserType) +
                '</ns1:CustomerInfo>';
        }

        // =========================
        // REQUEST INFO (Optional Block)
        // Contains main fraud classification and additional info
        // =========================
        if (req != null) {

            String requestBlock = '';

            // Basic fraud classification fields
            //Check caseID existing for update
            if (String.isNotBlank(req.CaseID)) {     
                 requestBlock += FEC_IntegrationFraudCaseUtil.buildTag('CaseID', req.CaseID);
            }
         
            requestBlock += FEC_IntegrationFraudCaseUtil.buildTag('CaseType', req.CaseType);
            requestBlock += FEC_IntegrationFraudCaseUtil.buildTag('ProductType', req.ProductType);
            requestBlock += FEC_IntegrationFraudCaseUtil.buildTag('Category', req.Category);
            requestBlock += FEC_IntegrationFraudCaseUtil.buildTag('SubCategory', req.SubCategory);
            requestBlock += FEC_IntegrationFraudCaseUtil.buildTag('SubCode', req.SubCode);
            requestBlock += FEC_IntegrationFraudCaseUtil.buildTag('Remarks', req.Remarks);

            // AdditionalInfo elements (0..n)
            if (req.AdditionalInfo != null && !req.AdditionalInfo.isEmpty()) {

                for (FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element ai 
                    : req.AdditionalInfo) {

                    requestBlock +=
                        '<ns1:AdditionalInfo>' +
                            FEC_IntegrationFraudCaseUtil.buildTag('ID', ai.ID) +
                            FEC_IntegrationFraudCaseUtil.buildTag('Value', ai.Value) +
                        '</ns1:AdditionalInfo>';
                }
            }

            // Append RequestInfo block only if it contains data
            if (String.isNotBlank(requestBlock)) {
                xml += '<ns1:RequestInfo>' + requestBlock + '</ns1:RequestInfo>';
            }
        }

        // =========================
        // CREATOR INFO (Optional)
        // =========================
        if (creator != null && String.isNotBlank(creator.CreatorEmail)) {
            xml += '<ns1:CreatorInfo>' +
                    FEC_IntegrationFraudCaseUtil.buildTag('CreatorEmail', creator.CreatorEmail) +
                '</ns1:CreatorInfo>';
        }

        // Close SOAP Envelope
        xml +=
                    '</ns1:CreateFraudCaseRequest>' +
                '</soapenv:Body>' +
            '</soapenv:Envelope>';

        return xml;
    }

    private static String buildCancelFraudCaseBody(
        FEC_IntegrationSoapFraudcaseService.SysType sys,
        FEC_IntegrationSoapFraudcaseService.CaseInfoType caseIfo,
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator
    ) {

        // Initialize SOAP Envelope
        String xml = 
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope ' +
                'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
                '<soapenv:Header/>' +
                '<soapenv:Body>' +
                    '<ns1:CancelFraudCaseRequest>';

        // =========================
        // SYS (Required Section)
        // =========================
        xml += '<ns1:Sys>' +
                FEC_IntegrationFraudCaseUtil.buildTag('Channel', sys != null ? sys.Channel : null) +
                FEC_IntegrationFraudCaseUtil.buildTag('TransactionID', sys != null ? sys.TransactionID : null) +
                FEC_IntegrationFraudCaseUtil.buildTag(
                    'DateTime',
                    sys != null && sys.DateTime_x != null
                        ? sys.DateTime_x.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss')
                        : null
                ) +
            '</ns1:Sys>';

        // =========================
        // CASE INFO (Optional)        
        // =========================
        if (caseIfo != null && String.isNotBlank(caseIfo.CaseID)) {
            xml += '<ns1:CaseInfo>' +
                    FEC_IntegrationFraudCaseUtil.buildTag('CaseID', caseIfo.CaseID) +
                    FEC_IntegrationFraudCaseUtil.buildTag('Remarks', caseIfo.Remarks) +
                '</ns1:CaseInfo>';
        }


        // =========================
        // CREATOR INFO (Optional)
        // =========================
        if (creator != null && String.isNotBlank(creator.CreatorEmail)) {
            xml += '<ns1:CreatorInfo>' +
                    FEC_IntegrationFraudCaseUtil.buildTag('CreatorEmail', creator.CreatorEmail) +
                '</ns1:CreatorInfo>';
        }

        // Close SOAP Envelope
        xml +=
                    '</ns1:CancelFraudCaseRequest>' +
                '</soapenv:Body>' +
            '</soapenv:Envelope>';

        return xml;
    }

    private static String buildProcessFraudCaseBody(
        FEC_IntegrationSoapFraudcaseService.SysType sys,
        FEC_IntegrationSoapFraudcaseService.CaseInfoType4 caseIfo,
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator
    ) {

        // Initialize SOAP Envelope
        String xml = 
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope ' +
                'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
                '<soapenv:Header/>' +
                '<soapenv:Body>' +
                    '<ns1:ProcessCaseRequest>';

        // =========================
        // SYS (Required Section)
        // =========================
        xml += '<ns1:Sys>' +
                FEC_IntegrationFraudCaseUtil.buildTag('Channel', sys != null ? sys.Channel : null) +
                FEC_IntegrationFraudCaseUtil.buildTag('TransactionID', sys != null ? sys.TransactionID : null) +
                FEC_IntegrationFraudCaseUtil.buildTag(
                    'DateTime',
                    sys != null && sys.DateTime_x != null
                        ? sys.DateTime_x.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss')
                        : null
                ) +
            '</ns1:Sys>';

        // =========================
        // CASE INFO (Optional)        
        // =========================
        if (caseIfo != null && String.isNotBlank(caseIfo.CaseID)) {
            xml += '<ns1:CaseInfo>' +
                    FEC_IntegrationFraudCaseUtil.buildTag('CaseID', caseIfo.CaseID) +
                    FEC_IntegrationFraudCaseUtil.buildTag('Decision', caseIfo.Decision) +
                    FEC_IntegrationFraudCaseUtil.buildTag('SubDecision', caseIfo.SubDecision) +
                    FEC_IntegrationFraudCaseUtil.buildTag('Reason', caseIfo.Reason) +                    
                    FEC_IntegrationFraudCaseUtil.buildTag('Remarks', caseIfo.Remarks) +
                '</ns1:CaseInfo>';
        }


        // =========================
        // CREATOR INFO (Optional)
        // =========================
        if (creator != null && String.isNotBlank(creator.CreatorEmail)) {
            xml += '<ns1:CreatorInfo>' +
                    FEC_IntegrationFraudCaseUtil.buildTag('CreatorEmail', creator.CreatorEmail) +
                '</ns1:CreatorInfo>';
        }

        // Close SOAP Envelope
        xml +=
                    '</ns1:ProcessCaseRequest>' +
                '</soapenv:Body>' +
            '</soapenv:Envelope>';

        return xml;
    }



    public static Boolean isConnectFraudSystem() {        
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();        
            // 1. Set Endpoint và Method        
            request.setEndpoint(FEC_FraudConstantCommon.SET_ENPOINT_FRAUD_HEALTH);        
            request.setMethod('GET');        
            request.setHeader('X-API-KEY', FEC_FraudConstantCommon.FRAUD_X_API_KEY);        
            request.setTimeout(20000); // Tăng timeout lên 20s        
            HttpResponse response = http.send(request);
            log('STATUS CODE: ' + response.getStatusCode());
            System.debug(LoggingLevel.INFO, 'STATUS CODE: ' + response.getStatusCode());
            System.debug(LoggingLevel.INFO, 'BODY: ' + response.getBody());
            log('BODY: ' + response.getBody());        
            if (response.getStatusCode() == 200) {
                log('Connected FIMA System');
                return true;
            
            }  else {
                log('Connect Failed FIMA System: ' + response.getStatus());
                return false;
        
            }
        
        } catch (Exception e) {       

            log('Connect Failed (Timeout/DNS): ' + e.getMessage());     
            return false;
        
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
}