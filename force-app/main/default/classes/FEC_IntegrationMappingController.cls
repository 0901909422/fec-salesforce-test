/**
 * Controller for Integration Mapping screen
 * - Provide hierarchy data (UserType → Channel → Product → ...)
 * - Provide additional property mapping data
 */
public with sharing class FEC_IntegrationMappingController{

    public static final Boolean DEBUG_LOG = true;
    public static final String userLang = UserInfo.getLanguage();
    public static final String MSG_CREATED  = System.Label.LBL_MappingCreated;
    public static final String MSG_UPDATED  = System.Label.LBL_MappingUpdated;
    public static final String ERR_PAYLOAD  = System.Label.LBL_PayloadEmpty;
    public static final String ERR_DB       = System.Label.LBL_DatabaseError;
   

     /**
     * Standard response wrapper for save operations.
     * 
     * This DTO is returned to the UI layer to indicate whether
     * the operation succeeded and to provide a status message
     * and related record identifier when applicable.
     */

     public class SaveResultDTO {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id mappingId;
    }

    /**
     * Data Transfer Object representing a Mapping configuration.
     *
     * This DTO is used to exchange mapping data between
     * Lightning Web Components and Apex controllers.
     */
    public class MappingDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String userTypeId;
        @AuraEnabled public String channel;
        @AuraEnabled public String intUserTypeId;
        @AuraEnabled public String productLine;
        @AuraEnabled public String serviceType;
        @AuraEnabled public String category;
        @AuraEnabled public String subCategory;
        @AuraEnabled public String subCode;
        @AuraEnabled public String natureOfCaseId;
        @AuraEnabled public String caseStageId;
        @AuraEnabled public String screenCaseId;
        @AuraEnabled public String processChangeStatus;
        @AuraEnabled public Boolean status;
        @AuraEnabled public List<PropertyDTO> infos;
    }
    
   
     /**
     * Data Transfer Object representing a CSM field definition.
     *
     * Used by the UI layer to display and configure CSM-related fields.
     */
    public class CsmFieldDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String code;
        @AuraEnabled public String type;
    }
    

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
        @AuraEnabled public String csmPropertyId;     // Selected CSM property id
        @AuraEnabled public String csmProperty;       // Selected CSM property
        @AuraEnabled public String csmPropertyType;   // Type of CSM property
        @AuraEnabled public Boolean autoMapping;      // Auto-mapping flag,
        @AuraEnabled public String autoMappingPropertySource;   // Auto mapping Property from CS
    }
    
    /**
     * Save or update Integration Mapping based on Nature Of Case.
     *
     * Behavior:
     *  - If a mapping already exists with:
     *      + Same Nature Of Case
     *      + Status = false
     *      + Process Change Status = 'New'
     *    → UPDATE the existing mapping
     *      → Delete old child records
     *      → Insert new child records
     *
     *  - If no mapping exists
     *    → INSERT new mapping and child records
     *
     * Input:
     *  - payloadJson (String):
     *      {
     *        header: { mapping header fields },
     *        details: [ list of integrating properties ]
     *      }
     *
     * Output:
     *  - SaveResultDTO:
     *      success   : true / false
     *      mappingId : Id of inserted / updated mapping
     *      message   : result message
     */
    @AuraEnabled
    public static SaveResultDTO saveIntegrationMapping(String payloadJson) {  
        FEC_FraudConstantCommon.IntegrationMappingField caseField = new FEC_FraudConstantCommon.IntegrationMappingField();
          
        SaveResultDTO result = new SaveResultDTO();
        result.success = false;
    
        String processChangeStatus = FEC_FraudConstantCommon.NEW_STATUS;
    
        try {
            /* ================= VALIDATE PAYLOAD ================= */
            if (String.isBlank(payloadJson)) {
                throw new AuraHandledException(ERR_PAYLOAD);
            }
    
            Map<String, Object> payload =
                (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
    
            Map<String, Object> header =
                (Map<String, Object>) payload.get(caseField.SOURCE_HEADER);
    
            List<Object> details =
                (List<Object>) payload.get(caseField.SOURCE_DETAILS);
    
            String natureOfCaseId = (String) header.get(caseField.SOURCE_NATURE_OF_CASE_ID);
            String caseStageId = (String) header.get(caseField.SOURCE_CASE_STAGE_ID);
            String screenCaseId = (String) header.get(caseField.SOURCE_SCREEN_CASE_ID);
            String mappingId = (String) header.get(caseField.SOURCE_MAPPING_ID);
    
            log('[SAVE] mappingId=' + mappingId);
    
            /* ================= CHECK EXISTING ================= */
            List<FEC_Data_Integration_Mapping__c> exist = [
                SELECT Id
                FROM FEC_Data_Integration_Mapping__c
                WHERE Id = :mappingId
                LIMIT 1
            ];
    
            //Boolean isUpdate = !exist.isEmpty();
            //Allway create new
            Boolean isUpdate = false;
            log('[SAVE] isUpdate=' + isUpdate);
            String message = MSG_CREATED;          
    
            /* ================= UPSERT PARENT ================= */
            FEC_Data_Integration_Mapping__c mapping;
    
            if (isUpdate) {
                // UPDATE existing
                mapping = exist[0];
                log('[SAVE] Updating mappingId=' + mapping.Id);
                message = MSG_UPDATED;                
            } else {
                // INSERT new
                mapping = new FEC_Data_Integration_Mapping__c();
                mapping.FEC_Nature_Of_Case__c = natureOfCaseId;
                mapping.FEC_ScreenId__c = screenCaseId;
                mapping.FEC_Case_Stage__c = caseStageId;
                mapping.FEC_Process_Change_Status__c = processChangeStatus;
                mapping.FEC_Status__c = true;
                log('[SAVE] Creating new mapping');
            }
    
            // Common fields (insert + update)
            mapping.FEC_User_Type_Id__c        = (String) header.get(caseField.SOURCE_TYPE_USER_TYPE);
            mapping.FEC_Int_Channel__c         = (String) header.get(caseField.SOURCE_TYPE_CHANNEL);
            mapping.FEC_Int_User_Type_Id__c    = (String) header.get(caseField.SOURCE_TYPE_INT_USER);
            mapping.FEC_Int_Product_Line_Id__c = (String) header.get(caseField.SOURCE_TYPE_PRODUCT);
            mapping.FEC_Int_Service_Type_Id__c = (String) header.get(caseField.SOURCE_TYPE_SERVICE_TYPE);
            mapping.FEC_Int_Category_Id__c     = (String) header.get(caseField.SOURCE_TYPE_CATEGORY);
            mapping.FEC_Int_Sub_Category_Id__c = (String) header.get(caseField.SOURCE_TYPE_SUBCATEGORY);
            mapping.FEC_Int_Sub_Code_Id__c     = (String) header.get(caseField.SOURCE_TYPE_SUBCODE);
            
            log('### Before upsert mapping ###');
            log('Mapping fields: ' + mapping);

            upsert mapping;
    
            /* ================= DELETE OLD CHILDREN (UPDATE) ================= */
            if (isUpdate) {
                List<FEC_Data_Integration_Mapping_Info__c> oldInfos = [
                    SELECT Id
                    FROM FEC_Data_Integration_Mapping_Info__c
                    WHERE FEC_Data_Integration_Mapping__c = :mapping.Id
                ];
    
                if (!oldInfos.isEmpty()) {
                    delete oldInfos;
                    log('[SAVE] Deleted old child records=' + oldInfos.size());
                }
            }
    
            /* ================= INSERT CHILDREN ================= */
            List<FEC_Data_Integration_Mapping_Info__c> infos =
                new List<FEC_Data_Integration_Mapping_Info__c>();
    
            for (Object o : details) {
                Map<String, Object> row = (Map<String, Object>) o;
    
                FEC_Data_Integration_Mapping_Info__c info =
                    new FEC_Data_Integration_Mapping_Info__c();
    
                info.FEC_Data_Integration_Mapping__c  = mapping.Id;
                info.FEC_Integrating_Property__c      = (String) row.get(caseField.ROW_PROPERTY);
                info.FEC_Integrating_Property_Type__c = (String) row.get(caseField.ROW_PROPERTY_TYPE);
                info.FEC_CSM_Property__c              = (String) row.get(caseField.ROW_CSM_PROPERTY);
                info.FEC_CSM_Property_Type__c         = (String) row.get(caseField.ROW_CSM_PROPERTY_TYPE);
                info.FEC_Auto_Mapping_Property__c     = (Boolean) row.get(caseField.ROW_AUTO_MAPPING);
                info.FEC_Mandatory__c                 = (Boolean) row.get(caseField.ROW_MANDATORY);
                info.FEC_Auto_Mapping_Property_Source__c            = (String) row.get(caseField.ROW_AUTO_MAPPING_PROPERTY_SOURCE_ID);
    
                infos.add(info);
            }
    
            if (!infos.isEmpty()) {
                insert infos;
                log('[SAVE] Inserted child records=' + infos.size());
            }
    
            /* ================= SUCCESS ================= */
            result.success = true;
            result.mappingId = mapping.Id;
            result.message = message;
            log('[SAVE] SUCCESS=' + result);
            return result;
    
        } catch (DmlException dmlEx) {
            log('[SAVE ERROR][DML] ' + dmlEx.getMessage());
            result.message = ERR_DB +' ' + dmlEx.getDmlMessage(0);
            return result;
    
        } catch (Exception ex) {
            log('[SAVE ERROR] ' + ex.getMessage());
            result.message = ex.getMessage();
            return result;
        }
    }
    

     
     /**
     * Loads an existing Integration Mapping by Nature Of Case.
     *
     * Purpose:
     * - Used by LWC in UPDATE / VIEW mode
     * - Retrieves the latest COMPLETED and ACTIVE mapping
     * - Maps both parent and child records into DTOs for UI consumption
     *
     * Input:
     * @param mappingId  Id of Integration Of Case (passed from parent LWC)
     *
     * Output:
     * @return MappingDTO
     *   - Header information for mapping (channel, product, category, ...)
     *   - List of mapped integrating properties (PropertyDTO)
     *
     * Behavior:
     * - If no mapping exists, returns an empty MappingDTO
     * - No exception is thrown to UI (safe for cacheable method)
     *
     * Notes:
     * - cacheable=true because method is READ-ONLY
     * - Caller must handle empty DTO (no mapping found)
     */
    @AuraEnabled
    public static MappingDTO loadIntegrationMapping(String mappingId) {

        /* ============================================================
        * 1. Method entry & input validation
        * ============================================================ */

        log('[loadMapping] START');
        log('[loadMapping] natureOfCaseId = ' + mappingId);      
        // Defensive programming:
        // If Integration Of Case Id is null/blank, immediately return empty DTO
        if (String.isBlank(mappingId)) {
            log('[loadMapping] mappingId is blank → return empty DTO');
            return new MappingDTO();
        }

        /* ============================================================
        * 2. Query parent Integration Mapping
        *    - Only ACTIVE (FEC_Status__c = true)
        *    - Only COMPLETED (Process Status = Done)
        *    - Expect maximum 1 record
        * ============================================================ */

        List<FEC_Data_Integration_Mapping__c> mDataList = [
            SELECT Id,
                FEC_Nature_Of_Case__c,
                FEC_Int_Category_Id__c,
                FEC_Int_Channel__c,
                FEC_Int_Product_Line_Id__c,
                FEC_Int_Service_Type_Id__c,
                FEC_Int_Sub_Category_Id__c,
                FEC_Int_Sub_Code_Id__c,
                FEC_Int_User_Type_Id__c,
                FEC_Process_Change_Status__c,
                FEC_Status__c,
                FEC_ScreenId__c,
                FEC_Case_Stage__c,
                FEC_User_Type_Id__c                
            FROM FEC_Data_Integration_Mapping__c
            WHERE Id = :mappingId            
            LIMIT 1
        ];

        log('[loadMapping] Parent mapping records found = ' + mDataList.size());

        // Initialize return object (empty by default)
        MappingDTO dto = new MappingDTO();

        /* ============================================================
        * 3. If no parent mapping exists → return empty DTO
        * ============================================================ */

        if (mDataList.isEmpty()) {
            log('[loadMapping] No active/completed mapping found');
            return dto;           
        }

        /* ============================================================
        * 4. Map parent Integration Mapping fields into DTO
        * ============================================================ */

        FEC_Data_Integration_Mapping__c mData = mDataList[0];
        log('[loadMapping] Mapping Id = ' + mData.Id);

        dto.id = mData.Id;
        dto.userTypeId = mData.FEC_User_Type_Id__c;
        dto.channel = mData.FEC_Int_Channel__c;
        dto.intUserTypeId = mData.FEC_Int_User_Type_Id__c;
        dto.productLine = mData.FEC_Int_Product_Line_Id__c;
        dto.serviceType = mData.FEC_Int_Service_Type_Id__c;
        dto.category = mData.FEC_Int_Category_Id__c;
        dto.subCategory = mData.FEC_Int_Sub_Category_Id__c;
        dto.subCode = mData.FEC_Int_Sub_Code_Id__c;
        dto.processChangeStatus = mData.FEC_Process_Change_Status__c;
        dto.status = mData.FEC_Status__c;
        dto.natureOfCaseId = mData.FEC_Nature_Of_Case__c;
        dto.screenCaseId = mData.FEC_ScreenId__c;
        dto.caseStageId = mData.FEC_Case_Stage__c;

        log('[loadMapping] Parent mapping fields mapped');

        /* ============================================================
        * 5. Query child Integration Mapping Info records
        * ============================================================ */

        List<FEC_Data_Integration_Mapping_Info__c> mInfo = [
            SELECT Id,
                FEC_Auto_Mapping_Property__c,
                FEC_CSM_Property__c,
                FEC_CSM_Property_Type__c,
                FEC_Data_Integration_Mapping__c,
                FEC_Integrating_Property__c,
                FEC_Integrating_Property_Type__c,
                FEC_Mandatory__c,
                FEC_Auto_Mapping_Property_Source__c
            FROM FEC_Data_Integration_Mapping_Info__c           
            WHERE FEC_Data_Integration_Mapping__c = :mData.Id            
        ];

        log('[loadMapping] Child mapping records found = ' + mInfo.size());

        /* ============================================================
        * 6. Map child records into PropertyDTO list
        * ============================================================ */

        dto.infos = new List<PropertyDTO>();

        for (FEC_Data_Integration_Mapping_Info__c i : mInfo) {

            PropertyDTO info = new PropertyDTO();

            // Integrating property definition
            info.id = i.Id;
            info.property = i.FEC_Integrating_Property__c;
            info.type = i.FEC_Integrating_Property_Type__c;
            info.mandatory = i.FEC_Mandatory__c;

            // Mapping to CSM field
            info.csmProperty = i.FEC_CSM_Property__c;
            info.csmPropertyType = i.FEC_CSM_Property_Type__c;

            // Auto mapping flag
            info.autoMapping = i.FEC_Auto_Mapping_Property__c;
            info.autoMappingPropertySource = i.FEC_Auto_Mapping_Property_Source__c;

            dto.infos.add(info);

            log(
                '[loadMapping] Child mapped → ' +
                'property=' + info.property +
                ', csmProperty=' + info.csmProperty +
                ', autoMapping=' + info.autoMapping
            );
        }

        /* ============================================================
        * 7. Method exit
        * ============================================================ */

        log('[loadMapping] END - returning MappingDTO');
        return dto;
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
    
    /**
     * Searches CSM additional fields by keyword and filters them by file type.
     *
     * This method is used by LWC autocomplete to dynamically retrieve matching fields
     * while the user is typing.
     *
     * @param keyword   Text entered by the user for searching (minimum 1 character)
     * @param fileType  Integrating Property Type used to filter the results
     * @return          List of matching CsmFieldDTO records
     */
    @AuraEnabled(cacheable=true)
    public static List<CsmFieldDTO> searchAdditionalFields(String keyword, String fileType) {

        log('### searchAdditionalFields START ###');
        log('Input keyword = ' + keyword);
        log('Input fileType = ' + fileType);
    
        if (String.isBlank(keyword)) {
            log('Keyword is blank → return empty list');
            return new List<CsmFieldDTO>();
        }
    
        List<CsmFieldDTO> result = new List<CsmFieldDTO>();
    
        List<FEC_Additional_Field__c> records = [
            SELECT
                Id,
                FEC_Unique_ID__c,
                FEC_Name_VN__c,
                FEC_Type__c,
                Name
            FROM FEC_Additional_Field__c
            WHERE
            (
                FEC_Unique_ID__c LIKE :('%' + keyword + '%')
                OR FEC_Name_VN__c LIKE :('%' + keyword + '%')
                OR Name LIKE :('%' + keyword + '%')
            )
            AND FEC_Type__c LIKE :('%' + fileType + '%')
            ORDER BY FEC_Unique_ID__c
            LIMIT 10
        ];
    
        log('Query result size = ' + records.size());
    
        for (FEC_Additional_Field__c f : records) {
            log(
                'Match → Id=' + f.Id +
                ', UniqueId=' + f.FEC_Unique_ID__c +
                ', NameVN=' + f.FEC_Name_VN__c +
                ', Type=' + f.FEC_Type__c
            );
    
            CsmFieldDTO dto = new CsmFieldDTO();
            dto.id = f.Id;
            dto.name = f.FEC_Unique_ID__c;
            dto.type = f.FEC_Type__c;
    
            result.add(dto);
        }
    
        log('Return result size = ' + result.size());
        log('### searchAdditionalFields END ###');
    
        return result;
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
        String serviceType,
        String userTypeId
    ) {

        // Result list returned to LWC
        List<PropertyDTO> result = new List<PropertyDTO>();
         //Choose correct name field
        Boolean isVietnamese = userLang != null && userLang.startsWith(FEC_FraudConstantCommon.LANG_VI);

        /*
         * Step 1: Query FEC_Map_A_Properties_To_Master_Data_Item__c
         *   by channel (via FEC_Channel_ID__c) + Status + Sync Status
         *   Build map: FEC_Additional_Field__r.FEC_Unique_ID__c → FEC_Additional_Field__c (Id)
         */
        Map<String, String> additionalFieldMap = new Map<String, String>();
        if (String.isNotBlank(channelCode)) {
            String syncedStatus = FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_SYNCED;
            for (FEC_Map_A_Properties_To_Master_Data_Item__c mapItem : [
                SELECT FEC_Additional_Field__c,
                       FEC_Additional_Field__r.FEC_Unique_ID__c
                FROM FEC_Map_A_Properties_To_Master_Data_Item__c
                WHERE FEC_Status__c = true
                  AND FEC_Is_Deleted__c = false
                  AND FEC_User_Type__c =:userTypeId
                  AND FEC_Sync_Status__c = :syncedStatus
                  AND FEC_Channel__r.FEC_Channel_ID__c = :channelCode
            ]) {
                String uniqueId = mapItem.FEC_Additional_Field__r.FEC_Unique_ID__c;
                if (String.isNotBlank(uniqueId) && !additionalFieldMap.containsKey(uniqueId)) {
                    additionalFieldMap.put(uniqueId, uniqueId);
                }
            }
        }

        log('[loadAdditionalProperties] additionalFieldMap size = ' + additionalFieldMap.size());

        /*
         * Step 2: Query AdditionalProperty records
         * - Can be linked at Category, SubCategory, or SubCode level
         * - If FEC_Source_Id__c exists in additionalFieldMap → populate autoMappingPropertySource
         */
        for (FEC_Master_Data_Integration__c rec : [
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
        ]) {

            // Map database record to PropertyDTO
            PropertyDTO dto = new PropertyDTO();
            dto.id = rec.Id;
            dto.property = rec.FEC_Source_Id__c;            
            //Language-aware name
            dto.displayName = isVietnamese
            ? rec.FEC_Source_NameVN__c
            : rec.FEC_Source_Name__c;
            dto.type = rec.FEC_Source_Field_Type__c;
            dto.mandatory = rec.FEC_Source_Is_Mandatory__c;

            // These fields will be populated from UI later
            dto.csmProperty = null;
            dto.csmPropertyType = null;

            // Populate autoMappingPropertySource if FEC_Source_Id__c matches a synced mapping
            if (additionalFieldMap.containsKey(rec.FEC_Source_Id__c)) {
                dto.autoMappingPropertySource = additionalFieldMap.get(rec.FEC_Source_Id__c);
                dto.autoMapping = true;
            } else {
                dto.autoMappingPropertySource = null;
                dto.autoMapping = false;
            }

            result.add(dto);
        }

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
        FEC_FraudConstantCommon.IntegrationMappingField caseField = new FEC_FraudConstantCommon.IntegrationMappingField();
        if(sourceType == caseField.SOURCE_TYPE_INT_USER) {
            result = loadIntUserTypeList(channelCode);
        } else if(sourceType == caseField.SOURCE_TYPE_PRODUCT) {
            result = loadProductLineList(channelCode);
        }else if(sourceType == caseField.SOURCE_TYPE_CASE) {
            result = loadChildServiceTypeList(sourceType, parentId, channelCode);
        }else if(sourceType == caseField.SOURCE_MASTER_CATEGORY || sourceType == caseField.SOURCE_MASTER_SUBCATEGORY || sourceType == caseField.SOURCE_MASTER_SUBCODE) {
            result = loadChildServiceTypeList(sourceType, parentId, channelCode);
        }
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
        FEC_FraudConstantCommon.IntegrationMappingField caseField = new FEC_FraudConstantCommon.IntegrationMappingField();

        //Detect user language        
        Boolean isVietnamese = userLang != null && userLang.startsWith(FEC_FraudConstantCommon.LANG_VI);
        if (sourceType == caseField.SOURCE_TYPE_CASE) {
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
                ? (String) ar.get('nameVN')
                : (String) ar.get('nameEN');
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
                SELECT FEC_Source_Id__c,
                       FEC_Source_NameVN__c,
                       FEC_Source_Name__c
                FROM FEC_Master_Data_Integration__c
                WHERE FEC_Source_Type__c = :sourceType
                  AND FEC_Channel__c = :channelCode
                  AND FEC_Source_Parent_Id__c = :parentId
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
  

    /**
     * Loads all active User Types for UI selection.
     *
     * This method retrieves User Type records that are marked as active
     * and converts them into a lightweight NodeDTO structure for use
     * in Lightning components (e.g. dropdowns, picklists).
     *
     * The result is cacheable to improve UI performance and reduce
     * unnecessary server requests.
     *
     * @return A list of NodeDTO objects representing available User Types
     */
    @AuraEnabled(cacheable=true)
    public static List<NodeDTO> loadUserTypeList() {
        //Detect user language        
        Boolean isVietnamese = userLang != null && userLang.startsWith(FEC_FraudConstantCommon.LANG_VI);
        // List to store queried records
        List<FEC_User_Type__c> records;
        records = [
            SELECT Id, FEC_Code__c, 
            FEC_Name_VN__c, 
            Name 
            FROM FEC_User_Type__c 
            WHERE FEC_Status__c = True 
            ORDER BY FEC_Pos_Order__c
        ];

        // Convert queried records to NodeDTO         
        List<NodeDTO> result = new List<NodeDTO>();
        for (FEC_User_Type__c r : records) {
            String displayName = isVietnamese
                ? r.FEC_Name_VN__c
                : r.Name;
            result.add(
                new NodeDTO(
                    displayName, // label
                    r.Id     // value
                )
            );
        }

        return result;
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
            WHERE FEC_Channel_Status__c = True
            AND FEC_Channel_ID__c = :FEC_FraudConstantCommon.DEFAULT_CHANNEL_INTEGRATION_CODE
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

    /**
     * Loads Internal User Type options (Existing / Non-existing / All)
     * for the given integration channel.
     *
     * Data is derived from FEC_Master_Data_Integration__c by extracting
     * distinct ApplyTo values and mapping them into friendly UI labels.
     *
     * @param channelCode Integration channel identifier
     * @return List of NodeDTO for UI consumption
     */
    private static List<NodeDTO> loadIntUserTypeList(String channelCode) {
         //Detect user language        
         Boolean isVietnamese = userLang != null && userLang.startsWith(FEC_FraudConstantCommon.LANG_VI);
         // List to store queried records
         List<FEC_User_Type__c> records;
         records = [
             SELECT Id, FEC_Code__c, 
             FEC_Name_VN__c, 
             Name 
             FROM FEC_User_Type__c 
             WHERE FEC_Status__c = True 
             ORDER BY FEC_Pos_Order__c
         ];
 
         // Convert queried records to NodeDTO         
         List<NodeDTO> result = new List<NodeDTO>();
         for (FEC_User_Type__c r : records) {
             String displayName = isVietnamese
                 ? r.FEC_Name_VN__c
                 : r.Name;
             result.add(
                 new NodeDTO(
                     displayName, // label
                     r.Id     // value
                 )
             );
         }
 
         return result;
    }
    

    /**
     * Loads Product Line list for the given channel.
     *
     * Retrieves product records from integration master data and
     * converts them into NodeDTO format for UI components.
     *
     * @param channelCode Integration channel identifier
     * @return List of NodeDTO representing product lines
     */
    private static List<NodeDTO> loadProductLineList(String channelCode) {
        //Detect user language       
        Boolean isVietnamese = userLang != null && userLang.startsWith(FEC_FraudConstantCommon.LANG_VI);
        FEC_FraudConstantCommon.IntegrationMappingField caseField = new FEC_FraudConstantCommon.IntegrationMappingField();

        
        // List to store queried records
        List<FEC_Master_Data_Integration__c> records;
        records = [
            SELECT Id, 
            FEC_Source_Id__c, 
            FEC_Source_Name__c, 
            FEC_Source_NameVN__c, 
            FEC_Source_Type__c 
            FROM FEC_Master_Data_Integration__c 
            WHERE FEC_Source_Type__c = :caseField.SOURCE_MASTER_TYPE AND FEC_Channel__c = :channelCode
            ORDER BY FEC_PosOrder__c
        ];

        // Convert queried records to NodeDTO list
        List<NodeDTO> result = new List<NodeDTO>();
        for (FEC_Master_Data_Integration__c r : records) {
            String displayName = isVietnamese
            ? r.FEC_Source_NameVN__c
            : r.FEC_Source_Name__c;
            result.add(
                new NodeDTO(
                    displayName, // label
                    r.FEC_Source_Id__c      // value
                )
            );
        }

        return result;
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