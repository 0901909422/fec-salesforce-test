/**
 * @description Live mirror of FEC_NatureOfCaseTreeController.
 *              Provides full CRUD operations on Live (FEC_*) objects for the
 *              Live Master Data Configuration UI.
 *              Live objects do NOT have Process_Change_Status__c.
 *              Both Live and MDM tier objects use FEC_Order__c.
 *              CUD operations are delegated to FEC_LiveNatureOfCaseTreeService.
 * @date   2026
 */
public with sharing class FEC_LiveNatureOfCaseTreeController {

    // ─────────────────────────────────────────────────────────────────────
    //  READ
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @description Get NOC record detail by Id.
     */
    @AuraEnabled
    public static Map<String, String> getNocDetail(Id nocId) {
        if (nocId == null) {
            throw new AuraHandledException('NOC Id cannot be null.');
        }
        try {
            List<FEC_Nature_Of_Case__c> nocs = [
                SELECT Id, Name, FEC_Code__c, FEC_Customer_Type__c,
                       FEC_User_Group__c, FEC_Active__c,
                       FEC_Do_Not_Bother__c, FEC_Transfer_Call_to_Collection__c, FEC_Remove_Phone__c
                FROM FEC_Nature_Of_Case__c
                WHERE Id = :nocId
                LIMIT 1
            ];
            if (nocs.isEmpty()) {
                throw new AuraHandledException('Nature of Case record not found: ' + nocId);
            }
            FEC_Nature_Of_Case__c noc = nocs[0];
            Map<String, String> result = new Map<String, String>();
            result.put('id', noc.Id);
            result.put('name', noc.Name != null ? noc.Name : '');
            result.put('code', noc.FEC_Code__c != null ? noc.FEC_Code__c : '');
            result.put('customerType', noc.FEC_Customer_Type__c != null ? noc.FEC_Customer_Type__c : '');
            result.put('userGroup', noc.FEC_User_Group__c != null ? noc.FEC_User_Group__c : '');
            result.put('active', String.valueOf(noc.FEC_Active__c));
            result.put('doNotBother', String.valueOf(noc.FEC_Do_Not_Bother__c));
            result.put('transferCallToCollection', String.valueOf(noc.FEC_Transfer_Call_to_Collection__c));
            result.put('removePhone', String.valueOf(noc.FEC_Remove_Phone__c));
            // Live objects do NOT have Process_Change_Status__c
            result.put('processStatus', '');
            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Build the 5-level NOC tree from Live data.
     *              Reuses FEC_NatureOfCaseTreeBuilder.buildTree(List<FEC_Nature_Of_Case__c>).
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_NatureOfCaseTreeItem> getNatureOfCaseTreeData() {
        try {
            List<FEC_Nature_Of_Case__c> listNOC = [
                SELECT
                    Id, Name, FEC_Customer_Type__c, FEC_User_Group__c,
                    FEC_Product_Type__c,
                    FEC_Product_Type__r.Name, FEC_Product_Type__r.FEC_Alias__c,
                    FEC_Product_Type__r.FEC_Code__c, FEC_Product_Type__r.FEC_Name_VN__c,
                    FEC_Product_Type__r.FEC_Active__c,
                    FEC_Business_Process__c,
                    FEC_Business_Process__r.Name, FEC_Business_Process__r.FEC_Alias__c,
                    FEC_Business_Process__r.FEC_Code__c, FEC_Business_Process__r.FEC_Name_VN__c,
                    FEC_Business_Process__r.FEC_Active__c,
                    FEC_Category__c,
                    FEC_Category__r.Name, FEC_Category__r.FEC_Alias__c,
                    FEC_Category__r.FEC_Code__c, FEC_Category__r.FEC_Name_VN__c,
                    FEC_Category__r.FEC_Active__c,
                    FEC_Sub_Category__c,
                    FEC_Sub_Category__r.Name, FEC_Sub_Category__r.FEC_Alias__c,
                    FEC_Sub_Category__r.FEC_Code__c, FEC_Sub_Category__r.FEC_Name_VN__c,
                    FEC_Sub_Category__r.FEC_Active__c,
                    FEC_Sub_Code__c,
                    FEC_Sub_Code__r.Name, FEC_Sub_Code__r.FEC_Alias__c,
                    FEC_Sub_Code__r.FEC_Code__c, FEC_Sub_Code__r.FEC_Name_VN__c,
                    FEC_Sub_Code__r.FEC_Active__c
                FROM FEC_Nature_Of_Case__c
                ORDER BY
                    FEC_Product_Type__r.Name ASC,
                    FEC_Business_Process__r.Name ASC,
                    FEC_Category__r.Name ASC,
                    FEC_Sub_Category__r.Name ASC,
                    FEC_Sub_Code__r.Name ASC
            ];
            List<FEC_Nature_Of_Case__c> safe = (List<FEC_Nature_Of_Case__c>)
                Security.stripInaccessible(AccessType.READABLE, listNOC).getRecords();
            return FEC_NatureOfCaseTreeBuilder.buildTree(safe);
        } catch (Exception e) {
            System.debug('FEC_LiveNatureOfCaseTreeController.getNatureOfCaseTreeData error: ' + e);
            return new List<FEC_NatureOfCaseTreeItem>();
        }
    }

    /**
     * @description Get the next position order for a child node under a parent.
     */
    @AuraEnabled
    public static Integer getNextPosOrder(String parentId, String childFieldName) {
        String targetChildField;
        if (childFieldName == FEC_FieldConstants.NOC_FIELD_PRODUCT_TYPE) targetChildField = FEC_FieldConstants.NOC_FIELD_BUSINESS_PROCESS;
        else if (childFieldName == FEC_FieldConstants.NOC_FIELD_BUSINESS_PROCESS) targetChildField = FEC_FieldConstants.NOC_FIELD_CATEGORY;
        else if (childFieldName == FEC_FieldConstants.NOC_FIELD_CATEGORY) targetChildField = FEC_FieldConstants.NOC_FIELD_SUB_CATEGORY;
        else if (childFieldName == FEC_FieldConstants.NOC_FIELD_SUB_CATEGORY) targetChildField = FEC_FieldConstants.NOC_FIELD_SUB_CODE;
        else targetChildField = FEC_FieldConstants.NOC_FIELD_PRODUCT_TYPE;

        String query = 'SELECT COUNT_DISTINCT(' + targetChildField + ') uniqueCount FROM FEC_Nature_Of_Case__c';
        if (String.isNotBlank(parentId) && String.isNotBlank(childFieldName)) {
            query += ' WHERE ' + childFieldName + ' = :parentId AND ' + targetChildField + ' != NULL';
        }
        AggregateResult[] results = Database.query(query);
        Integer uniqueCount = (Integer) results[0].get('uniqueCount');
        return uniqueCount + 1;
    }

    // ─────────────────────────────────────────────────────────────────────
    //  WRITE — delegate to FEC_LiveNatureOfCaseTreeService
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @description Insert a new tier record (Product Type / BP / Category / Sub Cat / Sub Code)
     *              and create the corresponding NOC mapping. Auto-populates FEC_Code__c if blank.
     */
    @AuraEnabled
    public static String saveNewLookupNode(
        String strObjectType, String strCustomerType, String strParentId,
        String strName, String strAlias, String strCode, String strNameVN,
        Integer intPosOrder, Boolean isStatus
    ) {
        return FEC_LiveNatureOfCaseTreeService.saveNewLookupNode(
            strObjectType, strCustomerType, strParentId, strName, strAlias, strCode, strNameVN, intPosOrder, isStatus
        );
    }

    /**
     * @description Cascade-delete a tier node and all its descendant tier records
     *              along with associated NOC mapping records.
     */
    @AuraEnabled
    public static void deleteNodeApex(String typeRecordId, String typeName) {
        FEC_LiveNatureOfCaseTreeService.deleteNodeApex(typeRecordId, typeName);
    }

    /**
     * @description Update a single tier node by Id and type.
     */
    @AuraEnabled
    public static void updateNode(Map<String, Object> updateData) {
        FEC_LiveNatureOfCaseTreeService.updateNode(updateData);
    }

    /**
     * @description Bulk update multiple tier nodes (used for re-ordering).
     */
    @AuraEnabled
    public static void updateMultipleNodes(List<Map<String, Object>> listData) {
        if (listData == null || listData.isEmpty()) return;
        for (Map<String, Object> data : listData) {
            FEC_LiveNatureOfCaseTreeService.updateNode(data);
        }
    }

    /**
     * @description Update editable fields directly on a Nature of Case mapping record.
     *              Mirrors FEC_NatureOfCaseTreeController.updateNocFields() but for Live.
     */
    @AuraEnabled
    public static void updateNocFields(
        Id nocId, String customerType, String userGroup, Boolean isActive,
        Boolean doNotBother, Boolean transferCallToCollection, Boolean removePhone,
        Id nodeId, String nodeType
    ) {
        if (nocId == null) {
            throw new AuraHandledException('NOC Id cannot be null.');
        }
        if (!FEC_Nature_Of_Case__c.SObjectType.getDescribe().isUpdateable()) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' Update not allowed on Nature of Case');
        }
        try {
            FEC_Nature_Of_Case__c noc = new FEC_Nature_Of_Case__c(
                Id = nocId,
                FEC_Customer_Type__c = customerType,
                FEC_User_Group__c = String.isNotBlank(userGroup) ? userGroup : null,
                FEC_Active__c = isActive != null ? isActive : false,
                FEC_Do_Not_Bother__c = doNotBother != null ? doNotBother : false,
                FEC_Transfer_Call_to_Collection__c = transferCallToCollection != null ? transferCallToCollection : false,
                FEC_Remove_Phone__c = removePhone != null ? removePhone : false
            );
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<FEC_Nature_Of_Case__c>{ noc }
            );
            update decision.getRecords();

            // Cascade Customer Type to siblings of same Product Type
            if (String.isNotBlank(customerType)) {
                FEC_Nature_Of_Case__c updatedNoc = [
                    SELECT Id, FEC_Product_Type__c, FEC_Customer_Type__c
                    FROM FEC_Nature_Of_Case__c WHERE Id = :nocId LIMIT 1
                ];
                if (updatedNoc.FEC_Product_Type__c != null) {
                    List<FEC_Nature_Of_Case__c> siblings = [
                        SELECT Id, FEC_Customer_Type__c
                        FROM FEC_Nature_Of_Case__c
                        WHERE FEC_Product_Type__c = :updatedNoc.FEC_Product_Type__c
                          AND Id != :nocId
                          AND FEC_Customer_Type__c != :customerType
                    ];
                    if (!siblings.isEmpty()) {
                        for (FEC_Nature_Of_Case__c s : siblings) {
                            s.FEC_Customer_Type__c = customerType;
                        }
                        SObjectAccessDecision siblingDecision = Security.stripInaccessible(AccessType.UPDATABLE, siblings);
                        update siblingDecision.getRecords();
                    }
                }
            }
            // Live objects do NOT have Process_Change_Status__c → skip touch
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
}