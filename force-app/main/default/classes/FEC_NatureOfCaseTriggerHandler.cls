// tungnm37: Handler kế thừa FEC_Channel__c — cha/con theo FEC_Sub_Category__c (cha không Sub Code, con có Sub Code).
public without sharing class FEC_NatureOfCaseTriggerHandler {

    public static void handleAfterInsertUpdate(
        List<FEC_Nature_of_Case__c> newList,
        Map<Id, FEC_Nature_of_Case__c> oldMap
    ) {
        if (oldMap == null) {
            inheritChannelFromParentForNewChildren(newList);
        }

        List<FEC_Nature_of_Case__c> changed = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c noc : newList) {
            if (noc.FEC_Active__c != true || !isParentNoc(noc)) {
                continue;
            }
            if (String.isBlank(noc.FEC_Channel__c)) {
                continue;
            }
            if (oldMap != null) {
                FEC_Nature_of_Case__c old = oldMap.get(noc.Id);
                if (old != null && noc.FEC_Channel__c == old.FEC_Channel__c) {
                    continue;
                }
            }
            changed.add(noc);
        }
        if (changed.isEmpty()) {
            return;
        }

        propagateChannelToChildren(changed);
    }

    private static Boolean isParentNoc(FEC_Nature_of_Case__c noc) {
        return noc.FEC_Sub_Category__c != null && noc.FEC_Sub_Code__c == null;
    }

    private static Boolean isChildNoc(FEC_Nature_of_Case__c noc) {
        return noc.FEC_Sub_Category__c != null && noc.FEC_Sub_Code__c != null;
    }

    private static void inheritChannelFromParentForNewChildren(List<FEC_Nature_of_Case__c> newList) {
        List<FEC_Nature_of_Case__c> targets = new List<FEC_Nature_of_Case__c>();
        Set<Id> subCatIds = new Set<Id>();
        for (FEC_Nature_of_Case__c noc : newList) {
            if (noc.FEC_Active__c == true && isChildNoc(noc) && String.isBlank(noc.FEC_Channel__c)) {
                targets.add(noc);
                subCatIds.add(noc.FEC_Sub_Category__c);
            }
        }
        if (targets.isEmpty()) {
            return;
        }

        List<FEC_Nature_of_Case__c> parentCandidates = [
            SELECT Id, FEC_Sub_Category__c, FEC_Channel__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Active__c = true
              AND FEC_Sub_Category__c IN :subCatIds
              AND FEC_Sub_Code__c = null
              AND FEC_Channel__c != null
        ];

        List<FEC_Nature_of_Case__c> toUpdate = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c child : targets) {
            FEC_Nature_of_Case__c parent = getMatchedParent(child, parentCandidates);
            if (parent == null || String.isBlank(parent.FEC_Channel__c)) {
                continue;
            }
            toUpdate.add(new FEC_Nature_of_Case__c(
                Id = child.Id,
                FEC_Channel__c = parent.FEC_Channel__c
            ));
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

    private static void propagateChannelToChildren(List<FEC_Nature_of_Case__c> parents) {
        List<FEC_Nature_of_Case__c> toUpdate = new List<FEC_Nature_of_Case__c>();

        for (FEC_Nature_of_Case__c parent : parents) {
            if (!isParentNoc(parent) || String.isBlank(parent.FEC_Channel__c)) {
                continue;
            }

            String channelVal = parent.FEC_Channel__c;
            Id subCatId = parent.FEC_Sub_Category__c;

            List<FEC_Nature_of_Case__c> children = [
                SELECT Id, FEC_Channel__c
                FROM FEC_Nature_of_Case__c
                WHERE FEC_Sub_Category__c = :subCatId
                  AND FEC_Sub_Code__c != null
                  AND FEC_Active__c = true
                  AND Id != :parent.Id
            ];

            for (FEC_Nature_of_Case__c child : children) {
                toUpdate.add(new FEC_Nature_of_Case__c(
                    Id = child.Id,
                    FEC_Channel__c = channelVal
                ));
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false);
        }
    }
}
