/**
 * @description Controller for fetching and structuring data for the Nature of Case Lightning Tree.
 * @date 2025-12-09
 * @author DAT NGO
 */
public with sharing class FEC_NatureOfCaseTreeController {
    
    // payload keys and aggregate alias moved to FEC_Constants

    /**
     * @description Lấy thông tin Nature of Case record theo Id.
     * @param nocId Id của FEC_MDM_Nature_Of_Case__c
     * @return Map<String, String> chứa các fields editable của NOC
     */
    @AuraEnabled
    public static Map<String, String> getNocDetail(Id nocId) {
        if (nocId == null) {
            throw new AuraHandledException('NOC Id cannot be null.');
        }
        try {
            List<FEC_MDM_Nature_Of_Case__c> nocs = [
                SELECT Id, Name, FEC_Code__c, FEC_Customer_Type__c,
                       FEC_User_Group__c, FEC_Active__c,
                       FEC_Do_Not_Bother__c, FEC_Transfer_Call_To_Collection__c, FEC_Remove_Phone__c,
                       Process_Change_Status__c
                FROM FEC_MDM_Nature_Of_Case__c
                WHERE Id = :nocId
                LIMIT 1
            ];
            if (nocs.isEmpty()) {
                throw new AuraHandledException('Nature of Case record not found: ' + nocId);
            }
            FEC_MDM_Nature_Of_Case__c noc = nocs[0];
            Map<String, Object> populated = noc.getPopulatedFieldsAsMap();
            Map<String, String> result = new Map<String, String>();
            result.put('id', noc.Id);
            result.put('name', noc.Name != null ? noc.Name : '');
            result.put('code', noc.FEC_Code__c != null ? noc.FEC_Code__c : '');
            result.put('customerType', noc.FEC_Customer_Type__c != null ? noc.FEC_Customer_Type__c : '');
            result.put('userGroup', noc.FEC_User_Group__c != null ? noc.FEC_User_Group__c : '');
            result.put('active', String.valueOf(noc.FEC_Active__c));
            result.put('doNotBother', String.valueOf(noc.FEC_Do_Not_Bother__c));
            result.put('transferCallToCollection', String.valueOf(noc.FEC_Transfer_Call_To_Collection__c));
            result.put('removePhone', String.valueOf(noc.FEC_Remove_Phone__c));
            result.put('processStatus', populated.containsKey('Process_Change_Status__c') 
                ? (noc.Process_Change_Status__c != null ? noc.Process_Change_Status__c : '') : '');
            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Cập nhật các fields editable của Nature of Case record.
     * @param nocId Id của FEC_MDM_Nature_Of_Case__c
     * @param customerType Giá trị Customer Type mới
     * @param userGroup Giá trị User Group mới
     * @param roleNames Giá trị Role Names mới
     * @param isActive Giá trị Active mới
     */
    @AuraEnabled
    public static void updateNocFields(Id nocId, String customerType, String userGroup, Boolean isActive,
            Boolean doNotBother, Boolean transferCallToCollection, Boolean removePhone,
            Id nodeId, String nodeType) {
        if (nocId == null) {
            throw new AuraHandledException('NOC Id cannot be null.');
        }
        if (!FEC_MDM_Nature_Of_Case__c.SObjectType.getDescribe().isUpdateable()) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' Update not allowed on Nature of Case');
        }
        try {
            FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(
                Id = nocId,
                FEC_Customer_Type__c = customerType,
                FEC_User_Group__c = String.isNotBlank(userGroup) ? userGroup : null,
                FEC_Active__c = isActive != null ? isActive : false,
                FEC_Do_Not_Bother__c = doNotBother != null ? doNotBother : false,
                FEC_Transfer_Call_To_Collection__c = transferCallToCollection != null ? transferCallToCollection : false,
                FEC_Remove_Phone__c = removePhone != null ? removePhone : false
            );
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<FEC_MDM_Nature_Of_Case__c>{ noc }
            );
            update decision.getRecords();

            // Cascade: Khi sửa Customer Type ở Product Type node,
            // cập nhật tất cả NOC con cùng Product Type
            if (String.isNotBlank(customerType)) {
                FEC_MDM_Nature_Of_Case__c updatedNoc = [
                    SELECT Id, FEC_Product_Type__c, FEC_Customer_Type__c
                    FROM FEC_MDM_Nature_Of_Case__c WHERE Id = :nocId LIMIT 1
                ];
                if (updatedNoc.FEC_Product_Type__c != null) {
                    List<FEC_MDM_Nature_Of_Case__c> siblings = [
                        SELECT Id, FEC_Customer_Type__c
                        FROM FEC_MDM_Nature_Of_Case__c
                        WHERE FEC_Product_Type__c = :updatedNoc.FEC_Product_Type__c
                          AND Id != :nocId
                          AND FEC_Customer_Type__c != :customerType
                    ];
                    if (!siblings.isEmpty()) {
                        for (FEC_MDM_Nature_Of_Case__c s : siblings) {
                            s.FEC_Customer_Type__c = customerType;
                        }
                        SObjectAccessDecision siblingDecision = Security.stripInaccessible(
                            AccessType.UPDATABLE, siblings
                        );
                        update siblingDecision.getRecords();
                    }
                }
            }

            // Touch the node record to trigger Process_Change_Status__c update
            // so the tree node turns yellow after NOC-level changes
            if (nodeId != null && String.isNotBlank(nodeType)) {
                FEC_NatureOfCaseTreeService.touchNodeForStatusUpdate(nodeId, nodeType);
            }
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (DmlException dml) {
            String msg = dml.getDmlMessage(0);
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Integer getNextPosOrder(String parentId, String childFieldName) {
            String targetChildField;
            if (childFieldName == FEC_FieldConstants.NOC_FIELD_PRODUCT_TYPE) targetChildField = FEC_FieldConstants.NOC_FIELD_BUSINESS_PROCESS;
            else if (childFieldName == FEC_FieldConstants.NOC_FIELD_BUSINESS_PROCESS) targetChildField = FEC_FieldConstants.NOC_FIELD_CATEGORY;
            else if (childFieldName == FEC_FieldConstants.NOC_FIELD_CATEGORY) targetChildField = FEC_FieldConstants.NOC_FIELD_SUB_CATEGORY;
            else if (childFieldName == FEC_FieldConstants.NOC_FIELD_SUB_CATEGORY) targetChildField = FEC_FieldConstants.NOC_FIELD_SUB_CODE;
            else targetChildField = FEC_FieldConstants.NOC_FIELD_PRODUCT_TYPE;
            
            String query = FEC_Constants.SQL_SELECT_COUNT_DISTINCT + targetChildField + FEC_Constants.SQL_FROM_NOC;
            
            if (String.isNotBlank(parentId) && String.isNotBlank(childFieldName)) {
                query += ' WHERE ' + childFieldName + ' = :parentId AND ' + targetChildField + ' != NULL';
            }
            
            AggregateResult[] results = Database.query(query);
            Integer uniqueCount = (Integer)results[0].get(FEC_Constants.AGG_EXPR0);
            
            return uniqueCount + 1;
    }
    
    /**
     * @description Retrieves all Nature of Case records and structures them into a list
     * of Lightning Tree Items based on the hierarchy: Product Type > Business Process > Category > Sub Category > Sub Code.
     * @param
     * @return List<NatureOfCaseTreeItem> The list of tree items.
     * @author DAT NGO
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_NatureOfCaseTreeItem> getNatureOfCaseTreeData() {
        List<FEC_NatureOfCaseTreeItem> treeItems = new List<FEC_NatureOfCaseTreeItem>();
        try {
            // Reuse shared service to fetch mappings (SOQL + FLS enforcement)
            List<FEC_MDM_Nature_Of_Case__c> listNOC = FEC_NatureOfCaseTreeService.fetchAllMasterDataMappings();
            System.debug('===== TREE DEBUG: Total NOC records fetched: ' + listNOC.size());
            
            // Log first few records for debugging
            if (!listNOC.isEmpty()) {
                System.debug('===== TREE DEBUG: Sample record: ' + JSON.serializePretty(listNOC[0]));
            }

            // Build tree with helper to improve readability and testability
            // Delegate tree construction to external builder
            treeItems = FEC_NatureOfCaseTreeBuilder.buildTree(listNOC);
            System.debug('===== TREE DEBUG: Total tree items built: ' + treeItems.size());
            
            if (!treeItems.isEmpty()) {
                System.debug('===== TREE DEBUG: First tree item: ' + JSON.serializePretty(treeItems[0]));
            }
         } catch (Exception e) {
             System.debug('FEC_NatureOfCaseTreeController.getNatureOfCaseTreeData error: ' + e);
             System.debug('===== TREE DEBUG: Error stack trace: ' + e.getStackTraceString());
             // Return empty list on failure to avoid throwing raw exceptions to UI
             return new List<FEC_NatureOfCaseTreeItem>();
         }

         return treeItems;
     }

    /**
     * @description Inserts a new record into a specified Lookup Object (Tất cả đều có FEC_ prefix).
     * @param strObjectType API Name của đối tượng mục tiêu (e.g., 'FEC_MDM_Product_Type__c').
     * @param strParentId ID của node cha.
     * @param strAlias Alias cho bản ghi mới.
     * @param strCode Code cho bản ghi mới.
     * @param strNameVN Tên Tiếng Việt cho bản ghi mới.
     * @param intPosOrder Position Order cho bản ghi mới.
     * @param isStatus Status của bản ghi mới.
     * @return String The ID của bản ghi Lookup mới được tạo.
     * @author DAT NGO
     */
    @AuraEnabled
    public static String saveNewLookupNode(String strObjectType, String strCustomerType, String strParentId,String strName, String strAlias, String strCode, String strNameVN, Integer intPosOrder, Boolean isStatus) {
        // Delegate to service
        return FEC_NatureOfCaseTreeService.saveNewLookupNode(strObjectType, strCustomerType, strParentId, strName, strAlias, strCode, strNameVN, intPosOrder, isStatus);
    }

    @AuraEnabled
    public static void deleteNodeApex(String typeRecordId, String typeName) {
        // Delegate to service
        FEC_NatureOfCaseTreeService.deleteNodeApex(typeRecordId, typeName);
    }

    @AuraEnabled
    public static void updateMultipleNodes(List<Map<String, Object>> listData) {
        // Delegate to service
        FEC_NatureOfCaseTreeService.updateMultipleNodes(listData);
    }

    @AuraEnabled
    public static void updateNode(Map<String, Object> updateData) {
        // Delegate to service
        FEC_NatureOfCaseTreeService.updateNode(updateData);
    }
}