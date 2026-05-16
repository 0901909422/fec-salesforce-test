// Debug: thử insert FEC_Relevant_Ticket__c với S-1367
// Tìm Case S-1367 trước
List<Case> interactions = [
    SELECT Id, FEC_ID_Search__c, RecordType.DeveloperName, RecordType.Name
    FROM Case
    WHERE FEC_ID_Search__c = 'S-1367'
    LIMIT 1
];
System.debug('S-1367 Case: ' + interactions);

// Tìm Case S-0424 (parent/relatedTo)
List<Case> parents = [
    SELECT Id, FEC_ID_Search__c, RecordType.DeveloperName
    FROM Case
    WHERE FEC_ID_Search__c = 'S-0424'
    LIMIT 1
];
System.debug('S-0424 Case: ' + parents);

if (!interactions.isEmpty() && !parents.isEmpty()) {
    try {
        FEC_Relevant_Ticket__c rt = new FEC_Relevant_Ticket__c();
        rt.FEC_Interaction__c = interactions[0].Id;
        rt.FEC_Related_To__c = parents[0].Id;
        insert rt;
        System.debug('Insert OK: ' + rt.Id);
    } catch(Exception e) {
        System.debug('Insert FAILED: ' + e.getMessage());
        System.debug('Stack: ' + e.getStackTraceString());
    }
}
