/**
 * @description Controller for fetching and structuring data for the Nature of Case Lightning Tree.
 * @date 2025-12-09
 * @author DAT NGO
 */
public with sharing class FEC_NatureOfCaseTreeController {
    
    // payload keys and aggregate alias moved to FEC_Constants
    
    @AuraEnabled
    public static Integer getNextPosOrder(String parentId, String childFieldName) {
            String targetChildField;
            if (childFieldName == FEC_Constants.NOC_FIELD_PRODUCT_TYPE) targetChildField = FEC_Constants.NOC_FIELD_BUSINESS_PROCESS;
            else if (childFieldName == FEC_Constants.NOC_FIELD_BUSINESS_PROCESS) targetChildField = FEC_Constants.NOC_FIELD_CATEGORY;
            else if (childFieldName == FEC_Constants.NOC_FIELD_CATEGORY) targetChildField = FEC_Constants.NOC_FIELD_SUB_CATEGORY;
            else if (childFieldName == FEC_Constants.NOC_FIELD_SUB_CATEGORY) targetChildField = FEC_Constants.NOC_FIELD_SUB_CODE;
            else targetChildField = FEC_Constants.NOC_FIELD_PRODUCT_TYPE;
            
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
