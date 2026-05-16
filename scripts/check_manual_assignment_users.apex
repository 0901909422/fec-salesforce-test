// Check case có Assignment thủ công nhưng FEC_Assignment_Users__c trống
// Lấy case mới nhất có assignment thủ công
List<FEC_Assignment__c> manualAssignments = [
    SELECT Id, Name, FEC_Case__c, FEC_Case__r.FEC_ID_Search__c,
           FEC_Case__r.FEC_Assignment_Users__c,
           FEC_Case__r.FEC_Stage_Name__c,
           FEC_OwnerID__c, FEC_Manual__c, FEC_Assignment_Routing_Action__c
    FROM FEC_Assignment__c
    WHERE FEC_Manual__c = true
    ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('=== MANUAL ASSIGNMENTS ===');
for (FEC_Assignment__c a : manualAssignments) {
    System.debug(a.Name + ' | Case=' + a.FEC_Case__r?.FEC_ID_Search__c
        + ' | OwnerID=' + a.FEC_OwnerID__c
        + ' | RoutingAction=' + a.FEC_Assignment_Routing_Action__c
        + ' | FEC_Assignment_Users__c=' + a.FEC_Case__r?.FEC_Assignment_Users__c
        + ' | StageName=' + a.FEC_Case__r?.FEC_Stage_Name__c);
    
    // Check isStage1 logic
    String stageName = a.FEC_Assignment_Routing_Action__c;
    Boolean isStage1 = stageName != null && Pattern.matches('(?i).*stage\\s*1.*', stageName);
    System.debug('  isStage1=' + isStage1 + ' (from FEC_Assignment_Routing_Action__c)');
}
