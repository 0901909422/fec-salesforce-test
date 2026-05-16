// Inherit sub process flags: parent/child by FEC_Sub_Category__c (parent has no Sub Code, child has Sub Code).
public without sharing class FEC_NocRemovePhoneInheritanceHandler {

    public static void handleAfterInsertUpdate(
        List<FEC_Nature_of_Case__c> newList,
        Map<Id, FEC_Nature_of_Case__c> oldMap
    ) {
        if (oldMap == null) {
            inheritFromParentForNewChildren(newList);
        }

        List<FEC_Nature_of_Case__c> changed = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c noc : newList) {
            if (noc.FEC_Active__c != true || !isParentNoc(noc)) {
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

    private static Boolean isParentNoc(FEC_Nature_of_Case__c noc) {
        return noc.FEC_Sub_Category__c != null && noc.FEC_Sub_Code__c == null;
    }

    private static Boolean isChildNoc(FEC_Nature_of_Case__c noc) {
        return noc.FEC_Sub_Category__c != null && noc.FEC_Sub_Code__c != null;
    }

    private static void inheritFromParentForNewChildren(List<FEC_Nature_of_Case__c> newList) {
        List<FEC_Nature_of_Case__c> targets = new List<FEC_Nature_of_Case__c>();
        Set<Id> subCatIds = new Set<Id>();
        for (FEC_Nature_of_Case__c noc : newList) {
            if (noc.FEC_Active__c == true &&
                isChildNoc(noc) &&
                (
                    noc.FEC_Remove_Phone__c == false ||
                    noc.FEC_Do_Not_Bother__c == false ||
                    noc.FEC_Transfer_Call_to_Collection__c == false
                )
            ) {
                targets.add(noc);
                subCatIds.add(noc.FEC_Sub_Category__c);
            }
        }
        if (targets.isEmpty()) {
            return;
        }

        List<FEC_Nature_of_Case__c> parentCandidates = [
            SELECT Id, FEC_Sub_Category__c,
                   FEC_Remove_Phone__c, FEC_Do_Not_Bother__c, FEC_Transfer_Call_to_Collection__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Active__c = true
              AND FEC_Sub_Category__c IN :subCatIds
              AND FEC_Sub_Code__c = null
              AND (
                    FEC_Remove_Phone__c = true OR
                    FEC_Do_Not_Bother__c = true OR
                    FEC_Transfer_Call_to_Collection__c = true
              )
        ];

        List<FEC_Nature_of_Case__c> toUpdate = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c child : targets) {
            FEC_Nature_of_Case__c parent = getMatchedParent(child, parentCandidates);
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
            if (child.FEC_Transfer_Call_to_Collection__c == false && parent.FEC_Transfer_Call_to_Collection__c == true) {
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

    private static FEC_Nature_of_Case__c getMatchedParent(
        FEC_Nature_of_Case__c child,
        List<FEC_Nature_of_Case__c> candidates
    ) {
        for (FEC_Nature_of_Case__c p : candidates) {
            if (p.Id == child.Id) {
                continue;
            }
            if (p.FEC_Sub_Category__c == child.FEC_Sub_Category__c && isParentNoc(p)) {
                return p;
            }
        }
        return null;
    }

    private static void propagateRemovePhoneToChildren(List<FEC_Nature_of_Case__c> parents) {
        List<FEC_Nature_of_Case__c> toUpdate = new List<FEC_Nature_of_Case__c>();

        for (FEC_Nature_of_Case__c parent : parents) {
            if (!isParentNoc(parent)) {
                continue;
            }

            Boolean removePhoneVal = parent.FEC_Remove_Phone__c;
            Boolean doNotBotherVal = parent.FEC_Do_Not_Bother__c;
            Boolean transferToCollectionVal = parent.FEC_Transfer_Call_to_Collection__c;
            Id subCatId = parent.FEC_Sub_Category__c;

            List<FEC_Nature_of_Case__c> children = [
                SELECT Id, FEC_Remove_Phone__c, FEC_Do_Not_Bother__c, FEC_Transfer_Call_to_Collection__c
                FROM FEC_Nature_of_Case__c
                WHERE FEC_Sub_Category__c = :subCatId
                  AND FEC_Sub_Code__c != null
                  AND FEC_Active__c = true
                  AND Id != :parent.Id
                  AND (
                        FEC_Remove_Phone__c = false OR
                        FEC_Do_Not_Bother__c = false OR
                        FEC_Transfer_Call_to_Collection__c = false
                  )
            ];

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
