public with sharing class FEC_NatureOfCaseTreeService {
    // Centralized data access and mapping helpers for NatureOfCase tree

    @AuraEnabled(cacheable=true)
    public static List<FEC_MDM_Nature_Of_Case__c> fetchAllMasterDataMappings() {
        List<FEC_MDM_Nature_Of_Case__c> result = [
            SELECT 
                Id, 
                Name, 
                Process_Change_Status__c, 
                FEC_Customer_Type__c, 

                FEC_Product_Type_Name__c, 
                FEC_Product_Type_Name__r.Name, 
                FEC_Product_Type_Name__r.FEC_Alias__c, 
                FEC_Product_Type_Name__r.FEC_Code__c, 
                FEC_Product_Type_Name__r.FEC_Name_VN__c, 
                FEC_Product_Type_Name__r.FEC_Pos_Order__c, 
                FEC_Product_Type_Name__r.FEC_Status__c, 
                FEC_Product_Type_Name__r.Process_Change_Status__c, 

                FEC_Business_Process_Name__c, 
                FEC_Business_Process_Name__r.Name, 
                FEC_Business_Process_Name__r.FEC_Alias__c, 
                FEC_Business_Process_Name__r.FEC_Code__c, 
                FEC_Business_Process_Name__r.FEC_Name_VN__c, 
                FEC_Business_Process_Name__r.FEC_Pos_Order__c, 
                FEC_Business_Process_Name__r.FEC_Status__c, 
                FEC_Business_Process_Name__r.Process_Change_Status__c, 

                FEC_Category_Name__c, 
                FEC_Category_Name__r.Name, 
                FEC_Category_Name__r.FEC_Alias__c, 
                FEC_Category_Name__r.FEC_Code__c, 
                FEC_Category_Name__r.FEC_Name_VN__c, 
                FEC_Category_Name__r.FEC_Pos_Order__c, 
                FEC_Category_Name__r.FEC_Status__c, 
                FEC_Category_Name__r.Process_Change_Status__c,  

                FEC_Sub_Category_Name__c, 
                FEC_Sub_Category_Name__r.Name, 
                FEC_Sub_Category_Name__r.FEC_Alias__c, 
                FEC_Sub_Category_Name__r.FEC_Code__c, 
                FEC_Sub_Category_Name__r.FEC_Name_VN__c, 
                FEC_Sub_Category_Name__r.FEC_Pos_Order__c, 
                FEC_Sub_Category_Name__r.FEC_Status__c, 
                FEC_Sub_Category_Name__r.Process_Change_Status__c, 

                FEC_Sub_Code__c, 
                FEC_Sub_Code__r.Name,
                FEC_Sub_Code__r.FEC_Alias__c, 
                FEC_Sub_Code__r.FEC_Code__c, 
                FEC_Sub_Code__r.FEC_Name_VN__c, 
                FEC_Sub_Code__r.FEC_Pos_Order__c, 
                FEC_Sub_Code__r.FEC_Status__c,
                FEC_Sub_Code__r.Process_Change_Status__c
            FROM FEC_MDM_Nature_Of_Case__c
            ORDER BY 
                FEC_Product_Type_Name__r.FEC_Pos_Order__c ASC,
                FEC_Business_Process_Name__r.FEC_Pos_Order__c ASC,
                FEC_Category_Name__r.FEC_Pos_Order__c ASC,
                FEC_Sub_Category_Name__r.FEC_Pos_Order__c ASC,
                FEC_Sub_Code__r.FEC_Pos_Order__c ASC
        ];
        // Enforce FLS before returning
        result = (List<FEC_MDM_Nature_Of_Case__c>) Security.stripInaccessible(AccessType.READABLE, result).getRecords();
        return result;
    }

    public static String saveNewLookupNode(String strObjectType, String strCustomerType, String strParentId,String strName, String strAlias, String strCode, String strNameVN, Integer intPosOrder, Boolean isStatus) {
        String newRecordId;
        Map<String, String> labelToApiMap = new Map<String, String>();
        labelToApiMap.put(FEC_Constants.LABEL_PRODUCT_TYPE, FEC_Constants.OBJ_MDM_PRODUCT_TYPE);
        labelToApiMap.put(FEC_Constants.LABEL_BUSINESS_PROCESS, FEC_Constants.OBJ_MDM_BUSINESS_PROCESS);
        labelToApiMap.put(FEC_Constants.LABEL_CATEGORY, FEC_Constants.OBJ_MDM_CATEGORY);
        labelToApiMap.put(FEC_Constants.LABEL_SUB_CATEGORY, FEC_Constants.OBJ_MDM_SUB_CATEGORY);
        labelToApiMap.put(FEC_Constants.LABEL_SUB_CODE, FEC_Constants.OBJ_MDM_SUB_CODE);
        
        String apiName = labelToApiMap.containsKey(strObjectType)
            ? labelToApiMap.get(strObjectType)
            : strObjectType;
        
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(apiName)) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Invalid object type: ' + apiName);
        }
        Schema.SObjectType targetSObjectType = gd.get(apiName);
        Schema.DescribeSObjectResult dsr = targetSObjectType.getDescribe();
        if (!dsr.isCreateable()) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Create not allowed for object: ' + apiName);
        }
        
        SObject newRecord = targetSObjectType.newSObject();
        Map<String, Schema.SObjectField> fieldMap = dsr.fields.getMap();
        if (fieldMap.containsKey(FEC_Constants.FIELD_ALIAS)) newRecord.put(FEC_Constants.FIELD_ALIAS, strAlias);
        if (fieldMap.containsKey(FEC_Constants.FIELD_CODE)) newRecord.put(FEC_Constants.FIELD_CODE, strCode);
        if (fieldMap.containsKey(FEC_Constants.FIELD_NAME_VN)) newRecord.put(FEC_Constants.FIELD_NAME_VN, strNameVN);
        if (fieldMap.containsKey(FEC_Constants.FIELD_STATUS)) newRecord.put(FEC_Constants.FIELD_STATUS, isStatus);
        if (fieldMap.containsKey(FEC_Constants.FIELD_NAME)) newRecord.put(FEC_Constants.FIELD_NAME, strName);
        if (fieldMap.containsKey(FEC_Constants.FIELD_POS_ORDER)) newRecord.put(FEC_Constants.FIELD_POS_ORDER, intPosOrder);
        
        try {
            Database.insert(newRecord);
            newRecordId = (String)newRecord.get(FEC_Constants.FIELD_ID);
        } catch (DmlException e) {
            throw new AuraHandledException('Lỗi khi lưu bản ghi Lookup (' + strObjectType + '). Chi tiết lỗi: ' + e.getMessage());
        }
        
        try {
            String objectTypeUpper = apiName.toUpperCase();
            
            // Ensure creation allowed on mapping object
            if (!Schema.getGlobalDescribe().containsKey('FEC_MDM_Nature_Of_Case__c') || !FEC_MDM_Nature_Of_Case__c.sObjectType.getDescribe().isCreateable()) {
                throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Cannot create Nature of Case mapping record.');
            }
            
            FEC_MDM_Nature_Of_Case__c nocRecord = new FEC_MDM_Nature_Of_Case__c(
                Name = strCode,
                FEC_Customer_Type__c = strCustomerType
            );
            
            if (objectTypeUpper.equalsIgnoreCase(FEC_Constants.KEY_MDM_PRODUCT_TYPE)) {
                nocRecord.FEC_Product_Type_Name__c = newRecordId;
            } else if (strParentId != null && !String.isBlank(strParentId) && NOC_MAPPING.containsKey(objectTypeUpper)) {
                List<String> mapping = NOC_MAPPING.get(objectTypeUpper);
                String childNocField = mapping[0];
                String parentNocField = mapping[1];
                
                String queryFields = String.join(ALL_NOC_LOOKUP_FIELDS, ',');
                List<FEC_MDM_Nature_Of_Case__c> parentNocs = Database.query(
                    'SELECT ' + queryFields + ' FROM FEC_MDM_Nature_Of_Case__c WHERE ' + parentNocField + ' = :strParentId'
                );
                if (parentNocs == null || parentNocs.isEmpty()) {
                    throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Could not find Parent Nature of Case record: ' + strParentId);
                }
                FEC_MDM_Nature_Of_Case__c parentNoc = parentNocs[0];
                for (String fieldApiName : ALL_NOC_LOOKUP_FIELDS) {
                    Object fieldValue = parentNoc.get(fieldApiName);
                    if (fieldValue != null) {
                        nocRecord.put(fieldApiName, fieldValue);
                    }
                }
                nocRecord.put(childNocField, newRecordId);
            }
            
            Database.insert(nocRecord);
        } catch (Exception e) {
            throw new AuraHandledException('Lỗi không xác định trong quá trình liên kết FEC_MDM_Nature_Of_Case__c: ' + e.getMessage());
        }
        return newRecordId;
    }

    public static void deleteNodeApex(String typeRecordId, String typeName) {
        try {
            Set<Id> ptIds = new Set<Id>();
            Set<Id> bpIds = new Set<Id>();
            Set<Id> catIds = new Set<Id>();
            Set<Id> scatIds = new Set<Id>();
            Set<Id> scodeIds = new Set<Id>();
            
            String query = FEC_Constants.SQL_SELECT_NOC_FIELDS;
            
            if (typeName == FEC_Constants.LABEL_PRODUCT_TYPE) query += FEC_Constants.NOC_FIELD_PRODUCT_TYPE + ' = :typeRecordId';
            else if (typeName == FEC_Constants.LABEL_BUSINESS_PROCESS) query += FEC_Constants.NOC_FIELD_BUSINESS_PROCESS + ' = :typeRecordId';
            else if (typeName == FEC_Constants.LABEL_CATEGORY) query += FEC_Constants.NOC_FIELD_CATEGORY + ' = :typeRecordId';
            else if (typeName == FEC_Constants.LABEL_SUB_CATEGORY) query += FEC_Constants.NOC_FIELD_SUB_CATEGORY + ' = :typeRecordId';
            else if (typeName == FEC_Constants.LABEL_SUB_CODE) query += FEC_Constants.NOC_FIELD_SUB_CODE + ' = :typeRecordId';
            
            List<FEC_MDM_Nature_Of_Case__c> relatedNocs = Database.query(query);
            
            for (FEC_MDM_Nature_Of_Case__c n : relatedNocs) {
                if (n.FEC_Product_Type_Name__c != null) ptIds.add(n.FEC_Product_Type_Name__c);
                if (n.FEC_Business_Process_Name__c != null) bpIds.add(n.FEC_Business_Process_Name__c);
                if (n.FEC_Category_Name__c != null) catIds.add(n.FEC_Category_Name__c);
                if (n.FEC_Sub_Category_Name__c != null) scatIds.add(n.FEC_Sub_Category_Name__c);
                if (n.FEC_Sub_Code__c != null) scodeIds.add(n.FEC_Sub_Code__c);
            }
            
            // Delete mappings first
            if (!relatedNocs.isEmpty()) delete relatedNocs;
            
            // Delete related master records for branch
            if (typeName == FEC_Constants.LABEL_SUB_CODE) {
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CODE, scodeIds);
            }
            else if (typeName == FEC_Constants.LABEL_SUB_CATEGORY) {
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CODE, scodeIds);
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CATEGORY, scatIds);
            }
            else if (typeName == FEC_Constants.LABEL_CATEGORY) {
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CODE, scodeIds);
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CATEGORY, scatIds);
                deleteRecords(FEC_Constants.OBJ_MDM_CATEGORY, catIds);
            }
            else if (typeName == FEC_Constants.LABEL_BUSINESS_PROCESS) {
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CODE, scodeIds);
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CATEGORY, scatIds);
                deleteRecords(FEC_Constants.OBJ_MDM_CATEGORY, catIds);
                deleteRecords(FEC_Constants.OBJ_MDM_BUSINESS_PROCESS, bpIds);
            }
            else if (typeName == FEC_Constants.LABEL_PRODUCT_TYPE) {
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CODE, scodeIds);
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CATEGORY, scatIds);
                deleteRecords(FEC_Constants.OBJ_MDM_CATEGORY, catIds);
                deleteRecords(FEC_Constants.OBJ_MDM_BUSINESS_PROCESS, bpIds);
                deleteRecords(FEC_Constants.OBJ_MDM_PRODUCT_TYPE, ptIds);
            }
        } catch (Exception e) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    private static void deleteRecords(String objName, Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return;
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(objName)) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Invalid object for delete: ' + objName);
        }
        Schema.DescribeSObjectResult dsr = gd.get(objName).getDescribe();
        if (!dsr.isDeletable()) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Delete not allowed for object: ' + objName);
        }
        String dmlQuery = 'SELECT Id FROM ' + objName + ' WHERE Id IN :ids';
        List<SObject> toDelete = Database.query(dmlQuery);
        if (!toDelete.isEmpty()) {
            Database.delete(toDelete);
        }
    }

    public static void updateMultipleNodes(List<Map<String, Object>> listData) {
        List<FEC_MDM_Product_Type__c> ptUpdates = new List<FEC_MDM_Product_Type__c>();
        List<FEC_MDM_Business_Process__c> bpUpdates = new List<FEC_MDM_Business_Process__c>();
        List<FEC_MDM_Category__c> catUpdates = new List<FEC_MDM_Category__c>();
        List<FEC_MDM_Sub_Category__c> scatUpdates = new List<FEC_MDM_Sub_Category__c>();
        List<FEC_MDM_Sub_Code__c> scodeUpdates = new List<FEC_MDM_Sub_Code__c>();
        
        try {
            for (Map<String, Object> data : listData) {
                String type = (String)data.get(FEC_Constants.PAYLOAD_TYPE);
                String recordId = (String)data.get(FEC_Constants.PAYLOAD_IDTYPE);
                if (String.isBlank(recordId)) continue;
                if (type == FEC_Constants.LABEL_PRODUCT_TYPE) {
                    ptUpdates.add(new FEC_MDM_Product_Type__c(
                        Id = recordId,
                        Name = (String)data.get(FEC_Constants.PAYLOAD_NAMEEN),
                        FEC_Name_VN__c = (String)data.get(FEC_Constants.PAYLOAD_NAMEVN),
                        FEC_Alias__c = (String)data.get(FEC_Constants.PAYLOAD_ALIAS),
                        FEC_Code__c = (String)data.get(FEC_Constants.PAYLOAD_CODE),
                        FEC_Pos_Order__c = Decimal.valueOf(String.valueOf(data.get(FEC_Constants.PAYLOAD_POSORDER))),
                        FEC_Status__c = (Boolean)data.get(FEC_Constants.PAYLOAD_STATUS)
                    ));
                } else if (type == FEC_Constants.LABEL_BUSINESS_PROCESS) {
                    bpUpdates.add(new FEC_MDM_Business_Process__c(
                        Id = recordId,
                        Name = (String)data.get(FEC_Constants.PAYLOAD_NAMEEN),
                        FEC_Name_VN__c = (String)data.get(FEC_Constants.PAYLOAD_NAMEVN),
                        FEC_Alias__c = (String)data.get(FEC_Constants.PAYLOAD_ALIAS),
                        FEC_Code__c = (String)data.get(FEC_Constants.PAYLOAD_CODE),
                        FEC_Pos_Order__c = Decimal.valueOf(String.valueOf(data.get(FEC_Constants.PAYLOAD_POSORDER))),
                        FEC_Status__c = (Boolean)data.get(FEC_Constants.PAYLOAD_STATUS)
                    ));
                } else if (type == FEC_Constants.LABEL_CATEGORY) {
                    catUpdates.add(new FEC_MDM_Category__c(
                        Id = recordId,
                        Name = (String)data.get(FEC_Constants.PAYLOAD_NAMEEN),
                        FEC_Name_VN__c = (String)data.get(FEC_Constants.PAYLOAD_NAMEVN),
                        FEC_Alias__c = (String)data.get(FEC_Constants.PAYLOAD_ALIAS),
                        FEC_Code__c = (String)data.get(FEC_Constants.PAYLOAD_CODE),
                        FEC_Pos_Order__c = Decimal.valueOf(String.valueOf(data.get(FEC_Constants.PAYLOAD_POSORDER))),
                        FEC_Status__c = (Boolean)data.get(FEC_Constants.PAYLOAD_STATUS)
                    ));
                } else if (type == FEC_Constants.LABEL_SUB_CATEGORY) {
                    scatUpdates.add(new FEC_MDM_Sub_Category__c(
                        Id = recordId,
                        Name = (String)data.get(FEC_Constants.PAYLOAD_NAMEEN),
                        FEC_Name_VN__c = (String)data.get(FEC_Constants.PAYLOAD_NAMEVN),
                        FEC_Alias__c = (String)data.get(FEC_Constants.PAYLOAD_ALIAS),
                        FEC_Code__c = (String)data.get(FEC_Constants.PAYLOAD_CODE),
                        FEC_Pos_Order__c = Decimal.valueOf(String.valueOf(data.get(FEC_Constants.PAYLOAD_POSORDER))),
                        FEC_Status__c = (Boolean)data.get(FEC_Constants.PAYLOAD_STATUS)
                    ));
                } else if (type == FEC_Constants.LABEL_SUB_CODE) {
                    scodeUpdates.add(new FEC_MDM_Sub_Code__c(
                        Id = recordId,
                        Name = (String)data.get(FEC_Constants.PAYLOAD_NAMEEN),
                        FEC_Name_VN__c = (String)data.get(FEC_Constants.PAYLOAD_NAMEVN),
                        FEC_Alias__c = (String)data.get(FEC_Constants.PAYLOAD_ALIAS),
                        FEC_Code__c = (String)data.get(FEC_Constants.PAYLOAD_CODE),
                        FEC_Pos_Order__c = Decimal.valueOf(String.valueOf(data.get(FEC_Constants.PAYLOAD_POSORDER))),
                        FEC_Status__c = (Boolean)data.get(FEC_Constants.PAYLOAD_STATUS)
                    ));
                }
            }

            if (!ptUpdates.isEmpty()) {
                if (!FEC_MDM_Product_Type__c.sObjectType.getDescribe().isUpdateable()) throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Update not allowed on Product Type');
                update ptUpdates;
            }
            if (!bpUpdates.isEmpty()) {
                if (!FEC_MDM_Business_Process__c.sObjectType.getDescribe().isUpdateable()) throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Update not allowed on Business Process');
                update bpUpdates;
            }
            if (!catUpdates.isEmpty()) {
                if (!FEC_MDM_Category__c.sObjectType.getDescribe().isUpdateable()) throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Update not allowed on Category');
                update catUpdates;
            }
            if (!scatUpdates.isEmpty()) {
                if (!FEC_MDM_Sub_Category__c.sObjectType.getDescribe().isUpdateable()) throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Update not allowed on Sub Category');
                update scatUpdates;
            }
            if (!scodeUpdates.isEmpty()) {
                if (!FEC_MDM_Sub_Code__c.sObjectType.getDescribe().isUpdateable()) throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Update not allowed on Sub Code');
                update scodeUpdates;
            }
        } catch (Exception e) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static void updateNode(Map<String, Object> updateData) {
        String IdNOC = (String)updateData.get(FEC_Constants.PAYLOAD_ID);
        String nodeId = (String)updateData.get(FEC_Constants.PAYLOAD_IDTYPE);
        String nodeType = (String)updateData.get(FEC_Constants.PAYLOAD_TYPE);
        SObject targetSObject = null;

        if (nodeType == FEC_Constants.LABEL_PRODUCT_TYPE) {
            targetSObject = [SELECT Id FROM FEC_MDM_Product_Type__c WHERE Id = :nodeId LIMIT 1];
        } else if (nodeType == FEC_Constants.LABEL_BUSINESS_PROCESS) {
            targetSObject = [SELECT Id FROM FEC_MDM_Business_Process__c WHERE Id = :nodeId LIMIT 1];
        } else if (nodeType == FEC_Constants.LABEL_CATEGORY) {
            targetSObject = [SELECT Id FROM FEC_MDM_Category__c WHERE Id = :nodeId LIMIT 1];
        } else if (nodeType == FEC_Constants.LABEL_SUB_CATEGORY) {
            targetSObject = [SELECT Id FROM FEC_MDM_Sub_Category__c WHERE Id = :nodeId LIMIT 1];
        } else if (nodeType == FEC_Constants.LABEL_SUB_CODE) {
            targetSObject = [SELECT Id FROM FEC_MDM_Sub_Code__c WHERE Id = :nodeId LIMIT 1];
        } else {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Unknown node type: ' + nodeType);
        }

        if (targetSObject == null) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Record not found: ' + nodeId);
        }

        if (!targetSObject.getSObjectType().getDescribe().isUpdateable()) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Update not allowed for this record type');
        }

        Map<String, Schema.SObjectField> fm = targetSObject.getSobjectType().getDescribe().fields.getMap();
        if (fm.containsKey(FEC_Constants.FIELD_ALIAS) && fm.get(FEC_Constants.FIELD_ALIAS).getDescribe().isUpdateable()) targetSObject.put(FEC_Constants.FIELD_ALIAS, (String)updateData.get(FEC_Constants.PAYLOAD_ALIAS));
        if (fm.containsKey(FEC_Constants.FIELD_CODE) && fm.get(FEC_Constants.FIELD_CODE).getDescribe().isUpdateable()) targetSObject.put(FEC_Constants.FIELD_CODE, (String)updateData.get(FEC_Constants.PAYLOAD_CODE));
        if (fm.containsKey(FEC_Constants.FIELD_NAME_VN) && fm.get(FEC_Constants.FIELD_NAME_VN).getDescribe().isUpdateable()) targetSObject.put(FEC_Constants.FIELD_NAME_VN, (String)updateData.get(FEC_Constants.PAYLOAD_NAMEVN));
        if (fm.containsKey(FEC_Constants.FIELD_STATUS) && fm.get(FEC_Constants.FIELD_STATUS).getDescribe().isUpdateable()) targetSObject.put(FEC_Constants.FIELD_STATUS, (Boolean)updateData.get(FEC_Constants.PAYLOAD_STATUS));
        if (fm.containsKey(FEC_Constants.FIELD_NAME) && fm.get(FEC_Constants.FIELD_NAME).getDescribe().isUpdateable()) targetSObject.put(FEC_Constants.FIELD_NAME, (String)updateData.get(FEC_Constants.PAYLOAD_NAMEEN));
        if (fm.containsKey(FEC_Constants.FIELD_POS_ORDER) && fm.get(FEC_Constants.FIELD_POS_ORDER).getDescribe().isUpdateable()) targetSObject.put(FEC_Constants.FIELD_POS_ORDER, (Decimal)updateData.get(FEC_Constants.PAYLOAD_POSORDER));

        try {
            update targetSObject;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
}