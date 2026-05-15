// Inherit sub process flags from parent NOC to children by hierarchy.
public without sharing class FEC_NocRemovePhoneInheritanceHandler {

    public static void handleAfterInsertUpdate(
        List<FEC_Nature_of_Case__c> newList,
        Map<Id, FEC_Nature_of_Case__c> oldMap
    ) {
        // Insert flow: child mới (false) cần kế thừa từ cha đã cấu hình true.
        if (oldMap == null) {
            inheritFromParentForNewChildren(newList);
        }

        List<FEC_Nature_of_Case__c> changed = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c noc : newList) {
            if (noc.FEC_Active__c != true) continue;
            if (oldMap != null) {
                FEC_Nature_of_Case__c oldRec = oldMap.get(noc.Id);
                if (oldRec != null &&
                    noc.FEC_Remove_Phone__c == oldRec.FEC_Remove_Phone__c &&
                    noc.FEC_Do_Not_Bother__c == oldRec.FEC_Do_Not_Bother__c &&
                    noc.FEC_Transfer_Call_to_Collection__c == oldRec.FEC_Transfer_Call_to_Collection__c
                ) continue;
            }
            changed.add(noc);
        }
        if (changed.isEmpty()) return;

        propagateRemovePhoneToChildren(changed);
    }

    private static void inheritFromParentForNewChildren(List<FEC_Nature_of_Case__c> newList) {
        List<FEC_Nature_of_Case__c> targets = new List<FEC_Nature_of_Case__c>();
        Set<Id> bpIds = new Set<Id>();
        for (FEC_Nature_of_Case__c noc : newList) {
            if (noc.FEC_Active__c == true &&
                noc.FEC_Business_Process__c != null &&
                (
                    noc.FEC_Remove_Phone__c == false ||
                    noc.FEC_Do_Not_Bother__c == false ||
                    noc.FEC_Transfer_Call_to_Collection__c == false
                )
            ) {
                targets.add(noc);
                bpIds.add(noc.FEC_Business_Process__c);
            }
        }
        if (targets.isEmpty()) return;

        List<FEC_Nature_of_Case__c> parentCandidates = [
            SELECT Id, FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c,
                   FEC_Remove_Phone__c, FEC_Do_Not_Bother__c, FEC_Transfer_Call_to_Collection__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Active__c = true
              AND (
                    FEC_Remove_Phone__c = true OR
                    FEC_Do_Not_Bother__c = true OR
                    FEC_Transfer_Call_to_Collection__c = true
              )
              AND FEC_Business_Process__c IN :bpIds
        ];

        List<FEC_Nature_of_Case__c> toUpdate = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c child : targets) {
            if (hasConfiguredParent(child, parentCandidates)) {
                FEC_Nature_of_Case__c upd = new FEC_Nature_of_Case__c(Id = child.Id);
                FEC_Nature_of_Case__c parent = getMatchedParent(child, parentCandidates);
                if (parent == null) continue;
                Boolean hasAnyChange = false;
                if (child.FEC_Remove_Phone__c == false && parent.FEC_Remove_Phone__c == true) {
                    upd.FEC_Remove_Phone__c = true;
                    hasAnyChange = true;
                }
                if (child.FEC_Do_Not_Bother__c == false && parent.FEC_Do_Not_Bother__c == true) {
                    upd.FEC_Do_Not_Bother__c = true;
                    hasAnyChange = true;
                }
                if (child.FEC_Transfer_Call_to_Collection__c == false && parent.FEC_Transfer_Call_to_Collection__c == true) {
                    upd.FEC_Transfer_Call_to_Collection__c = true;
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

    private static Boolean hasConfiguredParent(FEC_Nature_of_Case__c child, List<FEC_Nature_of_Case__c> candidates) {
        return getMatchedParent(child, candidates) != null;
    }

    private static FEC_Nature_of_Case__c getMatchedParent(FEC_Nature_of_Case__c child, List<FEC_Nature_of_Case__c> candidates) {
        for (FEC_Nature_of_Case__c p : candidates) {
            if (p.Id == child.Id) continue;
            if (p.FEC_Business_Process__c != child.FEC_Business_Process__c) continue;

            // Parent of level 2: BP-only parent.
            if (child.FEC_Category__c != null && child.FEC_Sub_Category__c == null && child.FEC_Sub_Code__c == null) {
                if (p.FEC_Category__c == null && p.FEC_Sub_Category__c == null && p.FEC_Sub_Code__c == null) return p;
            }
            // Parent of level 3: same BP + Category, parent has null SubCategory/SubCode.
            else if (child.FEC_Category__c != null && child.FEC_Sub_Category__c != null && child.FEC_Sub_Code__c == null) {
                if (p.FEC_Category__c == child.FEC_Category__c && p.FEC_Sub_Category__c == null && p.FEC_Sub_Code__c == null) return p;
            }
            // Parent of level 4: same BP + Category + SubCategory, parent has null SubCode.
            else if (child.FEC_Category__c != null && child.FEC_Sub_Category__c != null && child.FEC_Sub_Code__c != null) {
                if (p.FEC_Category__c == child.FEC_Category__c && p.FEC_Sub_Category__c == child.FEC_Sub_Category__c && p.FEC_Sub_Code__c == null) return p;
            }
        }
        return null;
    }

    private static void propagateRemovePhoneToChildren(List<FEC_Nature_of_Case__c> parents) {
        List<FEC_Nature_of_Case__c> toUpdate = new List<FEC_Nature_of_Case__c>();

        for (FEC_Nature_of_Case__c parent : parents) {
            Boolean removePhoneVal = parent.FEC_Remove_Phone__c;
            Boolean doNotBotherVal = parent.FEC_Do_Not_Bother__c;
            Boolean transferToCollectionVal = parent.FEC_Transfer_Call_to_Collection__c;
            Id bpId = parent.FEC_Business_Process__c;
            Id catId = parent.FEC_Category__c;
            Id subCatId = parent.FEC_Sub_Category__c;
            Id subCodeId = parent.FEC_Sub_Code__c;

            List<FEC_Nature_of_Case__c> children;

            // Level 1 (only BP): children are all records in same BP.
            if (bpId != null && catId == null && subCatId == null && subCodeId == null) {
                children = [
                    SELECT Id, FEC_Remove_Phone__c, FEC_Do_Not_Bother__c, FEC_Transfer_Call_to_Collection__c
                    FROM FEC_Nature_of_Case__c
                    WHERE FEC_Business_Process__c = :bpId
                      AND FEC_Active__c = true
                      AND Id != :parent.Id
                      AND (
                            FEC_Remove_Phone__c = false OR
                            FEC_Do_Not_Bother__c = false OR
                            FEC_Transfer_Call_to_Collection__c = false
                      )
                ];
            }
            // Level 2 (BP + Cat): children in same BP + Cat.
            else if (bpId != null && catId != null && subCatId == null && subCodeId == null) {
                children = [
                    SELECT Id, FEC_Remove_Phone__c, FEC_Do_Not_Bother__c, FEC_Transfer_Call_to_Collection__c
                    FROM FEC_Nature_of_Case__c
                    WHERE FEC_Business_Process__c = :bpId
                      AND FEC_Category__c = :catId
                      AND FEC_Active__c = true
                      AND Id != :parent.Id
                      AND (
                            FEC_Remove_Phone__c = false OR
                            FEC_Do_Not_Bother__c = false OR
                            FEC_Transfer_Call_to_Collection__c = false
                      )
                ];
            }
            // Level 3 (BP + Cat + SubCat): children in same BP + Cat + SubCat.
            else if (bpId != null && catId != null && subCatId != null && subCodeId == null) {
                children = [
                    SELECT Id, FEC_Remove_Phone__c, FEC_Do_Not_Bother__c, FEC_Transfer_Call_to_Collection__c
                    FROM FEC_Nature_of_Case__c
                    WHERE FEC_Business_Process__c = :bpId
                      AND FEC_Category__c = :catId
                      AND FEC_Sub_Category__c = :subCatId
                      AND FEC_Active__c = true
                      AND Id != :parent.Id
                      AND (
                            FEC_Remove_Phone__c = false OR
                            FEC_Do_Not_Bother__c = false OR
                            FEC_Transfer_Call_to_Collection__c = false
                      )
                ];
            } else {
                continue;
            }

            for (FEC_Nature_of_Case__c child : children) {
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
