// tungnm37: FEC_Channel__c — cùng FEC_Product_Type__c; cha = nhiều null hơn (ít specificity hơn con).
public without sharing class FEC_NatureOfCaseTriggerHandler {

    private static final String NOC_CHANNEL_FIELDS = 'Id, FEC_Product_Type__c, FEC_Business_Process__c, '
        + 'FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c, FEC_Channel__c, FEC_Active__c';

    public static void handleAfterInsertUpdate(
        List<FEC_Nature_of_Case__c> newList,
        Map<Id, FEC_Nature_of_Case__c> oldMap
    ) {
        if (oldMap == null) {
            inheritChannelFromParentForNewChildren(newList);
        }

        List<FEC_Nature_of_Case__c> changed = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c noc : newList) {
            if (!FEC_NocInheritanceUtil.isParentCandidate(noc)) {
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

    private static void inheritChannelFromParentForNewChildren(List<FEC_Nature_of_Case__c> newList) {
        List<FEC_Nature_of_Case__c> targets = new List<FEC_Nature_of_Case__c>();
        Set<Id> productTypeIds = new Set<Id>();
        for (FEC_Nature_of_Case__c noc : newList) {
            if (noc.FEC_Active__c == true
                && noc.FEC_Product_Type__c != null
                && String.isBlank(noc.FEC_Channel__c)
                && FEC_NocInheritanceUtil.specificityScore(noc) > 0
            ) {
                targets.add(noc);
                productTypeIds.add(noc.FEC_Product_Type__c);
            }
        }
        if (targets.isEmpty()) {
            return;
        }

        List<FEC_Nature_of_Case__c> parentCandidates = Database.query(
            'SELECT ' + NOC_CHANNEL_FIELDS +
            ' FROM FEC_Nature_of_Case__c WHERE FEC_Active__c = true'
            + ' AND FEC_Product_Type__c IN :productTypeIds'
            + ' AND FEC_Sub_Code__c = null'
            + ' AND FEC_Channel__c != null'
        );

        List<FEC_Nature_of_Case__c> toUpdate = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c child : targets) {
            FEC_Nature_of_Case__c parent = FEC_NocInheritanceUtil.findImmediateParent(child, parentCandidates);
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

    private static void propagateChannelToChildren(List<FEC_Nature_of_Case__c> parents) {
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
            'SELECT ' + NOC_CHANNEL_FIELDS +
            ' FROM FEC_Nature_of_Case__c WHERE FEC_Product_Type__c IN :productTypeIds'
            + ' AND FEC_Active__c = true'
        );

        List<FEC_Nature_of_Case__c> toUpdate = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c parent : parents) {
            if (!FEC_NocInheritanceUtil.isParentCandidate(parent)
                || String.isBlank(parent.FEC_Channel__c)
            ) {
                continue;
            }

            String channelVal = parent.FEC_Channel__c;
            for (FEC_Nature_of_Case__c child : FEC_NocInheritanceUtil.findDescendants(parent, pool)) {
                if (child.Id == parent.Id) {
                    continue;
                }
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
