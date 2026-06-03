public with sharing class FEC_NatureOfCaseTreeBuilder {

    /**
     * Overloaded buildTree for Live objects (FEC_Nature_Of_Case__c).
     * Live objects have the same field structure as MDM objects.
     */
    public static List<FEC_NatureOfCaseTreeItem> buildTree(List<FEC_Nature_Of_Case__c> listLiveNOC) {
        List<FEC_NatureOfCaseTreeItem> treeItems = new List<FEC_NatureOfCaseTreeItem>();
        if (listLiveNOC == null || listLiveNOC.isEmpty()) {
            return treeItems;
        }

        Map<String, FEC_NatureOfCaseTreeItem> mapProductType = new Map<String, FEC_NatureOfCaseTreeItem>();

        for (FEC_Nature_Of_Case__c noc : listLiveNOC) {
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

            String ptKey = FEC_UIConstants.PT_PREFIX + ptId;
            String bpsKey = FEC_UIConstants.BP_PREFIX + ptId + '_' + bpId;
            String cataKey = FEC_UIConstants.CAT_PREFIX + ptId + '_' + bpId + '_' + catId;
            String scatKey = FEC_UIConstants.SCAT_PREFIX + ptId + '_' + bpId + '_' + catId + '_' + scatId;
            String scodeKey = FEC_UIConstants.SCODE_PREFIX + ptId + '_' + bpId + '_' + catId + '_' + scatId + '_' + scodeId;

            // 1. Product Type Node
            FEC_NatureOfCaseTreeItem ptNode;
            if (productTypeCode != null) {
                if (!mapProductType.containsKey(productTypeCode)) {
                    ptNode = new FEC_NatureOfCaseTreeItem(
                        productTypeCode, ptKey, new List<FEC_NatureOfCaseTreeItem>(),
                        noc.FEC_Product_Type__r.FEC_Alias__c, noc.FEC_Product_Type__r.FEC_Code__c,
                        noc.FEC_Product_Type__r.FEC_Name_VN__c, null,
                        noc.FEC_Product_Type__r.FEC_Active__c, null,
                        noc.FEC_Product_Type__r.Name, noc.FEC_Product_Type__c,
                        noc.FEC_Customer_Type__c, noc.Id, FEC_UIConstants.LABEL_PRODUCT_TYPE
                    );
                    ptNode.FEC_User_Group = noc.FEC_User_Group__c;
                    mapProductType.put(productTypeCode, ptNode);
                } else {
                    ptNode = mapProductType.get(productTypeCode);
                }
                if (noc.FEC_Product_Type__r.FEC_Active__c == false) { continue; }
            } else { continue; }

            // 2. Business Process Node
            FEC_NatureOfCaseTreeItem bpNode;
            if (businessProcessCode != null) {
                String bpKey = productTypeCode + '_' + businessProcessCode;
                if (ptNode.mapChilds == null) ptNode.mapChilds = new Map<String, FEC_NatureOfCaseTreeItem>();
                if (!ptNode.mapChilds.containsKey(bpKey)) {
                    bpNode = new FEC_NatureOfCaseTreeItem(
                        businessProcessCode, bpsKey, new List<FEC_NatureOfCaseTreeItem>(),
                        noc.FEC_Business_Process__r.FEC_Alias__c, noc.FEC_Business_Process__r.FEC_Code__c,
                        noc.FEC_Business_Process__r.FEC_Name_VN__c, null,
                        noc.FEC_Business_Process__r.FEC_Active__c, null,
                        noc.FEC_Business_Process__r.Name, noc.FEC_Business_Process__c,
                        noc.FEC_Customer_Type__c, noc.Id, FEC_UIConstants.LABEL_BUSINESS_PROCESS
                    );
                    bpNode.FEC_User_Group = noc.FEC_User_Group__c;
                    ptNode.mapChilds.put(bpKey, bpNode);
                } else { bpNode = ptNode.mapChilds.get(bpKey); }
                if (noc.FEC_Business_Process__r.FEC_Active__c == false) { continue; }
            } else { continue; }

            // 3. Category Node
            FEC_NatureOfCaseTreeItem catNode;
            if (categoryCode != null) {
                String catKey = bpNode.code + '_' + categoryCode;
                if (bpNode.mapChilds == null) bpNode.mapChilds = new Map<String, FEC_NatureOfCaseTreeItem>();
                if (!bpNode.mapChilds.containsKey(catKey)) {
                    catNode = new FEC_NatureOfCaseTreeItem(
                        categoryCode, cataKey, new List<FEC_NatureOfCaseTreeItem>(),
                        noc.FEC_Category__r.FEC_Alias__c, noc.FEC_Category__r.FEC_Code__c,
                        noc.FEC_Category__r.FEC_Name_VN__c, null,
                        noc.FEC_Category__r.FEC_Active__c, null,
                        noc.FEC_Category__r.Name, noc.FEC_Category__c,
                        noc.FEC_Customer_Type__c, noc.Id, FEC_UIConstants.LABEL_CATEGORY
                    );
                    catNode.FEC_User_Group = noc.FEC_User_Group__c;
                    bpNode.mapChilds.put(catKey, catNode);
                } else { catNode = bpNode.mapChilds.get(catKey); }
                if (noc.FEC_Category__r.FEC_Active__c == false) { continue; }
            } else { continue; }

            // 4. Sub Category Node
            FEC_NatureOfCaseTreeItem subCatNode;
            if (subCategoryCode != null) {
                String subCatKey = catNode.code + '_' + subCategoryCode;
                if (catNode.mapChilds == null) catNode.mapChilds = new Map<String, FEC_NatureOfCaseTreeItem>();
                if (!catNode.mapChilds.containsKey(subCatKey)) {
                    subCatNode = new FEC_NatureOfCaseTreeItem(
                        subCategoryCode, scatKey, new List<FEC_NatureOfCaseTreeItem>(),
                        noc.FEC_Sub_Category__r.FEC_Alias__c, noc.FEC_Sub_Category__r.FEC_Code__c,
                        noc.FEC_Sub_Category__r.FEC_Name_VN__c, null,
                        noc.FEC_Sub_Category__r.FEC_Active__c, null,
                        noc.FEC_Sub_Category__r.Name, noc.FEC_Sub_Category__c,
                        noc.FEC_Customer_Type__c, noc.Id, FEC_UIConstants.LABEL_SUB_CATEGORY
                    );
                    subCatNode.FEC_User_Group = noc.FEC_User_Group__c;
                    catNode.mapChilds.put(subCatKey, subCatNode);
                } else { subCatNode = catNode.mapChilds.get(subCatKey); }
                if (noc.FEC_Sub_Category__r.FEC_Active__c == false) { continue; }
            } else { continue; }

            // 5. Sub Code Node (Leaf)
            if (subCodeCode != null) {
                String scKey = subCatNode.code + '_' + subCodeCode;
                if (subCatNode.mapChilds == null) subCatNode.mapChilds = new Map<String, FEC_NatureOfCaseTreeItem>();
                if (!subCatNode.mapChilds.containsKey(scKey)) {
                    FEC_NatureOfCaseTreeItem scNode = new FEC_NatureOfCaseTreeItem(
                        subCodeCode, scodeKey, null,
                        noc.FEC_Sub_Code__r.FEC_Alias__c, noc.FEC_Sub_Code__r.FEC_Code__c,
                        noc.FEC_Sub_Code__r.FEC_Name_VN__c, null,
                        noc.FEC_Sub_Code__r.FEC_Active__c, null,
                        noc.FEC_Sub_Code__r.Name, noc.FEC_Sub_Code__c,
                        noc.FEC_Customer_Type__c, noc.Id, FEC_UIConstants.LABEL_SUB_CODE
                    );
                    scNode.FEC_User_Group = noc.FEC_User_Group__c;
                    subCatNode.mapChilds.put(scKey, scNode);
                }
            }
        }

        for (FEC_NatureOfCaseTreeItem ptItem : mapProductType.values()) {
            ptItem.convertMapToList();
            treeItems.add(ptItem);
        }
        return treeItems;
    }

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

        // ── Pre-process: Build map of correct NOC ID per level ──
        // Key = composite key (same as tree node key), Value = NOC record Id
        // A NOC record belongs to level X if its lookup at level X is filled but level X+1 is null.
        Map<String, Id> nocIdByNodeKey = new Map<String, Id>();
        for (FEC_MDM_Nature_Of_Case__c noc : listNOC) {
            String ptId = noc.FEC_Product_Type__c;
            String bpId = noc.FEC_Business_Process__c;
            String catId = noc.FEC_Category__c;
            String scatId = noc.FEC_Sub_Category__c;
            String scodeId = noc.FEC_Sub_Code__c;
            if (ptId == null) continue;

            // Determine which level this NOC belongs to based on null pattern
            if (bpId == null) {
                // Product Type level NOC
                nocIdByNodeKey.put(FEC_UIConstants.PT_PREFIX + ptId, noc.Id);
            } else if (catId == null) {
                // Business Process level NOC
                nocIdByNodeKey.put(FEC_UIConstants.BP_PREFIX + ptId + '_' + bpId, noc.Id);
            } else if (scatId == null) {
                // Category level NOC
                nocIdByNodeKey.put(FEC_UIConstants.CAT_PREFIX + ptId + '_' + bpId + '_' + catId, noc.Id);
            } else if (scodeId == null) {
                // Sub Category level NOC
                nocIdByNodeKey.put(FEC_UIConstants.SCAT_PREFIX + ptId + '_' + bpId + '_' + catId + '_' + scatId, noc.Id);
            } else {
                // Sub Code level NOC (leaf)
                nocIdByNodeKey.put(FEC_UIConstants.SCODE_PREFIX + ptId + '_' + bpId + '_' + catId + '_' + scatId + '_' + scodeId, noc.Id);
            }
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

            String ptKey = FEC_UIConstants.PT_PREFIX + ptId;
            String bpsKey = FEC_UIConstants.BP_PREFIX + ptId + '_' + bpId;
            String cataKey = FEC_UIConstants.CAT_PREFIX + ptId + '_' + bpId + '_' + catId;
            String scatKey = FEC_UIConstants.SCAT_PREFIX + ptId + '_' + bpId + '_' + catId + '_' + scatId;
            String scodeKey = FEC_UIConstants.SCODE_PREFIX + ptId + '_' + bpId + '_' + catId + '_' + scatId + '_' + scodeId;

            // 1. Product Type Node (Root)
            FEC_NatureOfCaseTreeItem ptNode;
            if (productTypeCode != null) {
                if (!mapProductType.containsKey(productTypeCode)) {
                    Id ptNocId = nocIdByNodeKey.containsKey(ptKey) ? nocIdByNodeKey.get(ptKey) : noc.Id;
                    ptNode = new FEC_NatureOfCaseTreeItem(
                        productTypeCode,
                        ptKey,
                        new List<FEC_NatureOfCaseTreeItem>(),
                        noc.FEC_Product_Type__r.FEC_Alias__c,
                        noc.FEC_Product_Type__r.FEC_Code__c,
                        noc.FEC_Product_Type__r.FEC_Name_VN__c,
                        noc.FEC_Product_Type__r.FEC_Order__c,
                        noc.FEC_Product_Type__r.FEC_Active__c,
                        noc.FEC_Product_Type__r.Process_Change_Status__c,
                        noc.FEC_Product_Type__r.Name,
                        noc.FEC_Product_Type__c,
                        noc.FEC_Customer_Type__c,
                        ptNocId,
                        FEC_UIConstants.LABEL_PRODUCT_TYPE
                    );
                    ptNode.FEC_User_Group = noc.FEC_User_Group__c;
                    mapProductType.put(productTypeCode, ptNode);
                } else {
                    ptNode = mapProductType.get(productTypeCode);
                }
                if (noc.FEC_Product_Type__r.FEC_Active__c == false) {
                    skippedCount++;
                    continue;
                }
            } else {
                skippedCount++;
                continue;
            }

            // 2. Business Process Node
            FEC_NatureOfCaseTreeItem bpNode;
            if (businessProcessCode != null) {
                String bpKey = productTypeCode + '_' + businessProcessCode;
                if (ptNode.mapChilds == null) ptNode.mapChilds = new Map<String, FEC_NatureOfCaseTreeItem>();

                if (!ptNode.mapChilds.containsKey(bpKey)) {
                    Id bpNocId = nocIdByNodeKey.containsKey(bpsKey) ? nocIdByNodeKey.get(bpsKey) : noc.Id;
                    bpNode = new FEC_NatureOfCaseTreeItem(
                        businessProcessCode,
                        bpsKey,
                        new List<FEC_NatureOfCaseTreeItem>(),
                        noc.FEC_Business_Process__r.FEC_Alias__c,
                        noc.FEC_Business_Process__r.FEC_Code__c,
                        noc.FEC_Business_Process__r.FEC_Name_VN__c,
                        noc.FEC_Business_Process__r.FEC_Order__c,
                        noc.FEC_Business_Process__r.FEC_Active__c,
                        noc.FEC_Business_Process__r.Process_Change_Status__c,
                        noc.FEC_Business_Process__r.Name,
                        noc.FEC_Business_Process__c,
                        noc.FEC_Customer_Type__c,
                        bpNocId,
                        FEC_UIConstants.LABEL_BUSINESS_PROCESS
                    );
                    bpNode.FEC_User_Group = noc.FEC_User_Group__c;
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
                    Id catNocId = nocIdByNodeKey.containsKey(cataKey) ? nocIdByNodeKey.get(cataKey) : noc.Id;
                    catNode = new FEC_NatureOfCaseTreeItem(
                        categoryCode,
                        cataKey,
                        new List<FEC_NatureOfCaseTreeItem>(),
                        noc.FEC_Category__r.FEC_Alias__c,
                        noc.FEC_Category__r.FEC_Code__c,
                        noc.FEC_Category__r.FEC_Name_VN__c,
                        noc.FEC_Category__r.FEC_Order__c,
                        noc.FEC_Category__r.FEC_Active__c,
                        noc.FEC_Category__r.Process_Change_Status__c,
                        noc.FEC_Category__r.Name,
                        noc.FEC_Category__c,
                        noc.FEC_Customer_Type__c,
                        catNocId,
                        FEC_UIConstants.LABEL_CATEGORY
                    );
                    catNode.FEC_User_Group = noc.FEC_User_Group__c;
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
                    Id scatNocId = nocIdByNodeKey.containsKey(scatKey) ? nocIdByNodeKey.get(scatKey) : noc.Id;
                    subCatNode = new FEC_NatureOfCaseTreeItem(
                        subCategoryCode,
                        scatKey,
                        new List<FEC_NatureOfCaseTreeItem>(),
                        noc.FEC_Sub_Category__r.FEC_Alias__c,
                        noc.FEC_Sub_Category__r.FEC_Code__c,
                        noc.FEC_Sub_Category__r.FEC_Name_VN__c,
                        noc.FEC_Sub_Category__r.FEC_Order__c,
                        noc.FEC_Sub_Category__r.FEC_Active__c,
                        noc.FEC_Sub_Category__r.Process_Change_Status__c,
                        noc.FEC_Sub_Category__r.Name,
                        noc.FEC_Sub_Category__c,
                        noc.FEC_Customer_Type__c,
                        scatNocId,
                        FEC_UIConstants.LABEL_SUB_CATEGORY
                    );
                    subCatNode.FEC_User_Group = noc.FEC_User_Group__c;
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
                    Id scNocId = nocIdByNodeKey.containsKey(scodeKey) ? nocIdByNodeKey.get(scodeKey) : noc.Id;
                    FEC_NatureOfCaseTreeItem scNode = new FEC_NatureOfCaseTreeItem(
                        subCodeCode,
                        scodeKey,
                        null,
                        noc.FEC_Sub_Code__r.FEC_Alias__c,
                        noc.FEC_Sub_Code__r.FEC_Code__c,
                        noc.FEC_Sub_Code__r.FEC_Name_VN__c,
                        noc.FEC_Sub_Code__r.FEC_Order__c,
                        noc.FEC_Sub_Code__r.FEC_Active__c,
                        noc.FEC_Sub_Code__r.Process_Change_Status__c,
                        noc.FEC_Sub_Code__r.Name,
                        noc.FEC_Sub_Code__c,
                        noc.FEC_Customer_Type__c,
                        scNocId,
                        FEC_UIConstants.LABEL_SUB_CODE
                    );
                    scNode.FEC_User_Group = noc.FEC_User_Group__c;
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