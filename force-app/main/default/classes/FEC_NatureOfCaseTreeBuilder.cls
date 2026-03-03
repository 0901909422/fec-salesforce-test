public with sharing class FEC_NatureOfCaseTreeBuilder {
    /**
     * Build tree structure from stripped NOC mapping records.
     * Returns a list of FEC_NatureOfCaseTreeItem
     */
    public static List<FEC_NatureOfCaseTreeItem> buildTree(List<FEC_MDM_Nature_Of_Case__c> listNOC) {
        List<FEC_NatureOfCaseTreeItem> treeItems = new List<FEC_NatureOfCaseTreeItem>();
        if (listNOC == null || listNOC.isEmpty()) {
            System.debug('===== BUILDER DEBUG: No NOC records to build tree from');
            return treeItems;
        }

        Map<String, FEC_NatureOfCaseTreeItem> mapProductType = new Map<String, FEC_NatureOfCaseTreeItem>();
        Integer skippedCount = 0;

        for (FEC_MDM_Nature_Of_Case__c noc : listNOC) {
            String productTypeCode = noc.FEC_Product_Type__r?.FEC_Code__c;
            String businessProcessCode = noc.FEC_Business_Process__r?.FEC_Code__c;
            String categoryCode = noc.FEC_Category__r?.FEC_Code__c;
            String subCategoryCode = noc.FEC_Sub_Category__r?.FEC_Code__c;
            String subCodeCode = noc.FEC_Sub_Code__r?.FEC_Code__c;

            String ptId = noc.FEC_Product_Type__c;
            String bpId = noc.FEC_Business_Process__c;
            String catId = noc.FEC_Category__c;
            String scatId = noc.FEC_Sub_Category__c;
            String scodeId = noc.FEC_Sub_Code__c;

            String ptKey = FEC_Constants.PT_PREFIX + ptId;
            String bpsKey = FEC_Constants.BP_PREFIX + ptId + '_' + bpId;
            String cataKey = FEC_Constants.CAT_PREFIX + ptId + '_' + bpId + '_' + catId;
            String scatKey = FEC_Constants.SCAT_PREFIX + ptId + '_' + bpId + '_' + catId + '_' + scatId;
            String scodeKey = FEC_Constants.SCODE_PREFIX + ptId + '_' + bpId + '_' + catId + '_' + scatId + '_' + scodeId;

            // 1. Product Type Node (Root)
            FEC_NatureOfCaseTreeItem ptNode;
            if (productTypeCode != null) {
                if (!mapProductType.containsKey(productTypeCode)) {
                    ptNode = new FEC_NatureOfCaseTreeItem(
                        productTypeCode,
                        ptKey,
                        new List<FEC_NatureOfCaseTreeItem>(),
                        noc.FEC_Product_Type__r.FEC_Alias__c,
                        noc.FEC_Product_Type__r.FEC_Code__c,
                        noc.FEC_Product_Type__r.FEC_Name_VN__c,
                        noc.FEC_Product_Type__r.FEC_Pos_Order__c,
                        noc.FEC_Product_Type__r.FEC_Active__c,
                        noc.FEC_Product_Type__r.Process_Change_Status__c,
                        noc.FEC_Product_Type__r.Name,
                        noc.FEC_Product_Type__c,
                        noc.FEC_Customer_Type__c,
                        noc.Id,
                        FEC_Constants.LABEL_PRODUCT_TYPE
                    );
                    mapProductType.put(productTypeCode, ptNode);
                } else {
                    ptNode = mapProductType.get(productTypeCode);
                }
                if (noc.FEC_Product_Type__r.FEC_Active__c == false) {
                    System.debug('===== BUILDER DEBUG: Skipping inactive Product Type: ' + productTypeCode);
                    skippedCount++;
                    continue;
                }
            } else {
                System.debug('===== BUILDER DEBUG: Skipping NOC with null Product Type. NOC Id: ' + noc.Id);
                skippedCount++;
                continue;
            }

            // 2. Business Process Node
            FEC_NatureOfCaseTreeItem bpNode;
            if (businessProcessCode != null) {
                String bpKey = productTypeCode + '_' + businessProcessCode;
                if (ptNode.mapChilds == null) ptNode.mapChilds = new Map<String, FEC_NatureOfCaseTreeItem>();

                if (!ptNode.mapChilds.containsKey(bpKey)) {
                    bpNode = new FEC_NatureOfCaseTreeItem(
                        businessProcessCode,
                        bpsKey,
                        new List<FEC_NatureOfCaseTreeItem>(),
                        noc.FEC_Business_Process__r.FEC_Alias__c,
                        noc.FEC_Business_Process__r.FEC_Code__c,
                        noc.FEC_Business_Process__r.FEC_Name_VN__c,
                        noc.FEC_Business_Process__r.FEC_Pos_Order__c,
                        noc.FEC_Business_Process__r.FEC_Active__c,
                        noc.FEC_Business_Process__r.Process_Change_Status__c,
                        noc.FEC_Business_Process__r.Name,
                        noc.FEC_Business_Process__c,
                        noc.FEC_Customer_Type__c,
                        noc.Id,
                        FEC_Constants.LABEL_BUSINESS_PROCESS
                    );
                    ptNode.mapChilds.put(bpKey, bpNode);
                } else {
                    bpNode = ptNode.mapChilds.get(bpKey);
                }
                if (noc.FEC_Business_Process__r.FEC_Active__c == false) {
                    continue;
                }
            } else {
                continue;
            }

            // 3. Category Node
            FEC_NatureOfCaseTreeItem catNode;
            if (categoryCode != null) {
                String catKey = bpNode.code + '_' + categoryCode;
                if (bpNode.mapChilds == null) bpNode.mapChilds = new Map<String, FEC_NatureOfCaseTreeItem>();

                if (!bpNode.mapChilds.containsKey(catKey)) {
                    catNode = new FEC_NatureOfCaseTreeItem(
                        categoryCode,
                        cataKey,
                        new List<FEC_NatureOfCaseTreeItem>(),
                        noc.FEC_Category__r.FEC_Alias__c,
                        noc.FEC_Category__r.FEC_Code__c,
                        noc.FEC_Category__r.FEC_Name_VN__c,
                        noc.FEC_Category__r.FEC_Pos_Order__c,
                        noc.FEC_Category__r.FEC_Active__c,
                        noc.FEC_Category__r.Process_Change_Status__c,
                        noc.FEC_Category__r.Name,
                        noc.FEC_Category__c,
                        noc.FEC_Customer_Type__c,
                        noc.Id,
                        FEC_Constants.LABEL_CATEGORY
                    );
                    bpNode.mapChilds.put(catKey, catNode);
                } else {
                    catNode = bpNode.mapChilds.get(catKey);
                }
                if (noc.FEC_Category__r.FEC_Active__c == false) {
                    continue;
                }
            } else {
                continue;
            }

            // 4. Sub Category Node
            FEC_NatureOfCaseTreeItem subCatNode;
            if (subCategoryCode != null) {
                String subCatKey = catNode.code + '_' + subCategoryCode;
                if (catNode.mapChilds == null) catNode.mapChilds = new Map<String, FEC_NatureOfCaseTreeItem>();

                if (!catNode.mapChilds.containsKey(subCatKey)) {
                    subCatNode = new FEC_NatureOfCaseTreeItem(
                        subCategoryCode,
                        scatKey,
                        new List<FEC_NatureOfCaseTreeItem>(),
                        noc.FEC_Sub_Category__r.FEC_Alias__c,
                        noc.FEC_Sub_Category__r.FEC_Code__c,
                        noc.FEC_Sub_Category__r.FEC_Name_VN__c,
                        noc.FEC_Sub_Category__r.FEC_Pos_Order__c,
                        noc.FEC_Sub_Category__r.FEC_Active__c,
                        noc.FEC_Sub_Category__r.Process_Change_Status__c,
                        noc.FEC_Sub_Category__r.Name,
                        noc.FEC_Sub_Category__c,
                        noc.FEC_Customer_Type__c,
                        noc.Id,
                        FEC_Constants.LABEL_SUB_CATEGORY
                    );
                    catNode.mapChilds.put(subCatKey, subCatNode);
                } else {
                    subCatNode = catNode.mapChilds.get(subCatKey);
                }
                if (noc.FEC_Sub_Category__r.FEC_Active__c == false) {
                    continue;
                }
            } else {
                continue;
            }

            // 5. Sub Code Node (Leaf Node)
            if (subCodeCode != null) {
                String scKey = subCatNode.code + '_' + subCodeCode;
                if (subCatNode.mapChilds == null) subCatNode.mapChilds = new Map<String, FEC_NatureOfCaseTreeItem>();

                if (!subCatNode.mapChilds.containsKey(scKey)) {
                    FEC_NatureOfCaseTreeItem scNode = new FEC_NatureOfCaseTreeItem(
                        subCodeCode,
                        scodeKey, // Dùng ID Sub Code
                        null,
                        noc.FEC_Sub_Code__r.FEC_Alias__c,
                        noc.FEC_Sub_Code__r.FEC_Code__c,
                        noc.FEC_Sub_Code__r.FEC_Name_VN__c,
                        noc.FEC_Sub_Code__r.FEC_Pos_Order__c,
                        noc.FEC_Sub_Code__r.FEC_Active__c,
                        noc.FEC_Sub_Code__r.Process_Change_Status__c,
                        noc.FEC_Sub_Code__r.Name,
                        noc.FEC_Sub_Code__c,
                        noc.FEC_Customer_Type__c,
                        noc.Id,
                        FEC_Constants.LABEL_SUB_CODE
                    );
                    subCatNode.mapChilds.put(scKey, scNode);
                }
                if (noc.FEC_Sub_Code__r.FEC_Active__c == false) {
                    continue;
                }
            }
        }

        // Convert map to list
        for (FEC_NatureOfCaseTreeItem ptItem : mapProductType.values()) {
            ptItem.convertMapToList();
            treeItems.add(ptItem);
        }
        
        System.debug('===== BUILDER DEBUG: Total records processed: ' + listNOC.size());
        System.debug('===== BUILDER DEBUG: Total records skipped: ' + skippedCount);
        System.debug('===== BUILDER DEBUG: Total tree nodes created: ' + treeItems.size());
        
        return treeItems;
    }
}
