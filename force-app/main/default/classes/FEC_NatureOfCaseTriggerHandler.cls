// tungnm37: Handler kế thừa FEC_Channel__c từ NOC cha xuống NOC con theo hierarchy (Channel Config)
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
            if (noc.FEC_Active__c != true) {
                continue;
            }
            if (String.isBlank(noc.FEC_Channel__c)) {
                continue;
            }
            // tungnm37: chỉ propagate khi channel thay đổi (từ null → có giá trị, hoặc đổi giá trị)
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

    /**
     * Con mới insert để trống Channel: lấy Channel từ NOC cha đã cấu hình (cùng logic bậc hierarchy với Sub Process).
     */
    private static void inheritChannelFromParentForNewChildren(List<FEC_Nature_of_Case__c> newList) {
        List<FEC_Nature_of_Case__c> targets = new List<FEC_Nature_of_Case__c>();
        Set<Id> bpIds = new Set<Id>();
        for (FEC_Nature_of_Case__c noc : newList) {
            if (noc.FEC_Active__c == true
                && String.isBlank(noc.FEC_Channel__c)
                && noc.FEC_Business_Process__c != null
                && noc.FEC_Category__c != null
            ) {
                targets.add(noc);
                bpIds.add(noc.FEC_Business_Process__c);
            }
        }
        if (targets.isEmpty()) {
            return;
        }

        List<FEC_Nature_of_Case__c> parentCandidates = [
            SELECT Id, FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c, FEC_Channel__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Active__c = true
                AND FEC_Channel__c != null
                AND FEC_Business_Process__c IN :bpIds
        ];

        List<FEC_Nature_of_Case__c> toUpdate = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c child : targets) {
            FEC_Nature_of_Case__c parent = getChannelMatchedParent(child, parentCandidates);
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

    private static FEC_Nature_of_Case__c getChannelMatchedParent(
        FEC_Nature_of_Case__c child,
        List<FEC_Nature_of_Case__c> candidates
    ) {
        for (FEC_Nature_of_Case__c p : candidates) {
            if (p.Id == child.Id) {
                continue;
            }
            if (p.FEC_Business_Process__c != child.FEC_Business_Process__c) {
                continue;
            }
            if (child.FEC_Category__c != null && child.FEC_Sub_Category__c == null && child.FEC_Sub_Code__c == null) {
                if (p.FEC_Category__c == null && p.FEC_Sub_Category__c == null && p.FEC_Sub_Code__c == null) {
                    return p;
                }
            } else if (child.FEC_Category__c != null && child.FEC_Sub_Category__c != null && child.FEC_Sub_Code__c == null) {
                if (p.FEC_Category__c == child.FEC_Category__c && p.FEC_Sub_Category__c == null && p.FEC_Sub_Code__c == null) {
                    return p;
                }
            } else if (child.FEC_Category__c != null && child.FEC_Sub_Category__c != null && child.FEC_Sub_Code__c != null) {
                if (p.FEC_Category__c == child.FEC_Category__c
                    && p.FEC_Sub_Category__c == child.FEC_Sub_Category__c
                    && p.FEC_Sub_Code__c == null) {
                    return p;
                }
            }
        }
        return null;
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
                      AND FEC_Active__c = true
                      AND Id != :parent.Id
                ];
            }
            // Level 2 (BP + Cat): con là NOC cùng BP+Cat
            else if (bpId != null && catId != null && subCatId == null && subCodeId == null) {
                children = [
                    SELECT Id, FEC_Channel__c FROM FEC_Nature_of_Case__c
                    WHERE FEC_Business_Process__c = :bpId
                      AND FEC_Category__c = :catId
                      AND FEC_Active__c = true
                      AND Id != :parent.Id
                ];
            }
            // Level 3 (BP + Cat + SubCat): con là NOC cùng BP+Cat+SubCat
            else if (bpId != null && catId != null && subCatId != null && subCodeId == null) {
                children = [
                    SELECT Id, FEC_Channel__c FROM FEC_Nature_of_Case__c
                    WHERE FEC_Business_Process__c = :bpId
                      AND FEC_Category__c = :catId
                      AND FEC_Sub_Category__c = :subCatId
                      AND FEC_Active__c = true
                      AND Id != :parent.Id
                ];
            }
            // Level 3b (Cat + SubCat, không có BP): con là NOC cùng Cat+SubCat
            else if (bpId == null && catId != null && subCatId != null && subCodeId == null) {
                children = [
                    SELECT Id, FEC_Channel__c FROM FEC_Nature_of_Case__c
                    WHERE FEC_Category__c = :catId
                      AND FEC_Sub_Category__c = :subCatId
                      AND FEC_Active__c = true
                      AND Id != :parent.Id
                ];
            }
            // Level 2b (chỉ Cat, không có BP): con là NOC cùng Cat
            else if (bpId == null && catId != null && subCatId == null && subCodeId == null) {
                children = [
                    SELECT Id, FEC_Channel__c FROM FEC_Nature_of_Case__c
                    WHERE FEC_Category__c = :catId
                      AND FEC_Active__c = true
                      AND Id != :parent.Id
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
