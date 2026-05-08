// tungnm37: Handler kế thừa FEC_Channel__c từ NOC cha xuống NOC con theo hierarchy
public without sharing class FEC_NatureOfCaseTriggerHandler {

    public static void handleAfterInsertUpdate(
        List<FEC_Nature_of_Case__c> newList,
        Map<Id, FEC_Nature_of_Case__c> oldMap
    ) {
        List<FEC_Nature_of_Case__c> changed = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c noc : newList) {
            if (String.isBlank(noc.FEC_Channel__c)) continue;
            // tungnm37: chỉ propagate khi channel thay đổi (từ null → có giá trị, hoặc đổi giá trị)
            if (oldMap != null) {
                FEC_Nature_of_Case__c old = oldMap.get(noc.Id);
                if (old != null && noc.FEC_Channel__c == old.FEC_Channel__c) continue;
            }
            changed.add(noc);
        }
        if (changed.isEmpty()) return;

        propagateChannelToChildren(changed);
    }

    private static void propagateChannelToChildren(List<FEC_Nature_of_Case__c> parents) {
        List<FEC_Nature_of_Case__c> toUpdate = new List<FEC_Nature_of_Case__c>();

        for (FEC_Nature_of_Case__c parent : parents) {
            String channelVal = parent.FEC_Channel__c;
            Id bpId = parent.FEC_Business_Process__c;
            Id catId = parent.FEC_Category__c;
            Id subCatId = parent.FEC_Sub_Category__c;
            Id subCodeId = parent.FEC_Sub_Code__c;

            List<FEC_Nature_of_Case__c> children;

            // tungnm37: xác định con theo level hierarchy
            // Level 1 (chỉ BP): con là tất cả NOC cùng BP
            if (bpId != null && catId == null && subCatId == null && subCodeId == null) {
                children = [
                    SELECT Id, FEC_Channel__c FROM FEC_Nature_of_Case__c
                    WHERE FEC_Business_Process__c = :bpId
                      AND Id != :parent.Id AND FEC_Channel__c = null
                ];
            }
            // Level 2 (BP + Cat): con là NOC cùng BP+Cat
            else if (bpId != null && catId != null && subCatId == null && subCodeId == null) {
                children = [
                    SELECT Id, FEC_Channel__c FROM FEC_Nature_of_Case__c
                    WHERE FEC_Business_Process__c = :bpId
                      AND FEC_Category__c = :catId
                      AND Id != :parent.Id AND FEC_Channel__c = null
                ];
            }
            // Level 3 (BP + Cat + SubCat): con là NOC cùng BP+Cat+SubCat
            else if (bpId != null && catId != null && subCatId != null && subCodeId == null) {
                children = [
                    SELECT Id, FEC_Channel__c FROM FEC_Nature_of_Case__c
                    WHERE FEC_Business_Process__c = :bpId
                      AND FEC_Category__c = :catId
                      AND FEC_Sub_Category__c = :subCatId
                      AND Id != :parent.Id AND FEC_Channel__c = null
                ];
            }
            // Level 4 (đầy đủ): không có con
            else {
                continue;
            }

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
