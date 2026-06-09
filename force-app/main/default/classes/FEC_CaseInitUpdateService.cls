/**
 * Cập nhật Case khi LWC init — tránh updateRecord client-side gây race / side-effect trigger.
 */
public without sharing class FEC_CaseInitUpdateService {
    @AuraEnabled
    public static void updateRoutingActionDisplay(Id caseId, String routingActionDisplay) {
        if (caseId == null) {
            return;
        }
        String displayValue = routingActionDisplay == null ? '' : routingActionDisplay;
        runSystemCaseUpdate(
            new Case(
                Id = caseId,
                FEC_Is_Routing_Action_Display__c = displayValue
            )
        );
    }

    @AuraEnabled
    public static void clearCreatedFromSearchFlag(Id caseId) {
        if (caseId == null) {
            return;
        }
        List<Case> caseList = [
            SELECT Id, FEC_Is_Created_From_Search__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (caseList.isEmpty() || caseList[0].FEC_Is_Created_From_Search__c != true) {
            return;
        }
        runSystemCaseUpdate(
            new Case(
                Id = caseId,
                FEC_Is_Created_From_Search__c = false
            )
        );
    }

    public static void runSystemCaseUpdateIfChanged(Case current, Case baseline) {
        if (current == null || current.Id == null) {
            return;
        }
        if (baseline == null || !hasPersistableFieldChanges(current, baseline)) {
            return;
        }
        runSystemCaseUpdate(current);
    }

    public static void runSystemCaseUpdate(Case caseUpdate) {
        if (caseUpdate == null || caseUpdate.Id == null) {
            return;
        }
        registerSystemCaseUpdate(caseUpdate.Id);
        FEC_CaseTriggerHandler.isSystemUpdate = true;
        try {
            update caseUpdate;
        } catch (DmlException e) {
            System.debug('FEC_CaseInitUpdateService.runSystemCaseUpdate failed: ' + e.getMessage());
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = false;
        }
    }

    public static void registerSystemCaseUpdate(Id caseId) {
        if (caseId != null) {
            FEC_CaseTriggerHandler.systemUpdatedCaseIds.add(caseId);
        }
    }

    public static Boolean hasPersistableFieldChanges(Case current, Case baseline) {
        if (current == null || baseline == null) {
            return current != null;
        }

        Map<String, Object> currentFields = current.getPopulatedFieldsAsMap();
        Map<String, Object> baselineFields = baseline.getPopulatedFieldsAsMap();

        for (String fieldName : currentFields.keySet()) {
            if (fieldName == 'Id' || fieldName.endsWith('__r')) {
                continue;
            }
            Object currentValue = currentFields.get(fieldName);
            Object baselineValue = baselineFields.get(fieldName);
            if (!valuesEqual(currentValue, baselineValue)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean valuesEqual(Object left, Object right) {
        if (left == right) {
            return true;
        }
        if (left == null || right == null) {
            return false;
        }
        return String.valueOf(left) == String.valueOf(right);
    }
}
