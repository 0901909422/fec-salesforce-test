public with sharing class FEC_RelevantTicketController {

    @AuraEnabled
    public static Id createRelevantTicket(String interactionId, String relatedToId) {
        FEC_Relevant_Ticket__c rt = new FEC_Relevant_Ticket__c();
        rt.FEC_Interaction__c = relatedToId;
        rt.FEC_Related_To__c  = String.isNotBlank(interactionId) ? interactionId : null;
        insert rt;
        return rt.Id;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getCaseById(String caseId) {
        if (String.isBlank(caseId)) return null;
        List<Case> cases = [SELECT Id, FEC_ID_Search__c, CaseNumber, Subject, Status FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty()) return null;
        Case c = cases[0];
        return new Map<String, String>{
            'id'    => c.Id,
            'label' => (String.isNotBlank(c.FEC_ID_Search__c) ? c.FEC_ID_Search__c : c.CaseNumber),
            'sub'   => (String.isNotBlank(c.Subject) ? c.Subject : '') + ' | ' + (c.Status != null ? c.Status : '')
        };
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchCases(String searchTerm) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) return results;
        String q = '%' + searchTerm + '%';
        for (Case c : [
            SELECT Id, FEC_ID_Search__c, CaseNumber, Subject, Status
            FROM Case
            WHERE (FEC_ID_Search__c LIKE :q OR CaseNumber LIKE :q)
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ]) {
            results.add(new Map<String, String>{
                'id'    => c.Id,
                'label' => (String.isNotBlank(c.FEC_ID_Search__c) ? c.FEC_ID_Search__c : c.CaseNumber),
                'sub'   => (String.isNotBlank(c.Subject) ? c.Subject : '') + ' | ' + (c.Status != null ? c.Status : '')
            });
        }
        return results;
    }
    
}
