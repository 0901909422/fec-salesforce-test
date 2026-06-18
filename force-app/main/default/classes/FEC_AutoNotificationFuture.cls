public with sharing class FEC_AutoNotificationFuture {

    @future(callout=true)
    public static void sendZNSAsync(String newCasesJson, String oldMapJson) {
        List<Case> newCases = parseNewCases(newCasesJson);
        Map<Id, Case> oldMap = parseOldMap(oldMapJson);

        FEC_NotificationService.sendZNSNotification(newCases, oldMap);
    }

    @future(callout=true)
    public static void sendMobileAppAsync(String newCasesJson, String oldMapJson) {
        List<Case> newCases = parseNewCases(newCasesJson);
        Map<Id, Case> oldMap = parseOldMap(oldMapJson);

        FEC_NotificationService.sendMobileAppNotification(newCases, oldMap);
    }

    private static List<Case> parseNewCases(String newCasesJson) {
        if (String.isBlank(newCasesJson)) {
            return new List<Case>();
        }

        return (List<Case>) JSON.deserialize(
            newCasesJson,
            List<Case>.class
        );
    }

    private static Map<Id, Case> parseOldMap(String oldMapJson) {
        Map<Id, Case> result = new Map<Id, Case>();

        if (String.isBlank(oldMapJson)) {
            return result;
        }

        Map<String, Case> rawMap = (Map<String, Case>) JSON.deserialize(
            oldMapJson,
            Map<String, Case>.class
        );

        for (String caseIdStr : rawMap.keySet()) {
            result.put((Id) caseIdStr, rawMap.get(caseIdStr));
        }

        return result;
    }
}