/****************************************************************************************
 * File Name    : FEC_HoldCaseInheritanceService.Apex
 * Author       : Quangdv7
 * Date         : 2026-05-10
 * Description  : Call data object FEC_Hold_Case_Config__c
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0     2026-05-10     Quangdv7             Create
 
****************************************************************************************/

public with sharing class FEC_HoldCaseInheritanceService {

    /* =====================================================
     * MAIN
     * ===================================================== */
    public static void process(Id holdCaseConfigId) {

        if (holdCaseConfigId == null) return;

        FEC_Hold_Case_Config__c sourceConfig = [
            SELECT
                Id,
                Name,
                Hold_Case_Type__c,
                FEC_Channel__c,
                FEC_Current_Status__c,
                FEC_Changed_Status__c,
                FEC_Case_Stage__c,
                FEC_NFU_Code__c,
                FEC_Active__c,
                FEC_Nature_of_Cases__c,
                FEC_Auto_Hold_Duration_Minutes__c,
                FEC_Auto_Hold_Release_Case_Status__c
            FROM FEC_Hold_Case_Config__c
            WHERE Id = :holdCaseConfigId
            LIMIT 1
        ];

        if (sourceConfig.FEC_Nature_of_Cases__c == null) return;

        FEC_Nature_of_Case__c rootNode = [
            SELECT
                Id,
                Name,
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_Sub_Category__c,
                FEC_Sub_Code__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :sourceConfig.FEC_Nature_of_Cases__c
            LIMIT 1
        ];

        Boolean sourceIsSubCode = rootNode.FEC_Sub_Code__c != null;

        processNode(rootNode, sourceConfig, sourceIsSubCode);
    }

    /* =====================================================
     * RECURSIVE
     * ===================================================== */
    private static void processNode(
        FEC_Nature_of_Case__c currentNode,
        FEC_Hold_Case_Config__c sourceConfig,
        Boolean sourceIsSubCode
    ) {
        List<FEC_Nature_of_Case__c> children = getDirectChildren(currentNode);

        if (children.isEmpty()) return;

        Set<Id> childIds = new Set<Id>();
        for (FEC_Nature_of_Case__c child : children) {
            childIds.add(child.Id);
        }

        /* =========================================
         * EXISTING CONFIG
         * ========================================= */
        Map<Id, FEC_Hold_Case_Config__c> existingConfigs =
            new Map<Id, FEC_Hold_Case_Config__c>();

        for (FEC_Hold_Case_Config__c item : [
            SELECT Id, FEC_Nature_of_Cases__c
            FROM FEC_Hold_Case_Config__c
            WHERE FEC_Nature_of_Cases__c IN :childIds
        ]) {
            existingConfigs.put(item.FEC_Nature_of_Cases__c, item);
        }

        List<FEC_Hold_Case_Config__c> inserts = new List<FEC_Hold_Case_Config__c>();
        List<FEC_Nature_of_Case__c> nextNodes = new List<FEC_Nature_of_Case__c>();

        /* =========================================
         * PROCESS CHILDREN
         * ========================================= */
        for (FEC_Nature_of_Case__c child : children) {

            if (existingConfigs.containsKey(child.Id)) continue;

            if (sourceIsSubCode) {
                Boolean isCategory    = child.FEC_Category__c != null
                                     && child.FEC_Sub_Category__c == null;
                Boolean isSubCategory = child.FEC_Category__c != null
                                     && child.FEC_Sub_Category__c != null;

                if (!isCategory && !isSubCategory) continue;
            }

            FEC_Hold_Case_Config__c cloneRec = sourceConfig.clone(false, true, false, false);
            cloneRec.FEC_Nature_of_Cases__c = child.Id;
            inserts.add(cloneRec);
            nextNodes.add(child);
        }

        /* =========================================
         * INSERT
         * ========================================= */
        if (!inserts.isEmpty()) {
            insert inserts;
        }

        /* =========================================
         * CONTINUE RECURSIVE
         * ========================================= */
        for (FEC_Nature_of_Case__c node : nextNodes) {
            if (node.FEC_Sub_Code__c == null) {
                processNode(node, sourceConfig, sourceIsSubCode);
            }
        }
    }

    /* =====================================================
     * GET DIRECT CHILDREN
     * ===================================================== */
    private static List<FEC_Nature_of_Case__c> getDirectChildren(
        FEC_Nature_of_Case__c node
    ) {
        /* =================================================
         * CASE 1 — PRODUCT ONLY
         * ================================================= */
        if (
            node.FEC_Product_Type__c != null &&
            node.FEC_Category__c     == null &&
            node.FEC_Sub_Category__c == null &&
            node.FEC_Sub_Code__c     == null
        ) {
            return [
                SELECT
                    Id, Name,
                    FEC_Product_Type__c,
                    FEC_Category__c,
                    FEC_Sub_Category__c,
                    FEC_Sub_Code__c
                FROM FEC_Nature_of_Case__c
                WHERE
                    Id != :node.Id
                    AND FEC_Product_Type__c = :node.FEC_Product_Type__c
                    AND FEC_Category__c     = null
                    AND FEC_Sub_Category__c = null
                    AND FEC_Sub_Code__c     = null
            ];
        }

        /* =================================================
         * CASE 2 — PRODUCT + CATEGORY
         * ================================================= */
        if (
            node.FEC_Product_Type__c != null &&
            node.FEC_Category__c     != null &&
            node.FEC_Sub_Category__c == null &&
            node.FEC_Sub_Code__c     == null
        ) {
            return [
                SELECT
                    Id, Name,
                    FEC_Product_Type__c,
                    FEC_Category__c,
                    FEC_Sub_Category__c,
                    FEC_Sub_Code__c
                FROM FEC_Nature_of_Case__c
                WHERE
                    Id != :node.Id
                    AND FEC_Product_Type__c = :node.FEC_Product_Type__c
                    AND FEC_Category__c     = :node.FEC_Category__c
                    AND FEC_Sub_Category__c = null
                    AND FEC_Sub_Code__c     = null
            ];
        }

        /* =================================================
         * CASE 3 — PRODUCT + CATEGORY + SUB CATEGORY
         * ================================================= */
        if (
            node.FEC_Product_Type__c != null &&
            node.FEC_Category__c     != null &&
            node.FEC_Sub_Category__c != null &&
            node.FEC_Sub_Code__c     == null
        ) {
            return [
                SELECT
                    Id, Name,
                    FEC_Product_Type__c,
                    FEC_Category__c,
                    FEC_Sub_Category__c,
                    FEC_Sub_Code__c
                FROM FEC_Nature_of_Case__c
                WHERE
                    Id != :node.Id
                    AND FEC_Product_Type__c = :node.FEC_Product_Type__c
                    AND FEC_Category__c     = :node.FEC_Category__c
                    AND FEC_Sub_Category__c = :node.FEC_Sub_Category__c
            ];
        }

        return new List<FEC_Nature_of_Case__c>();
    }
}