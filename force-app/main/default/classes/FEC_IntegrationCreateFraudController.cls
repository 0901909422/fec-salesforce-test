/**
 * Controller for Integration Mapping screen
 * - Provide hierarchy data (UserType → Channel → Product → ...)
 * - Provide additional property mapping data
 */
public with sharing class FEC_IntegrationCreateFraudController{
 
    public static final Boolean DEBUG_LOG = true;   
    
    public static final String INIT_CASE_STATUS = FEC_FraudConstantCommon.NEW_STATUS;
    public static final String CANCEL_CASE_STATUS = FEC_FraudConstantCommon.CANCELED;
    public static final String ERR_MISS_FRAUD_CASE = System.Label.Err_Missing_Fraud_Case;
    public static final String MSG_CANCEL_SUCCESS = System.Label.Msg_Cancel_Success;
    public static final String MSG_CANCEL_FAILED  = System.Label.Msg_Cancel_Failed;
    public static final String MSG_CREATE_SUCCESS = System.Label.Msg_Create_Success;
    public static final String MSG_CREATE_FAILED  = System.Label.Msg_Create_Failed;
    public static final String MSG_UPDATE_SUCCESS = System.Label.Msg_Update_Success;
    public static final String MSG_UPDATE_FAILED  = System.Label.Msg_Update_Failed;
    public static final String ERR_SYSTEM         = System.Label.Err_System;
    public static final String CONTENT_VISIBILITY = 'AllUsers';
    

    public static final String userLang = UserInfo.getLanguage();
  
    /**
     * Generic DTO for hierarchy nodes
     * Used by lightning-combobox
     */
    public class NodeDTO {
        @AuraEnabled public String label; // Display text in combobox
        @AuraEnabled public String value; // Actual value (Id / Code)

        public NodeDTO(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

     /**
     * DTO for Additional Property mapping table
     */
    public class PropertyDTO {
        @AuraEnabled public Id id;                    // Record Id
        @AuraEnabled public String property;          // Integrating Property code
        @AuraEnabled public String displayName;       // Vietnamese/English display name
        @AuraEnabled public String type;              // Data type (string, list, file...)
        @AuraEnabled public Boolean mandatory;        // Mandatory flag       
        @AuraEnabled public List<AvailableValueDTO> availableValues;
    }

    public class FraudPropertyDTO {
        @AuraEnabled public String intChannel;                   
        @AuraEnabled public String intUserType;          
        @AuraEnabled public String intProductLine;       
        @AuraEnabled public String intServiceType;              
        @AuraEnabled public String intCategory;
        @AuraEnabled public String intSubCategory;
        @AuraEnabled public String intSubCode;
        @AuraEnabled public List<PropertyDTO> propertyValues;
    }


    public class AvailableValueDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String displayName;
        @AuraEnabled public String property;
    }

    

    @AuraEnabled(cacheable=true)
    public static FEC_IntegrationFraudCaseUtil.CategoryMappingResponse loadCategoryMapping(String channelCode) {
    
        FEC_IntegrationFraudCaseUtil.CategoryMappingResponse res =
            new FEC_IntegrationFraudCaseUtil.CategoryMappingResponse();
        FEC_FraudConstantCommon.IntegrationMappingField integrationField = new FEC_FraudConstantCommon.IntegrationMappingField();
    
        List<Map<String, Object>> categoryMock =
            FEC_FraudCaseMockData.getCategoryMockupData() != null
            ? FEC_FraudCaseMockData.getCategoryMockupData()
            : new List<Map<String, Object>>();
    
        List<Map<String, Object>> subCategoryMock =
            FEC_FraudCaseMockData.getSubCategoryMockupData() != null
            ? FEC_FraudCaseMockData.getSubCategoryMockupData()
            : new List<Map<String, Object>>();
    
        List<Map<String, Object>> subCodeMock =
            FEC_FraudCaseMockData.getCategorySubCodeMockupData() != null
            ? FEC_FraudCaseMockData.getCategorySubCodeMockupData()
            : new List<Map<String, Object>>();
    
        for (Map<String, Object> row : categoryMock) {
            log('categoryMock: '+ row);
            res.categoryAll.add(
                FEC_IntegrationFraudCaseUtil.buildDTO(
                    null,
                    (String) row.get(integrationField.NODE_LABEL),
                    null,
                    (String) row.get(integrationField.NODE_VALUE),
                    (String) row.get(integrationField.SOURCE_MAPPING_ID),
                    FEC_FraudConstantCommon.CATEGORY_KEY
                )
            );
        }
    
        for (Map<String, Object> row : subCategoryMock) {
            log('subCategoriesAll: '+ row);
            res.subCategoriesAll.add(
                FEC_IntegrationFraudCaseUtil.buildDTO(
                    null,
                    (String) row.get(integrationField.NODE_LABEL),
                    (String) row.get(integrationField.NODE_PARENT_ID),
                    (String) row.get(integrationField.NODE_VALUE),
                    (String) row.get(integrationField.SOURCE_MAPPING_ID),
                    FEC_FraudConstantCommon.SUBCATEGORY_KEY
                )
            );
        }
    
        for (Map<String, Object> row : subCodeMock) {
            res.subCodesAll.add(
                FEC_IntegrationFraudCaseUtil.buildDTO(
                    null,
                    (String) row.get(integrationField.NODE_LABEL),
                    (String) row.get(integrationField.NODE_PARENT_ID),
                    (String) row.get(integrationField.NODE_VALUE),
                    (String) row.get(integrationField.SOURCE_MAPPING_ID),
                    FEC_FraudConstantCommon.SUBCODE_KEY
                )
            );
        }
    
        return res;
    }

    
    @AuraEnabled(cacheable=true)
    public static String getMasterDataForUI() {
         // Build UI-friendly structure
       Map<String, Object> ui = buildUiMCreateFraudCaseData();
       return JSON.serializePretty(ui);
       
    }
    /**
     * Loads all active channels for UI selection.
     *
     * This method retrieves enabled channels and converts them into
     * NodeDTO format for use in Lightning components.
     *
     * Marked cacheable for improved UI performance.
     *
     * @return List of NodeDTO representing channels
     */
    @AuraEnabled(cacheable=true)
    public static List<NodeDTO> loadChannelList() {
        //Detect user language       
        Boolean isVietnamese = userLang != null && userLang.startsWith(FEC_FraudConstantCommon.LANG_VI);
        // List to store queried records
        List<FEC_Channel__c> records;
        records = [
            SELECT Id,
            FEC_Channel_ID__c,
            Name,          
            FEC_Channel_Vietnamese_name__c
            FROM FEC_Channel__c
            WHERE FEC_Status__c = True
        ];

        // Convert queried records to NodeDTO list
        List<NodeDTO> result = new List<NodeDTO>();
        for (FEC_Channel__c r : records) {
            String displayName = isVietnamese
            ? r.FEC_Channel_Vietnamese_name__c
            : r.Name;
            result.add(
                new NodeDTO(
                    displayName, // label
                    r.FEC_Channel_ID__c      // value
                )
            );
        }

        return result;
    }

    /* =====================================================
     * LOAD HIERARCHY DATA
     * Generic method used for:
     * UserType, Channel, Product, ServiceType, Category,
     * SubCategory, SubCode
     * ===================================================== */

     @AuraEnabled(cacheable=true)
     public static List<NodeDTO> loadMasterDataIntegration(String sourceType, String parentId, String channelCode) {
 
         // List to store queried records
         List<NodeDTO> result = loadHierarchyMasterInt(sourceType, parentId, channelCode);
         return result;
     }

     @AuraEnabled(cacheable=true)
     public static FraudPropertyDTO loadMasterDataIntegrationMappingById(String integrationMappingId) {
 
         // List to store queried records
         FraudPropertyDTO result = getDataIntegrationMapping(integrationMappingId);
         return result;
     }

     /**
 * Retrieves Integration Mapping data by Id and converts it into FraudPropertyDTO.
 *
 * @param integrationMappingId  Id of FEC_Data_Integration_Mapping__c record
 * @return FraudPropertyDTO     DTO containing integration mapping information
 */
private static FraudPropertyDTO getDataIntegrationMapping(String integrationMappingId) {

    // Initialize result DTO object
    FraudPropertyDTO resultData = new FraudPropertyDTO();

    // Query integration mapping record by Id
    List<FEC_Data_Integration_Mapping__c> existIntegrationMapping = [
        SELECT Id,
               FEC_User_Type_Id__c,
               FEC_Int_Channel__c,
               FEC_Int_User_Type_Id__c,
               FEC_Int_Product_Line_Id__c,
               FEC_Int_Service_Type_Id__c,
               FEC_Int_Category_Id__c,
               FEC_Int_Sub_Category_Id__c,
               FEC_Int_Sub_Code_Id__c
        FROM FEC_Data_Integration_Mapping__c
        WHERE Id = :integrationMappingId
        LIMIT 1
    ];

    // Proceed only if mapping record exists
    if (!existIntegrationMapping.isEmpty()) {

        // Get the first (and only) mapping record
        FEC_Data_Integration_Mapping__c mapping = existIntegrationMapping[0];

        // Variable to store Integration User Type Code
        String intUserType;
        
        // If Integration User Type lookup is not null, retrieve its code
        if (mapping.FEC_Int_User_Type_Id__c != null) {

            List<FEC_User_Type__c> existUserType = [
                SELECT FEC_Code__c
                FROM FEC_User_Type__c
                WHERE Id = :mapping.FEC_Int_User_Type_Id__c
                LIMIT 1
            ];

            // If related User Type record exists, get its FEC_Code__c
            if (!existUserType.isEmpty()) {
                intUserType = existUserType[0].FEC_Code__c;
            }
        }

        // Map integration fields from object to DTO
        resultData.intChannel      = mapping.FEC_Int_Channel__c;
        resultData.intUserType     = intUserType;
        resultData.intProductLine  = mapping.FEC_Int_Product_Line_Id__c;
        resultData.intServiceType  = mapping.FEC_Int_Service_Type_Id__c;

        resultData.intCategory     = mapping.FEC_Int_Category_Id__c;
        resultData.intSubCategory  = mapping.FEC_Int_Sub_Category_Id__c;
        resultData.intSubCode      = mapping.FEC_Int_Sub_Code_Id__c;

        // Load additional dynamic properties based on mapping configuration
        resultData.propertyValues =
            loadAdditionalProperties(
                mapping.FEC_Int_Category_Id__c,
                mapping.FEC_Int_Sub_Category_Id__c,
                mapping.FEC_Int_Sub_Code_Id__c,
                mapping.FEC_Int_Channel__c,
                mapping.FEC_Int_Service_Type_Id__c
            );
    }

    // Return populated (or empty) DTO
    return resultData;
}

     /* =====================================================
     * LOAD ADDITIONAL PROPERTIES
     * Load mapping fields for selected Category/SubCategory/SubCode
     * ===================================================== */
    @AuraEnabled(cacheable=true)
    public static List<PropertyDTO> loadAdditionalProperties(
    String category,
    String subCategory,
    String subCode,
    String channelCode,
    String serviceType
    ) {
        log('[START] loadAdditionalProperties'
            + ' | category=' + category
            + ' | subCategory=' + subCategory
            + ' | subCode=' + subCode
            + ' | channelCode=' + channelCode
        );
        FEC_FraudConstantCommon.IntegrationFieldType caseFileType = new FEC_FraudConstantCommon.IntegrationFieldType();

        List<PropertyDTO> result = new List<PropertyDTO>();
        Boolean isVietnamese = userLang != null && userLang.startsWith(FEC_FraudConstantCommon.LANG_VI);

        //Query AdditionalProperty
        List<FEC_Master_Data_Integration__c> props = [
            SELECT Id,
                FEC_Source_Id__c,
                FEC_Source_NameVN__c,
                FEC_Source_Field_Type__c,
                FEC_Source_Name__c,
                FEC_Source_Is_Mandatory__c
            FROM FEC_Master_Data_Integration__c
            WHERE FEC_Source_Type__c = :FEC_FraudConstantCommon.KEY_ADDITIONAL_PROPERTY
            AND FEC_Channel__c = :channelCode
            AND (
                FEC_Source_Parent_Id__c = :subCode
                OR FEC_Source_Parent_Id__c = :category
                OR FEC_Source_Parent_Id__c = :subCategory
                OR FEC_Source_Parent_Id__c = :serviceType
            )
            ORDER BY FEC_Source_Id__c
        ];

        log('[QUERY] AdditionalProperty count=' + props.size());

        //Collect LIST-type property KEYS (Source_Id)
        Set<String> listPropKeys = new Set<String>();
        for (FEC_Master_Data_Integration__c p : props) {
            if (p.FEC_Source_Field_Type__c == caseFileType.TYPE_LIST) {
                listPropKeys.add(p.FEC_Source_Id__c);
            }
        }

        log('[LIST] listPropKeys size=' + listPropKeys.size()
            + ' | keys=' + listPropKeys
        );

        //Query AvailableValue using Source_Id
        Map<String, List<AvailableValueDTO>> valuesByPropKey =
            new Map<String, List<AvailableValueDTO>>();

        if (!listPropKeys.isEmpty()) {
            List<FEC_Master_Data_Integration__c> valueRecords = [
                SELECT Id,
                    FEC_Source_Parent_Id__c,
                    FEC_Source_Id__c,
                    FEC_Source_Name__c,
                    FEC_Source_NameVN__c
                FROM FEC_Master_Data_Integration__c
                WHERE FEC_Source_Type__c = :FEC_FraudConstantCommon.KEY_AVAILABLE_VALUE
                AND FEC_Source_Parent_Id__c IN :listPropKeys
                ORDER BY FEC_Source_Id__c
            ];

            log('[QUERY] AvailableValue count=' + valueRecords.size());

            for (FEC_Master_Data_Integration__c val : valueRecords) {
                String parentKey = val.FEC_Source_Parent_Id__c;

                if (!valuesByPropKey.containsKey(parentKey)) {
                    valuesByPropKey.put(parentKey, new List<AvailableValueDTO>());
                }

                AvailableValueDTO v = new AvailableValueDTO();
                v.id = val.Id;
                v.property = val.FEC_Source_Id__c;
                v.displayName = isVietnamese
                ? val.FEC_Source_NameVN__c
                : val.FEC_Source_Name__c;

                valuesByPropKey.get(parentKey).add(v);
            }
        } else {
            log('[SKIP] No LIST properties found');
        }

        //Build DTOs
        for (FEC_Master_Data_Integration__c rec : props) {
            PropertyDTO dto = new PropertyDTO();

            dto.id = rec.Id; // logical id
            dto.property = rec.FEC_Source_Id__c;
            dto.displayName = isVietnamese
                ? rec.FEC_Source_NameVN__c
                : rec.FEC_Source_Name__c;
            dto.type = rec.FEC_Source_Field_Type__c;
            dto.mandatory = rec.FEC_Source_Is_Mandatory__c;

            if (dto.type == caseFileType.TYPE_LIST) {
                dto.availableValues = valuesByPropKey.containsKey(rec.FEC_Source_Id__c)
                    ? valuesByPropKey.get(rec.FEC_Source_Id__c)
                    : new List<AvailableValueDTO>();

                log('[DTO] LIST property=' + dto.property
                    + ' | values=' + dto.availableValues.size()
                );
            }

            result.add(dto);
        }

        log('[END] loadAdditionalProperties | result size=' + result.size());
        return result;
    }



     /* =====================================================
     * LOAD HIERARCHY DATA
     * Generic method used for:
     * UserType, Channel, Product, ServiceType, Category,
     * SubCategory, SubCode
     * ===================================================== */

     @AuraEnabled(cacheable=true)
     public static List<NodeDTO> loadMasterIntegration(String sourceType, String parentId, String channelCode) {
 
         // List to store queried records
         List<NodeDTO> result = loadHierarchyMasterInt(sourceType, parentId, channelCode);
         return result;
     }
 
    @AuraEnabled
    public static FEC_IntegrationFraudCaseUtil.FraudCaseResponse submitCancelFraudCase(Map<String,Object> payload) { 
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse response = new FEC_IntegrationFraudCaseUtil.FraudCaseResponse();
        try {

            log('========= SUBMIT CANCEL FRAUD CASE START =========');
            log('RAW PAYLOAD: ' + JSON.serializePretty(payload));

            // 1. Extract payload
            FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper reqWrapper = FEC_IntegrationFraudCaseUtil.extractPayload(payload);
            log('RAW reqWrapper: ' + JSON.serializePretty(reqWrapper));
            // 2. Build SOAP request objects
            FEC_IntegrationSoapFraudcaseService.SysType sys =
            FEC_IntegrationFraudCaseUtil.buildSys(reqWrapper);

            FEC_IntegrationSoapFraudcaseService.CaseInfoType caseIfo =
            FEC_IntegrationFraudCaseUtil.buildCCaseInfo(reqWrapper);

            FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator =
            FEC_IntegrationFraudCaseUtil.buildCreator(reqWrapper);

            // 3. Call SOAP service
            FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType apiRes =
            FEC_IntegrationFraudService.callCancelFraudCaseService(reqWrapper, sys, caseIfo, creator);
           
            log('LOG-callCancelFraudCaseService: '+ apiRes);
            // 4. Handle response
            response = handleCancelResponse(reqWrapper, apiRes, reqWrapper, sys, caseIfo, creator);
            log('LOG-handleCancelResponse: '+ response);

            log('========= SUBMIT CANCEL FRAUD CASE END =========');
            return response;

        } catch (Exception ex) {

            log('ERROR submitCancelFraudCase: ' + ex.getMessage());

            response.success = false;
            response.responseCode = 0;
            response.message = ex.getMessage();
            return response;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getIntegrationFieldTypes() {
        FEC_FraudConstantCommon.IntegrationFieldType t = new FEC_FraudConstantCommon.IntegrationFieldType();
        FEC_FraudConstantCommon.IntegrationLabelFieldType label = new FEC_FraudConstantCommon.IntegrationLabelFieldType();
        
        return new Map<String, String>{
            label.LABEL_TYPE_FILE     => t.TYPE_FILE,
            label.LABEL_TYPE_TEXT     => t.TYPE_TEXT,
            label.LABEL_TYPE_STRING   => t.TYPE_STRING,
            label.LABEL_TYPE_NUMBER   => t.TYPE_NUMBER,
            label.LABEL_TYPE_DATE     => t.TYPE_DATE,
            label.LABEL_TYPE_DATETIME => t.TYPE_DATETIME,
            label.LABEL_TYPE_BOOLEAN  => t.TYPE_BOOLEAN,
            label.LABEL_TYPE_OBJECT   => t.TYPE_OBJECT,
            label.LABEL_TYPE_ARRAY    => t.TYPE_ARRAY,
            label.LABEL_TYPE_LIST     => t.TYPE_LIST,
            label.LABEL_TYPE_MULTI    => t.TYPE_MULTI,
            label.LABEL_TYPE_PICKLIST => t.TYPE_PICKLIST
        };
    }

    /**
     * Submits a Create Fraud Case request to the external SOAP service.
     *
     * Flow:
     * 1. Log and validate incoming payload.
     * 2. Extract request wrapper from raw payload.
     * 3. Build SOAP request objects (Sys, Customer, Request, Creator).
     * 4. Call external CreateFraudCase SOAP service.
     * 5. Process API response and return standardized response.
     *
     * This method is exposed to LWC/Aura via @AuraEnabled.
     *
     * @param payload Raw payload received from UI (LWC/Aura)
     * @return FraudCaseResponse containing:
     *         - success flag
     *         - response code
     *         - message
     *         - fraud case ID (if created successfully)
     */
    @AuraEnabled
    public static FEC_IntegrationFraudCaseUtil.FraudCaseResponse 
    submitCreateFraudCase(Map<String,Object> payload) {

        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result =
            new FEC_IntegrationFraudCaseUtil.FraudCaseResponse();

        try {

            log('========= SUBMIT CREATE FRAUD CASE START =========');
            log('RAW PAYLOAD: ' + JSON.serializePretty(payload));

            // 1. Extract payload
            FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper reqWrapper = FEC_IntegrationFraudCaseUtil.extractPayload(payload);

            // 2. Build SOAP request objects
            FEC_IntegrationSoapFraudcaseService.SysType sys =
            FEC_IntegrationFraudCaseUtil.buildSys(reqWrapper);

            FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust =
            FEC_IntegrationFraudCaseUtil.buildCustomer(reqWrapper);

            FEC_IntegrationSoapFraudcaseService.RequestInfo_element req =
            FEC_IntegrationFraudCaseUtil.buildRequest(reqWrapper);
            FEC_IntegrationSoapFraudcaseService.RequestInfo_element reqOriginal =
            FEC_IntegrationFraudCaseUtil.buildRequestOriginal(reqWrapper);

            FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator =
            FEC_IntegrationFraudCaseUtil.buildCreator(reqWrapper);

            // 3. Call SOAP service
            FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType apiRes =
            FEC_IntegrationFraudService.callCreateFraudCaseService(reqWrapper, sys, cust, req, creator);
            log('LOG-callCreateFraudCaseService: '+ apiRes);
            // 4. Handle response
            result = handleCreateResponse(apiRes, reqWrapper, sys, cust, reqOriginal, creator);
            log('LOG-handleCreateResponse: '+ result);

            log('========= SUBMIT CREATE  CASE END =========');
            return result;

        } catch (Exception ex) {

            log('ERROR submitCreateFraudCase: ' + ex.getMessage());

            result.success = false;
            result.responseCode = 0;
            result.message = ex.getMessage();
            return result;
        }
    }

    /**
     * Handles the response returned from the CreateFraudCase SOAP service.
     *
     * This method:
     * - Parses response code and description from API response
     * - Updates Fraud Case ID if returned by external system
     * - Performs upsert to local Fraud Case Service table
     * - Builds and returns standardized FraudCaseResponse result
     *
     * Business Logic:
     * - ResponseCode == 1 AND CaseID is not blank → success flow
     * - Otherwise → failure flow
     *
     * @param apiRes  SOAP response from CreateFraudCase service
     * @param w       FraudCaseRequestWrapper (original request data)
     * @param sys     System metadata sent to external service
     * @param cust    Customer information sent to service
     * @param req     Request details sent to service
     * @param creator Creator information sent to service
     *
     * @return FEC_IntegrationFraudCaseUtil.FraudCaseResponse
     *         standardized response object for caller layer
     */
    private static FEC_IntegrationFraudCaseUtil.FraudCaseResponse 
    handleCreateResponse(
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType apiRes,
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w,
        FEC_IntegrationSoapFraudcaseService.SysType sys,
        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust,
        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req,
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

        // Update Fraud Case ID if returned from external system
        if (apiRes != null && String.isNotBlank(apiRes.CaseID)) {
            w.caseId = apiRes.CaseID;
        }

        // Success condition:
        // - External system returned success code (1)
        // - Fraud Case ID is present
        if (responseCode == 1 && String.isNotBlank(w.caseId)) {

            // Upsert fraud case service record locally
            Boolean isUpsert =
                upsertFraudCaseService(
                    w.serviceCaseId,
                    w.channelCode,
                    null,
                    w.caseId,
                    INIT_CASE_STATUS,
                    sys,
                    req,
                    cust,
                    creator
                );

            result.success = isUpsert;
            result.responseCode = isUpsert ? 1 : 0;
            result.message = isUpsert ? MSG_CREATE_SUCCESS : MSG_CREATE_FAILED;
            result.fraudCaseId = w.caseId;

        } else {

            // Failure flow
            result.success = false;
            result.responseCode = 0;
            result.message = responseDescription;
        }

        return result;
    }

    /**
     * Handles the response returned from the external Create/Update Fraud Case SOAP API.
     *
     * This method:
     * 1. Extracts and validates response code & description from API response.
     * 2. Updates Fraud Case ID if returned from external system.
     * 3. Determines success/failure based on response code and Case ID.
     * 4. Upserts local Fraud Case Service record when success.
     * 5. Returns a standardized FraudCaseResponse wrapper to caller.
     *
     * @param apiRes   SOAP response returned from external fraud system
     * @param w        FraudCaseRequestWrapper containing request data
     * @param sys      System information used for logging/upsert
     * @param cust     Customer information used for logging/upsert
     * @param req      Request information used for logging/upsert
     * @param creator  Creator information used for logging/upsert
     * @return FraudCaseResponse wrapper containing success flag, code, message, and case ID
     */
    private static FEC_IntegrationFraudCaseUtil.FraudCaseResponse 
    handleUpdateResponse(
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType apiRes,
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w,
        FEC_IntegrationSoapFraudcaseService.SysType sys,
        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust,
        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req,
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
        if (responseCode == 1 && String.isNotBlank(w.caseId)) {

            // Upsert fraud case service record locally
            Boolean isUpsert =
                upsertFraudCaseService(
                    w.serviceCaseId,
                    w.channelCode,
                    null,
                    w.caseId,
                    INIT_CASE_STATUS,
                    sys,
                    req,
                    cust,
                    creator
                );

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

    /**
     * Handles the SOAP Cancel Fraud Case API response and maps it
     * into an internal FraudCaseResponse object.
     *
     * Flow:
     * 1. Extract response code and description from external API response.
     * 2. Validate success condition (Code == 1 and CaseID returned).
     * 3. If success → trigger internal cancel processing.
     * 4. Build standardized response object for caller.
     *
     * @param payload   Original request payload sent to external system
     * @param apiRes    SOAP response received from CancelFraudCase service
     * @param w         Request wrapper object used for processing
     * @param sys       System information used in SOAP request (for logging/debug)
     * @param caseInfo  Case information sent to external system (for logging/debug)
     * @param creator   Creator information sent to external system (for logging/debug)
     * @return FraudCaseResponse containing:
     *         - success flag
     *         - response code
     *         - message
     *         - fraud case ID
     */
    private static FEC_IntegrationFraudCaseUtil.FraudCaseResponse 
    handleCancelResponse(
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper payload,
        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType apiRes,
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w,
        FEC_IntegrationSoapFraudcaseService.SysType sys,
        FEC_IntegrationSoapFraudcaseService.CaseInfoType caseInfo,
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

        // Update Fraud Case ID if returned from external system
        if (apiRes != null && String.isNotBlank(apiRes.CaseID)) {
            w.caseId = apiRes.CaseID;
        }

        // Success condition:
        // - External system returned success code (1)
        // - Fraud Case ID is present
        if (responseCode == 1 && String.isNotBlank(w.caseId)) {

            //Process Cancel Fraud case
            Boolean isProcessCancelCase = processCancelFraudCase(payload.caseId, payload.channelCode, payload.serviceCaseId, payload.remarks);

            result.success = isProcessCancelCase;
            result.responseCode = isProcessCancelCase ? 1 : 0;
            result.message = isProcessCancelCase ? MSG_CANCEL_SUCCESS : MSG_CANCEL_FAILED;
            result.fraudCaseId = w.caseId;

        } else {

            // Failure flow
            result.success = false;
            result.responseCode = 0;
            result.message = responseDescription;
        }

        return result;
    }
 
 
    @AuraEnabled
    public static FEC_IntegrationFraudCaseUtil.FraudCaseResponse submitUpdateFraudCase(Map<String,Object> payload) {
        
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result =
            new FEC_IntegrationFraudCaseUtil.FraudCaseResponse();

        try {

            log('========= SUBMIT UPDATE FRAUD CASE START =========');
            log('RAW PAYLOAD: ' + JSON.serializePretty(payload));

            // 1. Extract payload
            FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper reqWrapper = FEC_IntegrationFraudCaseUtil.extractPayload(payload);

            // 2. Build SOAP request objects
            FEC_IntegrationSoapFraudcaseService.SysType sys =
            FEC_IntegrationFraudCaseUtil.buildSys(reqWrapper);

            FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust =
            FEC_IntegrationFraudCaseUtil.buildCustomer(reqWrapper);

            FEC_IntegrationSoapFraudcaseService.RequestInfo_element req =
            FEC_IntegrationFraudCaseUtil.buildRequest(reqWrapper);
            FEC_IntegrationSoapFraudcaseService.RequestInfo_element reqOr =
            FEC_IntegrationFraudCaseUtil.buildRequestOriginal(reqWrapper);

            FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator =
            FEC_IntegrationFraudCaseUtil.buildCreator(reqWrapper);
            log('submitUpdateFraudCase: '+ JSON.serialize(req));

            // 3. Call SOAP service
            FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType apiRes =
            FEC_IntegrationFraudService.callUpdateFraudCaseService(reqWrapper, sys, cust, req, creator);
            log('LOG-callUpdateFraudCaseService: '+ apiRes);
            // 4. Handle response
            result = handleUpdateResponse(apiRes, reqWrapper, sys, cust, reqOr, creator);
            log('LOG-handleUpdateResponse: '+ result);

            log('========= SUBMIT UPDATE FRAUD CASE END =========');
            return result;

        } catch (Exception ex) {

            log('ERROR submitUpdateFraudCase: ' + ex.getMessage());

            result.success = false;
            result.responseCode = 0;
            result.message = ex.getMessage();
            return result;
        }
        
    }

    private static Boolean processCancelFraudCase(String caseId, String channelCode, String serviceCaseId, String Remarks) {
        try {
            log('SUCCESS IN processCancelFraudCase');
            List<FEC_Integration_Case__c> existing = [
                    SELECT Id, FEC_CaseID__c, FEC_Service_Case_ID__c
                    FROM FEC_Integration_Case__c
                    WHERE FEC_CaseID__c = :caseId 
                    AND FEC_Sys_Channel__c = :channelCode
                    AND FEC_Service_Case_ID__c = :serviceCaseId
                    LIMIT 1
                ];
             log('QUERY RESULT: ' + JSON.serializePretty(existing));
             if (existing.isEmpty()) {
                log('NO EXISTING CASE FOUND → CANCEL FAILED');
                return false;
            }
   
            FEC_Integration_Case__c rec = existing[0];
            rec.FEC_Case_Status__c = FEC_IntegrationFraudCaseUtil.mapCaseStatus(CANCEL_CASE_STATUS);
            rec.FEC_CS_Remark__c = String.isBlank(remarks) ? null : FEC_IntegrationFraudCaseUtil.safeText(remarks);

            update rec;

            log('CANCEL SUCCESSFULLY UPDATED');
            return true;
            
        } catch (Exception ex) {
            log('ERROR IN processCancelFraudCase: ' + ex.getMessage());            
            return false;
        }
    }
 
       
    private static Boolean upsertFraudCaseService(
    String serviceCaseId,
    String channelCode,
    String parentCaseId,
    String caseId,
    String caseStatus,
    FEC_IntegrationSoapFraudcaseService.SysType sys,
    FEC_IntegrationSoapFraudcaseService.RequestInfo_element req,
    FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust,
    FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator
    ) {

        log('==================== UPSERT FRAUD CASE START ====================');
        log('LOG-upsertFraudCaseService CASEID: '+ caseId);

        try {

            // =============================================================
            // 1) FIND EXISTING
            // =============================================================
            List<FEC_Integration_Case__c> existing = [
                SELECT Id
                FROM FEC_Integration_Case__c
                WHERE FEC_CaseID__c = :caseId
                AND FEC_Sys_Channel__c = :channelCode
                LIMIT 1
            ];

            FEC_Integration_Case__c rec =
                existing.isEmpty()
                ? new FEC_Integration_Case__c()
                : existing[0];

            // =============================================================
            // 2) MAP PRIMARY FIELDS
            // =============================================================

            rec.FEC_CaseID__c = caseId;
            rec.FEC_Service_Case_ID__c = serviceCaseId;
            rec.FEC_Parent_CaseID__c = parentCaseId;
            rec.FEC_Case_Status__c = caseStatus;

            // ----- SYS -----
            if (sys != null) {
                rec.FEC_Sys_Transaction_Id__c = sys.TransactionID;
                rec.FEC_Sys_Date_Time__c = sys.DateTime_x;
                rec.FEC_Sys_Channel__c = channelCode;
            }

            // ----- CUSTOMER -----
            if (cust != null) {
                rec.FEC_Customer_User_Type__c = cust.UserType;
            }

            // ----- CREATOR -----
            if (creator != null) {
                rec.FEC_Creator_Email__c = creator.CreatorEmail;
            }

            // ----- REQUEST -----
            if (req != null) {
                rec.FEC_Case_Type__c = req.CaseType;
                rec.FEC_Product_Type__c = req.ProductType;
                rec.FEC_Category__c = req.Category;
                rec.FEC_Sub_Category__c = req.SubCategory;
                rec.FEC_Sub_Code__c = req.SubCode;
                rec.FEC_CS_Remark__c = FEC_IntegrationFraudCaseUtil.safeText(req.Remarks);
            }

            rec.OwnerId = UserInfo.getUserId();
            log('LOG-upsertFraudCaseService RECORD: '+ JSON.serialize(rec));

            // =============================================================
            // 3) SAVE CASE
            // =============================================================

            if (rec.Id == null) {
                insert rec;
            } else {
                update rec;
            }

            log('CASE SAVED: ' + rec.Id);

            // =============================================================
            // 4) DELETE OLD ADDITIONAL INFO (AFTER SAVE)
            // =============================================================

            List<FEC_Integration_Case_Info__c> oldInfos = [
                SELECT Id
                FROM FEC_Integration_Case_Info__c
                WHERE FEC_Parent_Case__c = :rec.Id
            ];

            if (!oldInfos.isEmpty()) {
                delete oldInfos;
            }

            // =============================================================
            // 5) INSERT NEW ADDITIONAL INFO
            // =============================================================

            if (req != null && req.AdditionalInfo != null) {

                List<FEC_Integration_Case_Info__c> newInfos =
                    new List<FEC_Integration_Case_Info__c>();
            
                for (FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element ai : req.AdditionalInfo) {
            
                    if (ai == null) continue;
            
                    String infoValue = ai.Value;   
                    String infoId    = ai.ID;    
                    // ===============================
                    // FILE HANDLING
                    // ===============================
                    if (String.isNotBlank(infoValue) && infoValue.contains('|')) {
                        Integer firstPipe = infoValue.indexOf('|');
                        Integer secondPipe = infoValue.indexOf('|', firstPipe + 1);
                        if (firstPipe > 0 && secondPipe > firstPipe) {
                            String fileName  = infoValue.substring(0, firstPipe);
                            String extension = infoValue.substring(firstPipe + 1, secondPipe);
                            String base64Val = infoValue.substring(secondPipe + 1);
                            Id contentDocumentId =
                                saveAttachedFile(fileName, base64Val, rec.Id);
            
                            if (contentDocumentId != null) {
                                infoValue =
                                    fileName + '|' +
                                    extension + '|' +
                                    contentDocumentId;
                            }
                        }
                        
                    }

                    // if (String.isNotBlank(infoValue) && infoValue.contains('|')) {
            
                    //     List<String> parts = infoValue.split('\\|', 3);
            
                    //     if (parts.size() == 3) {
            
                    //         String fileName  = parts[0];
                    //         String extension = parts[1];
                    //         String base64Val = parts[2];
            
                    //         Id contentDocumentId =
                    //             saveAttachedFile(fileName, base64Val, rec.Id);
            
                    //         if (contentDocumentId != null) {
                    //             infoValue =
                    //                 fileName + '|' +
                    //                 extension + '|' +
                    //                 contentDocumentId;
                    //         }
                    //     }
                    // }
            
                    FEC_Integration_Case_Info__c info =
                        new FEC_Integration_Case_Info__c();
            
                    info.FEC_Parent_Case__c = rec.Id;
                    info.FEC_Info_ID__c     = infoId;
                    info.FEC_Info_Value__c  = infoValue;
            
                    newInfos.add(info);
                }
            
                if (!newInfos.isEmpty()) {
                    insert newInfos;
                }
            }

            log('==================== UPSERT FRAUD CASE DONE ====================');
            return true;

        } catch (Exception ex) {

            log('ERROR IN UPSERT FRAUD CASE: ' + ex.getMessage());
            log('STACKTRACE: ' + ex.getStackTraceString());

            return false;
        }
    }
    
    

    private static Id saveAttachedFile(String fileName, String base64Data, Id parentId) {

        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = EncodingUtil.base64Decode(base64Data);
        insert cv;
    
        ContentVersion insertedCV = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];
    
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = insertedCV.ContentDocumentId,
            LinkedEntityId = parentId,
            ShareType = 'V',
            Visibility = CONTENT_VISIBILITY
        );
        insert link;
    
        return insertedCV.ContentDocumentId;
    }
        
 
    private static Map<String, Object> buildUiMCreateFraudCaseData() {
        Map<String, Object> result = new Map<String, Object>();
        List<Map<String, Object>> categories = new List<Map<String, Object>>();
        Boolean isVietnamese = userLang != null && userLang.startsWith(FEC_FraudConstantCommon.LANG_VI);
        FEC_FraudConstantCommon.IntegrationMappingField integrationField = new FEC_FraudConstantCommon.IntegrationMappingField();
        FEC_FraudConstantCommon.IntegrationField masterFields = new FEC_FraudConstantCommon.IntegrationField();
        // Load full master data
        List<FEC_Master_Data_Integration__c> recs = [
            SELECT
                FEC_Source_Id__c,
                FEC_Source_Parent_Id__c,
                FEC_Source_Name__c,
                FEC_Source_NameVN__c,
                FEC_Source_Type__c,
                FEC_Source_Field_Type__c,
                FEC_Source_Enum_Value__c,
                FEC_Source_Enum_Label__c,
                FEC_Source_Enum_LabelVN__c,
                FEC_Source_Is_Mandatory__c,
                FEC_PosOrder__c
            FROM FEC_Master_Data_Integration__c
            ORDER BY FEC_PosOrder__c NULLS LAST
        ];
        log('➡ Load full master data        = ' + JSON.serializePretty(recs));
 
        // Group records by Type
        Map<String, List<FEC_Master_Data_Integration__c>> typeMap = new Map<String, List<FEC_Master_Data_Integration__c>>();
        for (FEC_Master_Data_Integration__c r : recs) {
            String t = r.FEC_Source_Type__c != null ? r.FEC_Source_Type__c : null;
            if (!typeMap.containsKey(t)) {
                typeMap.put(t, new List<FEC_Master_Data_Integration__c>());
            }
            typeMap.get(t).add(r);
        }
 
        // Safe shortcuts
        List<FEC_Master_Data_Integration__c> categoryList        = typeMap.containsKey(integrationField.SOURCE_MASTER_CATEGORY)         ? typeMap.get(integrationField.SOURCE_MASTER_CATEGORY)         : new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> subCategoryList    = typeMap.containsKey(integrationField.SOURCE_MASTER_SUBCATEGORY)      ? typeMap.get(integrationField.SOURCE_MASTER_SUBCATEGORY)      : new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> subCodeList        = typeMap.containsKey(integrationField.SOURCE_MASTER_SUBCODE)          ? typeMap.get(integrationField.SOURCE_MASTER_SUBCODE)          : new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> additionalList     = typeMap.containsKey(FEC_FraudConstantCommon.KEY_ADDITIONAL_PROPERTY)? typeMap.get(FEC_FraudConstantCommon.KEY_ADDITIONAL_PROPERTY): new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> availableValueList = typeMap.containsKey(FEC_FraudConstantCommon.KEY_AVAILABLE_VALUE)   ? typeMap.get(FEC_FraudConstantCommon.KEY_AVAILABLE_VALUE)   : new List<FEC_Master_Data_Integration__c>();
        log('➡ Load full master categoryList        = ' + JSON.serializePretty(categoryList));
        log('➡ Load full master subCategoryList        = ' + JSON.serializePretty(subCategoryList));
        log('➡ Load full master additionalList        = ' + JSON.serializePretty(additionalList));
        log('➡ Load full master availableValueList        = ' + JSON.serializePretty(availableValueList));
        // ------------------------------------------------------------
        // BUILD TREE: Category → SubCategory → SubCode → AP → Values
        // ------------------------------------------------------------
        for (FEC_Master_Data_Integration__c cat : categoryList) {
 
            Map<String, Object> catNode = new Map<String, Object>{
                masterFields.MASTER_ID   => cat.FEC_Source_Id__c,
                masterFields.MASTER_NAME => getLabel(
                cat.FEC_Source_Name__c,
                cat.FEC_Source_NameVN__c,
                isVietnamese
                ),
                masterFields.MASTER_POSORDER      => cat.FEC_PosOrder__c,
                masterFields.MASTER_SUBCATEGORIES => new List<Object>()
            };
 
            // ---------------- SUBCATEGORY ----------------
            for (FEC_Master_Data_Integration__c sub : subCategoryList) {
                if (sub.FEC_Source_Parent_Id__c == cat.FEC_Source_Id__c) {
 
                    Map<String, Object> subNode = new Map<String, Object>{
                        masterFields.MASTER_ID        => sub.FEC_Source_Id__c,
                        masterFields.MASTER_NAME => getLabel(
                            sub.FEC_Source_Name__c,
                            sub.FEC_Source_NameVN__c,
                            isVietnamese
                            ),
                        masterFields.MASTER_SUBCODES  => new List<Object>()
                    };
 
                    // ---------------- SUBCODE ----------------
                    for (FEC_Master_Data_Integration__c sc : subCodeList) {
                        if (sc.FEC_Source_Parent_Id__c == sub.FEC_Source_Id__c) {
 
                            Map<String, Object> scNode = new Map<String, Object>{
                                masterFields.MASTER_ID        => sc.FEC_Source_Id__c,
                                masterFields.MASTER_NAME => getLabel(
                                    sc.FEC_Source_Name__c,
                                    sc.FEC_Source_NameVN__c,
                                    isVietnamese
                                    ),
                                masterFields.MASTER_ADDITONAL_PROPERTIES => new List<Object>()
                            };
 
                            // ---------------- ADDITIONAL PROPERTY ----------------
                            for (FEC_Master_Data_Integration__c ap : additionalList) {
                                if (ap.FEC_Source_Parent_Id__c == sc.FEC_Source_Id__c) {
 
                                    Map<String, Object> apNode = new Map<String, Object>{
                                        masterFields.MASTER_ID            => ap.FEC_Source_Id__c,
                                        masterFields.MASTER_NAME => getLabel(
                                            ap.FEC_Source_Name__c,
                                            ap.FEC_Source_NameVN__c,
                                            isVietnamese
                                            ),
                                        masterFields.MASTER_TYPE          => ap.FEC_Source_Field_Type__c,
                                        masterFields.MASTER_MANDATORY     => ap.FEC_Source_Is_Mandatory__c,
                                        masterFields.MASTER_AVAILABLE_VALUES => new List<Object>()
                                    };
 
                                    // ---------------- AVAILABLE VALUES ----------------
                                    for (FEC_Master_Data_Integration__c av : availableValueList) {
                                        if (av.FEC_Source_Parent_Id__c == ap.FEC_Source_Id__c) {
 
                                            List<Object> avList = (List<Object>) apNode.get(masterFields.MASTER_AVAILABLE_VALUES);
                                            if (avList == null) {
                                                avList = new List<Object>();
                                                apNode.put(masterFields.MASTER_AVAILABLE_VALUES, avList);
                                            }
 
                                            avList.add(new Map<String, Object>{
                                                masterFields.MASTER_ID     => av.FEC_Source_Enum_Value__c,
                                                masterFields.MASTER_NAME => getLabel(
                                                    av.FEC_Source_Enum_Label__c,
                                                    av.FEC_Source_Enum_LabelVN__c,
                                                    isVietnamese
                                                    )
                                            });
                                        }
                                    }
 
                                    // Add AP → SubCode
                                    ((List<Object>)scNode.get(masterFields.MASTER_ADDITONAL_PROPERTIES)).add(apNode);
                                }
                            }
 
                            // Add SubCode → SubCategory
                            ((List<Object>)subNode.get(masterFields.MASTER_SUBCODES)).add(scNode);
                        }
                    }
 
                    // Add SubCategory → Category
                    ((List<Object>)catNode.get(masterFields.MASTER_SUBCATEGORIES)).add(subNode);
                }
            }
 
            categories.add(catNode);
        }
        log('➡ Load full all categories = ' + JSON.serializePretty(categories));
        result.put(masterFields.MASTER_CATEGORIES, categories);
        return result;    
   
    }

     /**
     * Loads hierarchical Master Integration data based on the requested source type.
     *
     * This method acts as a routing layer that determines which specific
     * loader method should be executed depending on the hierarchy level.
     *
     * @param sourceType  The requested master data type (IntUserType, ProductLine, CaseType, Category, etc.)
     * @param parentId    The parent node identifier (used for child loading)
     * @param channelCode The integration channel code
     * @return A list of NodeDTO objects for UI rendering
     */
    private static List<NodeDTO> loadHierarchyMasterInt(String sourceType, String parentId, String channelCode) {
        List<NodeDTO> result = new List<NodeDTO>();
        result = loadChildServiceTypeList(sourceType, parentId, channelCode);
        return result;
    }


    /**
     * Loads child service-type records for the requested hierarchy level.
     *
     * This method supports multiple levels of hierarchy including:
     *   CaseType → Category → SubCategory → SubCode
     *
     * @param sourceType  The source type of the requested records
     * @param parentId    Parent record identifier
     * @param channelCode Integration channel code
     * @return A list of NodeDTO objects
     */
    private static List<NodeDTO> loadChildServiceTypeList(String sourceType, String parentId, String channelCode) {
        List<NodeDTO> result = new List<NodeDTO>();
        //Detect user language        
        Boolean isVietnamese = userLang != null && userLang.startsWith(FEC_FraudConstantCommon.LANG_VI);
        FEC_FraudConstantCommon.IntegrationMappingField integrationField = new FEC_FraudConstantCommon.IntegrationMappingField();
        if (sourceType == integrationField.SOURCE_TYPE_CASE) {
            List<AggregateResult> ars = [
                SELECT FEC_Source_Id__c sourceId,
                    FEC_Source_NameVN__c nameVN,
                    FEC_Source_Name__c nameEN,
                    MIN(FEC_PosOrder__c) minPos
                FROM FEC_Master_Data_Integration__c
                WHERE FEC_Source_Type__c = :sourceType AND FEC_Channel__c = :channelCode
                GROUP BY FEC_Source_Id__c, FEC_Source_NameVN__c,FEC_Source_Name__c
            ];
            for (AggregateResult ar : ars) {
                String displayName = isVietnamese
                ? (String) ar.get(FEC_FraudConstantCommon.FIELD_NAME_VN)
                : (String) ar.get(FEC_FraudConstantCommon.FIELD_NAME_EN);
                result.add(
                    new NodeDTO(
                        displayName,
                        (String) ar.get('sourceId')
                    )
                );
        }
        }
        else {
            for (FEC_Master_Data_Integration__c r : [
            SELECT FEC_Source_Id__c, FEC_Source_NameVN__c, FEC_Source_Name__c
            FROM FEC_Master_Data_Integration__c
            WHERE FEC_Source_Type__c = :sourceType
            AND FEC_Source_Parent_Id__c = :parentId
            AND FEC_Channel__c = :channelCode
            ORDER BY FEC_PosOrder__c
            ]) {
                String displayName = isVietnamese
                ? r.FEC_Source_NameVN__c
                : r.FEC_Source_Name__c;
                result.add(new NodeDTO(displayName, r.FEC_Source_Id__c));
            }
        }

        

        return result;
    }

    private static String getLabel(String en, String vi, Boolean isVietnamese) {
        if (isVietnamese && String.isNotBlank(vi)) {
            return vi;
        }
        return en;
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