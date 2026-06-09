/**
 * @description Live mirror of FEC_NatureOfCaseTreeService.
 *              Handles CRUD for Live (FEC_*) hierarchy objects:
 *              FEC_Product_Type__c, FEC_Business_Process__c, FEC_Category__c,
 *              FEC_Sub_Category__c, FEC_Sub_Code__c, FEC_Nature_Of_Case__c.
 *              Live objects do NOT have Process_Change_Status__c.
 *              Both Live and MDM tier objects use FEC_Order__c.
 * @date   2026
 */
public with sharing class FEC_LiveNatureOfCaseTreeService {

    // Mapping: child NOC field, parent NOC field (used to inherit lookups when creating child node)
    private static final Map<String, List<String>> NOC_MAPPING = new Map<String, List<String>>{
        FEC_ObjectConstants.OBJ_BUSINESS_PROCESS.toUpperCase() => new List<String>{ FEC_FieldConstants.NOC_FIELD_BUSINESS_PROCESS, FEC_FieldConstants.NOC_FIELD_PRODUCT_TYPE },
        FEC_ObjectConstants.OBJ_CATEGORY.toUpperCase()         => new List<String>{ FEC_FieldConstants.NOC_FIELD_CATEGORY,         FEC_FieldConstants.NOC_FIELD_BUSINESS_PROCESS },
        FEC_ObjectConstants.OBJ_SUB_CATEGORY.toUpperCase()     => new List<String>{ FEC_FieldConstants.NOC_FIELD_SUB_CATEGORY,     FEC_FieldConstants.NOC_FIELD_CATEGORY },
        FEC_ObjectConstants.OBJ_SUB_CODE.toUpperCase()         => new List<String>{ FEC_FieldConstants.NOC_FIELD_SUB_CODE,         FEC_FieldConstants.NOC_FIELD_SUB_CATEGORY }
    };

    private static final List<String> ALL_NOC_LOOKUP_FIELDS = new List<String>{
        FEC_FieldConstants.NOC_FIELD_PRODUCT_TYPE,
        FEC_FieldConstants.NOC_FIELD_BUSINESS_PROCESS,
        FEC_FieldConstants.NOC_FIELD_CATEGORY,
        FEC_FieldConstants.NOC_FIELD_SUB_CATEGORY,
        FEC_FieldConstants.NOC_FIELD_SUB_CODE
    };

    private static final List<String> NOC_INHERITED_DATA_FIELDS = new List<String>{
        FEC_FieldConstants.FIELD_USER_GROUP,
        FEC_FieldConstants.FIELD_CUSTOMER_TYPE
    };

    private static final Pattern VALID_CODE_PATTERN = Pattern.compile('^[a-zA-Z][a-zA-Z0-9_.\\-]*$');

    /**
     * @description Insert a new Live tier record (Product Type, BP, Category, Sub Cat, Sub Code)
     *              and create the corresponding mapping in FEC_Nature_Of_Case__c.
     */
    public static String saveNewLookupNode(
        String strObjectType, String strCustomerType, String strParentId,
        String strName, String strAlias, String strCode, String strNameVN,
        Integer intPosOrder, Boolean isStatus
    ) {
        if (String.isNotBlank(strCode) && !VALID_CODE_PATTERN.matcher(strCode).matches()) {
            throw new AuraHandledException(System.Label.FEC_Error_Special_Characters_ID);
        }

        // Map UI labels → Live object API names
        Map<String, String> labelToApiMap = new Map<String, String>{
            FEC_UIConstants.LABEL_PRODUCT_TYPE      => FEC_ObjectConstants.OBJ_PRODUCT_TYPE,
            FEC_UIConstants.LABEL_BUSINESS_PROCESS  => FEC_ObjectConstants.OBJ_BUSINESS_PROCESS,
            FEC_UIConstants.LABEL_CATEGORY          => FEC_ObjectConstants.OBJ_CATEGORY,
            FEC_UIConstants.LABEL_SUB_CATEGORY      => FEC_ObjectConstants.OBJ_SUB_CATEGORY,
            FEC_UIConstants.LABEL_SUB_CODE          => FEC_ObjectConstants.OBJ_SUB_CODE
        };
        String apiName = labelToApiMap.containsKey(strObjectType)
            ? labelToApiMap.get(strObjectType)
            : strObjectType;

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(apiName)) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' Invalid object type: ' + apiName);
        }
        Schema.SObjectType targetSObjectType = gd.get(apiName);
        Schema.DescribeSObjectResult dsr = targetSObjectType.getDescribe();
        if (!dsr.isCreateable()) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' Create not allowed for object: ' + apiName);
        }

        SObject newRecord = targetSObjectType.newSObject();
        Map<String, Schema.SObjectField> fieldMap = dsr.fields.getMap();
        if (fieldMap.containsKey(FEC_FieldConstants.FIELD_ALIAS))   newRecord.put(FEC_FieldConstants.FIELD_ALIAS, strAlias);
        if (fieldMap.containsKey(FEC_FieldConstants.FIELD_CODE))    newRecord.put(FEC_FieldConstants.FIELD_CODE, strCode);
        if (fieldMap.containsKey(FEC_FieldConstants.FIELD_NAME_VN)) newRecord.put(FEC_FieldConstants.FIELD_NAME_VN, strNameVN);
        if (fieldMap.containsKey(FEC_FieldConstants.FIELD_ACTIVE))  newRecord.put(FEC_FieldConstants.FIELD_ACTIVE, isStatus);
        if (fieldMap.containsKey(FEC_FieldConstants.FIELD_NAME))    newRecord.put(FEC_FieldConstants.FIELD_NAME, strName);
        // Both Live and MDM tier objects use FEC_Order__c
        if (fieldMap.containsKey(FEC_FieldConstants.FIELD_FEC_ORDER)) newRecord.put(FEC_FieldConstants.FIELD_FEC_ORDER, intPosOrder);

        String newRecordId;
        try {
            Database.insert(newRecord);
            newRecordId = (String) newRecord.get(FEC_FieldConstants.FIELD_ID);
        } catch (DmlException e) {
            throw new AuraHandledException(Label.LABEL_ERROR_SAVE_LOOKUP + ' (' + strObjectType + '). ' + Label.FEC_Error_Details + ': ' + e.getMessage());
        }

        // Create the corresponding NOC mapping record
        try {
            if (!FEC_Nature_Of_Case__c.SObjectType.getDescribe().isCreateable()) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' Cannot create Nature of Case mapping record.');
            }

            // FEC_Nature_Of_Case__c.Name is auto-number — do not set it
            FEC_Nature_Of_Case__c nocRecord = new FEC_Nature_Of_Case__c(
                FEC_Customer_Type__c = strCustomerType,
                FEC_Code__c    = strCode + '_' + String.valueOf(Datetime.now().getTime()),
                FEC_Active__c  = isStatus != null ? isStatus : true
            );

            String objectTypeUpper = apiName.toUpperCase();
            if (objectTypeUpper.equalsIgnoreCase(FEC_ObjectConstants.OBJ_PRODUCT_TYPE)) {
                nocRecord.FEC_Product_Type__c = newRecordId;
            } else if (String.isNotBlank(strParentId) && NOC_MAPPING.containsKey(objectTypeUpper)) {
                List<String> mapping = NOC_MAPPING.get(objectTypeUpper);
                String childNocField  = mapping[0];
                String parentNocField = mapping[1];

                String queryFields = String.join(ALL_NOC_LOOKUP_FIELDS, ',');
                queryFields += ',' + String.join(NOC_INHERITED_DATA_FIELDS, ',');
                List<FEC_Nature_Of_Case__c> parentNocs = Database.query(
                    'SELECT ' + queryFields + ' FROM FEC_Nature_Of_Case__c WHERE ' + parentNocField + ' = :strParentId LIMIT 1'
                );
                if (parentNocs == null || parentNocs.isEmpty()) {
                    throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' Could not find Parent Nature of Case record: ' + strParentId);
                }
                FEC_Nature_Of_Case__c parentNoc = parentNocs[0];
                for (String fieldApiName : ALL_NOC_LOOKUP_FIELDS) {
                    Object fieldValue = parentNoc.get(fieldApiName);
                    if (fieldValue != null) {
                        nocRecord.put(fieldApiName, fieldValue);
                    }
                }
                nocRecord.put(childNocField, newRecordId);

                for (String dataField : NOC_INHERITED_DATA_FIELDS) {
                    Object dataValue = parentNoc.get(dataField);
                    if (dataValue != null) {
                        nocRecord.put(dataField, dataValue);
                    }
                }
            }

            Database.insert(nocRecord);
        } catch (Exception e) {
            throw new AuraHandledException(Label.LABEL_ERROR_LINK_NATURE_OF_CASE + ': ' + e.getMessage());
        }
        return newRecordId;
    }

    /**
     * @description Cascade delete: removes mapping NOC records + branch tier records.
     */
    public static void deleteNodeApex(String typeRecordId, String typeName) {
        try {
            Set<Id> ptIds = new Set<Id>();
            Set<Id> bpIds = new Set<Id>();
            Set<Id> catIds = new Set<Id>();
            Set<Id> scatIds = new Set<Id>();
            Set<Id> scodeIds = new Set<Id>();

            String query = 'SELECT Id, FEC_Product_Type__c, FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c FROM FEC_Nature_Of_Case__c WHERE ';

            if (typeName == FEC_UIConstants.LABEL_PRODUCT_TYPE)      query += FEC_FieldConstants.NOC_FIELD_PRODUCT_TYPE + ' = :typeRecordId';
            else if (typeName == FEC_UIConstants.LABEL_BUSINESS_PROCESS) query += FEC_FieldConstants.NOC_FIELD_BUSINESS_PROCESS + ' = :typeRecordId';
            else if (typeName == FEC_UIConstants.LABEL_CATEGORY)         query += FEC_FieldConstants.NOC_FIELD_CATEGORY + ' = :typeRecordId';
            else if (typeName == FEC_UIConstants.LABEL_SUB_CATEGORY)     query += FEC_FieldConstants.NOC_FIELD_SUB_CATEGORY + ' = :typeRecordId';
            else if (typeName == FEC_UIConstants.LABEL_SUB_CODE)         query += FEC_FieldConstants.NOC_FIELD_SUB_CODE + ' = :typeRecordId';
            else throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' Unknown node type: ' + typeName);

            List<FEC_Nature_Of_Case__c> relatedNocs = Database.query(query);
            for (FEC_Nature_Of_Case__c n : relatedNocs) {
                if (n.FEC_Product_Type__c     != null) ptIds.add(n.FEC_Product_Type__c);
                if (n.FEC_Business_Process__c != null) bpIds.add(n.FEC_Business_Process__c);
                if (n.FEC_Category__c         != null) catIds.add(n.FEC_Category__c);
                if (n.FEC_Sub_Category__c     != null) scatIds.add(n.FEC_Sub_Category__c);
                if (n.FEC_Sub_Code__c         != null) scodeIds.add(n.FEC_Sub_Code__c);
            }

            if (!relatedNocs.isEmpty()) delete relatedNocs;

            if (typeName == FEC_UIConstants.LABEL_SUB_CODE) {
                deleteRecords(FEC_ObjectConstants.OBJ_SUB_CODE, scodeIds);
            } else if (typeName == FEC_UIConstants.LABEL_SUB_CATEGORY) {
                deleteRecords(FEC_ObjectConstants.OBJ_SUB_CODE, scodeIds);
                deleteRecords(FEC_ObjectConstants.OBJ_SUB_CATEGORY, scatIds);
            } else if (typeName == FEC_UIConstants.LABEL_CATEGORY) {
                deleteRecords(FEC_ObjectConstants.OBJ_SUB_CODE, scodeIds);
                deleteRecords(FEC_ObjectConstants.OBJ_SUB_CATEGORY, scatIds);
                deleteRecords(FEC_ObjectConstants.OBJ_CATEGORY, catIds);
            } else if (typeName == FEC_UIConstants.LABEL_BUSINESS_PROCESS) {
                deleteRecords(FEC_ObjectConstants.OBJ_SUB_CODE, scodeIds);
                deleteRecords(FEC_ObjectConstants.OBJ_SUB_CATEGORY, scatIds);
                deleteRecords(FEC_ObjectConstants.OBJ_CATEGORY, catIds);
                deleteRecords(FEC_ObjectConstants.OBJ_BUSINESS_PROCESS, bpIds);
            } else if (typeName == FEC_UIConstants.LABEL_PRODUCT_TYPE) {
                deleteRecords(FEC_ObjectConstants.OBJ_SUB_CODE, scodeIds);
                deleteRecords(FEC_ObjectConstants.OBJ_SUB_CATEGORY, scatIds);
                deleteRecords(FEC_ObjectConstants.OBJ_CATEGORY, catIds);
                deleteRecords(FEC_ObjectConstants.OBJ_BUSINESS_PROCESS, bpIds);
                deleteRecords(FEC_ObjectConstants.OBJ_PRODUCT_TYPE, ptIds);
            }
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    private static void deleteRecords(String objName, Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return;
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(objName)) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' Invalid object for delete: ' + objName);
        }
        Schema.DescribeSObjectResult dsr = gd.get(objName).getDescribe();
        if (!dsr.isDeletable()) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' Delete not allowed for object: ' + objName);
        }
        List<SObject> toDelete = Database.query('SELECT Id FROM ' + objName + ' WHERE Id IN :ids');
        if (!toDelete.isEmpty()) {
            Database.delete(toDelete);
        }
    }

    /**
     * @description Update a single tier node by type and Id.
     */
    public static void updateNode(Map<String, Object> updateData) {
        String nodeId   = (String) updateData.get(FEC_UIConstants.PAYLOAD_IDTYPE);
        String nodeType = (String) updateData.get(FEC_UIConstants.PAYLOAD_TYPE);

        SObject targetSObject;
        if (nodeType == FEC_UIConstants.LABEL_PRODUCT_TYPE)         targetSObject = [SELECT Id FROM FEC_Product_Type__c     WHERE Id = :nodeId LIMIT 1];
        else if (nodeType == FEC_UIConstants.LABEL_BUSINESS_PROCESS) targetSObject = [SELECT Id FROM FEC_Business_Process__c WHERE Id = :nodeId LIMIT 1];
        else if (nodeType == FEC_UIConstants.LABEL_CATEGORY)         targetSObject = [SELECT Id FROM FEC_Category__c         WHERE Id = :nodeId LIMIT 1];
        else if (nodeType == FEC_UIConstants.LABEL_SUB_CATEGORY)     targetSObject = [SELECT Id FROM FEC_Sub_Category__c     WHERE Id = :nodeId LIMIT 1];
        else if (nodeType == FEC_UIConstants.LABEL_SUB_CODE)         targetSObject = [SELECT Id FROM FEC_Sub_Code__c         WHERE Id = :nodeId LIMIT 1];
        else throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + String.format(Label.FEC_Error_Unknown_Node_Type, new List<String>{nodeType}));

        if (targetSObject == null) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' Record not found: ' + nodeId);
        }
        if (!targetSObject.getSObjectType().getDescribe().isUpdateable()) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' Update not allowed for this record type');
        }

        Map<String, Schema.SObjectField> fm = targetSObject.getSObjectType().getDescribe().fields.getMap();
        if (fm.containsKey(FEC_FieldConstants.FIELD_ALIAS) && fm.get(FEC_FieldConstants.FIELD_ALIAS).getDescribe().isUpdateable())     targetSObject.put(FEC_FieldConstants.FIELD_ALIAS,   (String) updateData.get(FEC_UIConstants.PAYLOAD_ALIAS));
        if (fm.containsKey(FEC_FieldConstants.FIELD_CODE) && fm.get(FEC_FieldConstants.FIELD_CODE).getDescribe().isUpdateable())       targetSObject.put(FEC_FieldConstants.FIELD_CODE,    (String) updateData.get(FEC_UIConstants.PAYLOAD_CODE));
        if (fm.containsKey(FEC_FieldConstants.FIELD_NAME_VN) && fm.get(FEC_FieldConstants.FIELD_NAME_VN).getDescribe().isUpdateable()) targetSObject.put(FEC_FieldConstants.FIELD_NAME_VN, (String) updateData.get(FEC_UIConstants.PAYLOAD_NAMEVN));

        // Status: prefer FEC_Active__c (Live default); fallback to FEC_Status__c
        String statusField = fm.containsKey(FEC_FieldConstants.FIELD_ACTIVE) ? FEC_FieldConstants.FIELD_ACTIVE
                             : (fm.containsKey(FEC_FieldConstants.FIELD_STATUS) ? FEC_FieldConstants.FIELD_STATUS : null);
        if (statusField != null && fm.get(statusField).getDescribe().isUpdateable()) {
            Object statusVal = updateData.get(FEC_UIConstants.PAYLOAD_STATUS);
            targetSObject.put(statusField, statusVal != null ? Boolean.valueOf(statusVal) : false);
        }

        if (fm.containsKey(FEC_FieldConstants.FIELD_NAME) && fm.get(FEC_FieldConstants.FIELD_NAME).getDescribe().isUpdateable()) targetSObject.put(FEC_FieldConstants.FIELD_NAME, (String) updateData.get(FEC_UIConstants.PAYLOAD_NAMEEN));

        // Both Live and MDM tier objects use FEC_Order__c
        Object posVal = updateData.get(FEC_UIConstants.PAYLOAD_POSORDER);
        if (fm.containsKey(FEC_FieldConstants.FIELD_FEC_ORDER) && fm.get(FEC_FieldConstants.FIELD_FEC_ORDER).getDescribe().isUpdateable()) {
            targetSObject.put(FEC_FieldConstants.FIELD_FEC_ORDER, posVal != null ? Decimal.valueOf(String.valueOf(posVal)) : null);
        }

        try {
            update targetSObject;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
}