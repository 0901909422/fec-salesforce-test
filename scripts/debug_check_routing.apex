// Tìm case COF/GSR có FEC_Actual_Nature_of_Case__c
List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Actual_Nature_of_Case__c, FEC_Is_Submited__c
    FROM Case
    WHERE FEC_Actual_Nature_of_Case__c != null
    ORDER BY CreatedDate DESC LIMIT 5
];
for (Case c : cases) {
    System.debug('Case=' + c.CaseNumber + ' Id=' + c.Id + ' ActualNOC=' + c.FEC_Actual_Nature_of_Case__c + ' Submitted=' + c.FEC_Is_Submited__c);
}

// Check FEC_Routing_Assignment__c hiện có
List<FEC_Routing_Assignment__c> ras = [SELECT Id, FEC_Nature_of_Cases__c, FEC_Team__c, FEC_Queue__c FROM FEC_Routing_Assignment__c LIMIT 10];
for (FEC_Routing_Assignment__c ra : ras) {
    System.debug('RA Id=' + ra.Id + ' NOC=' + ra.FEC_Nature_of_Cases__c + ' Team=' + ra.FEC_Team__c + ' Queue=' + ra.FEC_Queue__c);
}

// Check FEC_Nature_of_Case__c có FEC_Routing_Assignment__c
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, FEC_Active__c, FEC_Business_Process__r.FEC_Code__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Business_Process__r.FEC_Code__c LIKE 'COF%'
       OR FEC_Business_Process__r.FEC_Code__c LIKE 'GSR%'
    LIMIT 10
];
for (FEC_Nature_of_Case__c n : nocs) {
    List<FEC_Routing_Assignment__c> nocRas = [SELECT Id, FEC_Team__c, FEC_Queue__c FROM FEC_Routing_Assignment__c WHERE FEC_Nature_of_Cases__c = :n.Id];
    System.debug('NOC Id=' + n.Id + ' Active=' + n.FEC_Active__c + ' BP=' + n.FEC_Business_Process__r?.FEC_Code__c + ' RAs=' + nocRas.size());
}
