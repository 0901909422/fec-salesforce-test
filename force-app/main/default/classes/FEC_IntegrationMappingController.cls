/**
 * Controller for Integration Mapping screen
 * - Provide hierarchy data (UserType → Channel → Product → ...)
 * - Provide additional property mapping data
 */
public with sharing class FEC_IntegrationMappingController{

    /* =====================================================
     * DTOs (Data Transfer Objects)
     * Used to send simple data structures to LWC
     * ===================================================== */

     public class SaveResultDTO {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id mappingId;
    }
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
        @AuraEnabled public String processChangeStatus;
        @AuraEnabled public Boolean status;
        @AuraEnabled public List<PropertyDTO> infos;
    }
    
   
    
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
        @AuraEnabled public String vnName;            // Vietnamese display name
        @AuraEnabled public String type;              // Data type (string, list, file...)
        @AuraEnabled public Boolean mandatory;         // Mandatory flag
        @AuraEnabled public String csmPropertyId;        // Selected CSM property id
        @AuraEnabled public String csmProperty;        // Selected CSM property
        @AuraEnabled public String csmPropertyType;    // Type of CSM property
        @AuraEnabled public Boolean autoMapping;       // Auto-mapping flag
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
    
        SaveResultDTO result = new SaveResultDTO();
        result.success = false;
    
        String processChangeStatus = 'New';
    
        try {
            /* ================= VALIDATE PAYLOAD ================= */
            if (String.isBlank(payloadJson)) {
                throw new AuraHandledException('Payload is empty');
            }
    
            Map<String, Object> payload =
                (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
    
            Map<String, Object> header =
                (Map<String, Object>) payload.get('header');
    
            List<Object> details =
                (List<Object>) payload.get('details');
    
            String natureOfCaseId = (String) header.get('natureOfCaseId');
    
            System.debug('[SAVE] NatureOfCaseId=' + natureOfCaseId);
    
            /* ================= CHECK EXISTING ================= */
            List<FEC_Data_Integration_Mapping__c> exist = [
                SELECT Id
                FROM FEC_Data_Integration_Mapping__c
                WHERE FEC_Nature_Of_Case__c = :natureOfCaseId
                  AND FEC_Status__c = false
                  AND FEC_Process_Change_Status__c = :processChangeStatus
                LIMIT 1
            ];
    
            Boolean isUpdate = !exist.isEmpty();
            System.debug('[SAVE] isUpdate=' + isUpdate);
            String message = 'Integration mapping created successfully';
    
            /* ================= UPSERT PARENT ================= */
            FEC_Data_Integration_Mapping__c mapping;
    
            if (isUpdate) {
                // UPDATE existing
                mapping = exist[0];
                System.debug('[SAVE] Updating mappingId=' + mapping.Id);
                message = 'Integration mapping updated successfully';
            } else {
                // INSERT new
                mapping = new FEC_Data_Integration_Mapping__c();
                mapping.FEC_Nature_Of_Case__c = natureOfCaseId;
                mapping.FEC_Process_Change_Status__c = processChangeStatus;
                mapping.FEC_Status__c = false;
                System.debug('[SAVE] Creating new mapping');
            }
    
            // Common fields (insert + update)
            mapping.FEC_User_Type_Id__c        = (String) header.get('userType');
            mapping.FEC_Int_Channel__c         = (String) header.get('channel');
            mapping.FEC_Int_User_Type_Id__c    = (String) header.get('intUserType');
            mapping.FEC_Int_Product_Line_Id__c = (String) header.get('productLine');
            mapping.FEC_Int_Service_Type_Id__c = (String) header.get('serviceType');
            mapping.FEC_Int_Category_Id__c     = (String) header.get('category');
            mapping.FEC_Int_Sub_Category_Id__c = (String) header.get('subCategory');
            mapping.FEC_Int_Sub_Code_Id__c     = (String) header.get('subCode');
    
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
                    System.debug('[SAVE] Deleted old child records=' + oldInfos.size());
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
                info.FEC_Integrating_Property__c      = (String) row.get('property');
                info.FEC_Integrating_Property_Type__c = (String) row.get('type');
                info.FEC_CSM_Property__c              = (String) row.get('csmProperty');
                info.FEC_CSM_Property_Type__c         = (String) row.get('csmPropertyType');
                info.FEC_Auto_Mapping_Property__c     = (Boolean) row.get('autoMapping');
                info.FEC_Mandatory__c                 = (Boolean) row.get('mandatory');
    
                infos.add(info);
            }
    
            if (!infos.isEmpty()) {
                insert infos;
                System.debug('[SAVE] Inserted child records=' + infos.size());
            }
    
            /* ================= SUCCESS ================= */
            result.success = true;
            result.mappingId = mapping.Id;
            result.message = message;
    
            return result;
    
        } catch (DmlException dmlEx) {
            System.debug('[SAVE ERROR][DML] ' + dmlEx.getMessage());
            result.message = 'Database error: ' + dmlEx.getDmlMessage(0);
            return result;
    
        } catch (Exception ex) {
            System.debug('[SAVE ERROR] ' + ex.getMessage());
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
     * @param natureOfCaseId  Id of Nature Of Case (passed from parent LWC)
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
    @AuraEnabled(cacheable=true)
    public static MappingDTO loadMapping(String natureOfCaseId) {

        /* ============================================================
        * 1. Method entry & input validation
        * ============================================================ */

        System.debug('[loadMapping] START');
        System.debug('[loadMapping] natureOfCaseId = ' + natureOfCaseId);
        String processChangeStatusDone = 'Done';
        String processChangeStatusNew = 'New';
        // Defensive programming:
        // If Nature Of Case Id is null/blank, immediately return empty DTO
        if (String.isBlank(natureOfCaseId)) {
            System.debug('[loadMapping] natureOfCaseId is blank → return empty DTO');
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
                FEC_User_Type_Id__c                
            FROM FEC_Data_Integration_Mapping__c
            WHERE FEC_Nature_Of_Case__c = :natureOfCaseId
            AND FEC_Status__c = true
            AND FEC_Process_Change_Status__c = :processChangeStatusDone
            LIMIT 1
        ];

        System.debug('[loadMapping] Parent mapping records found = ' + mDataList.size());

        // Initialize return object (empty by default)
        MappingDTO dto = new MappingDTO();

        /* ============================================================
        * 3. If no parent mapping exists → return empty DTO
        * ============================================================ */

        if (mDataList.isEmpty()) {
            System.debug('[loadMapping] No active/completed mapping found');
            //Check more New process change status
            mDataList = [
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
                FEC_User_Type_Id__c                
                FROM FEC_Data_Integration_Mapping__c
                WHERE FEC_Nature_Of_Case__c = :natureOfCaseId
                AND FEC_Status__c = false
                AND FEC_Process_Change_Status__c = :processChangeStatusNew
                LIMIT 1
            ];
            if (mDataList.isEmpty()) {
                return dto;
            }
           
        }

        /* ============================================================
        * 4. Map parent Integration Mapping fields into DTO
        * ============================================================ */

        FEC_Data_Integration_Mapping__c mData = mDataList[0];
        System.debug('[loadMapping] Mapping Id = ' + mData.Id);

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

        System.debug('[loadMapping] Parent mapping fields mapped');

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
                FEC_Mandatory__c
            FROM FEC_Data_Integration_Mapping_Info__c           
            WHERE FEC_Data_Integration_Mapping__c = :mData.Id            
        ];

        System.debug('[loadMapping] Child mapping records found = ' + mInfo.size());

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

            dto.infos.add(info);

            System.debug(
                '[loadMapping] Child mapped → ' +
                'property=' + info.property +
                ', csmProperty=' + info.csmProperty +
                ', autoMapping=' + info.autoMapping
            );
        }

        /* ============================================================
        * 7. Method exit
        * ============================================================ */

        System.debug('[loadMapping] END - returning MappingDTO');
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
    
    @AuraEnabled(cacheable=true)
    public static List<CsmFieldDTO> searchAdditionalFields(String keyword) {

        if (String.isBlank(keyword)) {
            return new List<CsmFieldDTO>();
        }

        List<CsmFieldDTO> result = new List<CsmFieldDTO>();

        for (FEC_Additional_Field__c f : [
            SELECT Id,FEC_Unique_ID__c,FEC_Name_VN__c,FEC_Type__c
            FROM FEC_Additional_Field__c
            WHERE FEC_Unique_ID__c LIKE :('%' + keyword + '%') OR FEC_Name_VN__c LIKE :('%' + keyword + '%')
            ORDER BY FEC_Unique_ID__c
            LIMIT 10
        ]) {
            CsmFieldDTO dto = new CsmFieldDTO();
            dto.id = f.Id;
            dto.name = f.FEC_Unique_ID__c;
            dto.type = f.FEC_Type__c;
            result.add(dto);
        }

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
        String channelCode
    ) {

        // Result list returned to LWC
        List<PropertyDTO> result = new List<PropertyDTO>();

        /*
         * Query AdditionalProperty records
         * - Can be linked at Category, SubCategory, or SubCode level
         */
        for (FEC_Master_Data_Integration__c rec : [
            SELECT Id,
                   FEC_Source_Id__c,
                   FEC_Source_NameVN__c,
                   FEC_Source_Field_Type__c,
                   FEC_Source_Is_Mandatory__c
            FROM FEC_Master_Data_Integration__c
            WHERE FEC_Source_Type__c = 'AdditionalProperty'
              AND FEC_Channel__c = :channelCode
              AND (
                   FEC_Source_Parent_Id__c = :subCode
                OR FEC_Source_Parent_Id__c = :category
                OR FEC_Source_Parent_Id__c = :subCategory
              )
            ORDER BY FEC_Source_Id__c
        ]) {

            // Map database record to PropertyDTO
            PropertyDTO dto = new PropertyDTO();
            dto.id = rec.Id;
            dto.property = rec.FEC_Source_Id__c;
            dto.vnName = rec.FEC_Source_NameVN__c;
            dto.type = rec.FEC_Source_Field_Type__c;
            dto.mandatory = rec.FEC_Source_Is_Mandatory__c;

            // These fields will be populated from UI later
            dto.csmProperty = null;
            dto.csmPropertyType = null;
            dto.autoMapping = false;

            result.add(dto);
        }

        return result;
    }
    private static List<NodeDTO> loadHierarchyMasterInt(String sourceType, String parentId, String channelCode) {
        List<NodeDTO> result = new List<NodeDTO>();
        if(sourceType == 'IntUserType') {
            result = loadIntUserTypeList(channelCode);
        } else if(sourceType == 'ProductLine') {
            result = loadProductLineList(channelCode);
        }else if(sourceType == 'CaseType') {
            result = loadChildServiceTypeList(sourceType, parentId, channelCode);
        }else if(sourceType == 'Category' || sourceType == 'SubCategory' || sourceType == 'SubCode') {
            result = loadChildServiceTypeList(sourceType, parentId, channelCode);
        }
        return result;
    }

    private static List<NodeDTO> loadChildServiceTypeList(String sourceType, String parentId, String channelCode) {
        List<NodeDTO> result = new List<NodeDTO>();
        if (sourceType == 'CaseType') {
            List<AggregateResult> ars = [
                SELECT FEC_Source_Id__c sourceId,
                    FEC_Source_NameVN__c nameVN,
                    MIN(FEC_PosOrder__c) minPos
                FROM FEC_Master_Data_Integration__c
                WHERE FEC_Source_Type__c = :sourceType AND FEC_Channel__c = :channelCode
                GROUP BY FEC_Source_Id__c, FEC_Source_NameVN__c
            ];
            for (AggregateResult ar : ars) {
            result.add(
                new NodeDTO(
                    (String) ar.get('nameVN'),
                    (String) ar.get('sourceId')
                )
            );
        }
        }
        else {
            for (FEC_Master_Data_Integration__c r : [
            SELECT FEC_Source_Id__c, FEC_Source_NameVN__c
            FROM FEC_Master_Data_Integration__c
            WHERE FEC_Source_Type__c = :sourceType
            AND FEC_Source_Parent_Id__c = :parentId
            AND FEC_Channel__c = :channelCode
            ORDER BY FEC_PosOrder__c
            ]) {
                result.add(new NodeDTO(r.FEC_Source_NameVN__c, r.FEC_Source_Id__c));
            }
        }

        

        return result;
    }
  

    @AuraEnabled(cacheable=true)
    public static List<NodeDTO> loadUserTypeList() {
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
            
            result.add(
                new NodeDTO(
                    r.FEC_Name_VN__c, // label
                    r.Id     // value
                )
            );
        }

        return result;
    }

    /**
     * Load Internal User Type list (Existing / Non-existing)
     */
    private static List<NodeDTO> loadIntUserTypeList(String channelCode) {

        // Result list
        List<NodeDTO> result = new List<NodeDTO>();

        /*
        * Aggregate query to get DISTINCT ApplyTo values
        */
        List<AggregateResult> aggResults = [
            SELECT FEC_ApplyTo__c applyTo
            FROM FEC_Master_Data_Integration__c
            WHERE FEC_Channel__c = :channelCode
            GROUP BY FEC_ApplyTo__c
            ORDER BY FEC_ApplyTo__c DESC
        ];

        for (AggregateResult ar : aggResults) {

            String applyTo = (String) ar.get('applyTo');
            String label;
            String value;

            if (applyTo == 'EXISTING') {
                label = 'Existing Customer';
                value = 'EXISTING';
            } else if(applyTo == 'ALL') {
                label = applyTo;
                value = applyTo;
            }
            else {
                label = 'Non Existing Customer';
                value = 'NONEXISTING';
            }

            result.add(new NodeDTO(label, value));
        }

        return result;
    }


    private static List<NodeDTO> loadProductLineList(String channelCode) {

        // List to store queried records
        List<FEC_Master_Data_Integration__c> records;
        records = [
            SELECT Id, 
            FEC_Source_Id__c, 
            FEC_Source_Name__c, 
            FEC_Source_NameVN__c, 
            FEC_Source_Type__c 
            FROM FEC_Master_Data_Integration__c 
            WHERE FEC_Source_Type__c='Product' AND FEC_Channel__c = :channelCode
            ORDER BY FEC_PosOrder__c
        ];

        // Convert queried records to NodeDTO list
        List<NodeDTO> result = new List<NodeDTO>();
        for (FEC_Master_Data_Integration__c r : records) {
            result.add(
                new NodeDTO(
                    r.FEC_Source_NameVN__c, // label
                    r.FEC_Source_Id__c      // value
                )
            );
        }

        return result;
    }

    
    @AuraEnabled(cacheable=true)
    public static List<NodeDTO> loadChannelList() {

        // List to store queried records
        List<FEC_Case_Channel__c> records;
        records = [
            SELECT Id,
            FEC_Code__c,            
            FEC_Name_VN__c
            FROM FEC_Case_Channel__c
            WHERE FEC_Status__c = True
        ];

        // Convert queried records to NodeDTO list
        List<NodeDTO> result = new List<NodeDTO>();
        for (FEC_Case_Channel__c r : records) {
            result.add(
                new NodeDTO(
                    r.FEC_Name_VN__c, // label
                    r.FEC_Code__c      // value
                )
            );
        }

        return result;
    }
}