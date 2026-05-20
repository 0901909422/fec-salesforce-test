// Inherit sub process: same FEC_Product_Type__c; parent = more nulls (lower specificity), child = more specific.
public without sharing class FEC_NocRemovePhoneInheritanceHandler {

    private static final String NOC_FIELDS_FOR_INHERIT = 'Id, FEC_Product_Type__c, FEC_Business_Process__c, '
        + 'FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c, FEC_Remove_Phone__c, '
        + 'FEC_Do_Not_Bother__c, FEC_Transfer_Call_to_Collection__c, FEC_Active__c';

    public static void handleAfterInsertUpdate(
        List<FEC_Nature_of_Case__c> newList,
        Map<Id, FEC_Nature_of_Case__c> oldMap
    ) {
        if (oldMap == null) {
            inheritFromParentForNewChildren(newList);
        }

        List<FEC_Nature_of_Case__c> changed = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c noc : newList) {
            if (!FEC_NocInheritanceUtil.isParentCandidate(noc)) {
                continue;
            }
            if (oldMap != null) {
                FEC_Nature_of_Case__c oldRec = oldMap.get(noc.Id);
                if (oldRec != null &&
                    noc.FEC_Remove_Phone__c == oldRec.FEC_Remove_Phone__c &&
                    noc.FEC_Do_Not_Bother__c == oldRec.FEC_Do_Not_Bother__c &&
                    noc.FEC_Transfer_Call_to_Collection__c == oldRec.FEC_Transfer_Call_to_Collection__c
                ) {
                    continue;
                }
            }
            changed.add(noc);
        }
        if (changed.isEmpty()) {
            return;
        }

        propagateRemovePhoneToChildren(changed);
    }

    private static void inheritFromParentForNewChildren(List<FEC_Nature_of_Case__c> newList) {
        List<FEC_Nature_of_Case__c> targets = new List<FEC_Nature_of_Case__c>();
        Set<Id> productTypeIds = new Set<Id>();
        for (FEC_Nature_of_Case__c noc : newList) {
            if (noc.FEC_Active__c != true || noc.FEC_Product_Type__c == null) {
                continue;
            }
            if (FEC_NocInheritanceUtil.specificityScore(noc) == 0) {
                continue;
            }
            if (noc.FEC_Remove_Phone__c == false
                || noc.FEC_Do_Not_Bother__c == false
                || noc.FEC_Transfer_Call_to_Collection__c == false
            ) {
                targets.add(noc);
                productTypeIds.add(noc.FEC_Product_Type__c);
            }
        }
        if (targets.isEmpty()) {
            return;
        }

        List<FEC_Nature_of_Case__c> parentCandidates = Database.query(
            'SELECT ' + NOC_FIELDS_FOR_INHERIT +
            ' FROM FEC_Nature_of_Case__c WHERE FEC_Active__c = true'
            + ' AND FEC_Product_Type__c IN :productTypeIds'
            + ' AND FEC_Sub_Code__c = null'
            + ' AND (FEC_Remove_Phone__c = true OR FEC_Do_Not_Bother__c = true'
            + ' OR FEC_Transfer_Call_to_Collection__c = true)'
        );

        List<FEC_Nature_of_Case__c> toUpdate = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c child : targets) {
            FEC_Nature_of_Case__c parent = FEC_NocInheritanceUtil.findImmediateParent(child, parentCandidates);
            if (parent == null) {
                continue;
            }
            FEC_Nature_of_Case__c upd = new FEC_Nature_of_Case__c(Id = child.Id);
            Boolean hasAnyChange = false;
            if (child.FEC_Remove_Phone__c == false && parent.FEC_Remove_Phone__c == true) {
                upd.FEC_Remove_Phone__c = true;
                hasAnyChange = true;
            }
            if (child.FEC_Do_Not_Bother__c == false && parent.FEC_Do_Not_Bother__c == true) {
                upd.FEC_Do_Not_Bother__c = true;
                hasAnyChange = true;
            }
            if (child.FEC_Transfer_Call_to_Collection__c == false
                && parent.FEC_Transfer_Call_to_Collection__c == true
            ) {
                upd.FEC_Transfer_Call_to_Collection__c = true;
                hasAnyChange = true;
            }
            if (hasAnyChange) {
                toUpdate.add(upd);
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false);
        }
    }

    private static void propagateRemovePhoneToChildren(List<FEC_Nature_of_Case__c> parents) {
        Set<Id> productTypeIds = new Set<Id>();
        for (FEC_Nature_of_Case__c p : parents) {
            if (p.FEC_Product_Type__c != null) {
                productTypeIds.add(p.FEC_Product_Type__c);
            }
        }
        if (productTypeIds.isEmpty()) {
            return;
        }

        List<FEC_Nature_of_Case__c> pool = Database.query(
            'SELECT ' + NOC_FIELDS_FOR_INHERIT +
            ' FROM FEC_Nature_of_Case__c WHERE FEC_Product_Type__c IN :productTypeIds'
            + ' AND FEC_Active__c = true'
        );

        List<FEC_Nature_of_Case__c> toUpdate = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c parent : parents) {
            if (!FEC_NocInheritanceUtil.isParentCandidate(parent)) {
                continue;
            }

            Boolean removePhoneVal = parent.FEC_Remove_Phone__c;
            Boolean doNotBotherVal = parent.FEC_Do_Not_Bother__c;
            Boolean transferToCollectionVal = parent.FEC_Transfer_Call_to_Collection__c;

            for (FEC_Nature_of_Case__c child : FEC_NocInheritanceUtil.findDescendants(parent, pool)) {
                if (child.Id == parent.Id) {
                    continue;
                }
                FEC_Nature_of_Case__c upd = new FEC_Nature_of_Case__c(Id = child.Id);
                Boolean hasAnyChange = false;
                if (child.FEC_Remove_Phone__c == false) {
                    upd.FEC_Remove_Phone__c = removePhoneVal;
                    hasAnyChange = true;
                }
                if (child.FEC_Do_Not_Bother__c == false) {
                    upd.FEC_Do_Not_Bother__c = doNotBotherVal;
                    hasAnyChange = true;
                }
                if (child.FEC_Transfer_Call_to_Collection__c == false) {
                    upd.FEC_Transfer_Call_to_Collection__c = transferToCollectionVal;
                    hasAnyChange = true;
                }
                if (hasAnyChange) {
                    toUpdate.add(upd);
                }
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false);
        }
    }
}
