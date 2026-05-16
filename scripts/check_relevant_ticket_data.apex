// Check relevant ticket data - xem field nào có giá trị
List<FEC_Relevant_Ticket__c> rts = [
    SELECT Id, Name,
           FEC_Interaction__c, FEC_Interaction__r.CaseNumber, FEC_Interaction__r.FEC_Account_or_Contract__c,
           FEC_Related_To__c, FEC_Related_To__r.CaseNumber, FEC_Related_To__r.FEC_Account_or_Contract__c,
           FEC_Account_or_Contract_Revelant__c,
           FEC_Account_Contract_Number__c
    FROM FEC_Relevant_Ticket__c
    ORDER BY CreatedDate DESC LIMIT 5
];
for (FEC_Relevant_Ticket__c rt : rts) {
    System.debug('--- RT: ' + rt.Name);
    System.debug('  Interaction (master): ' + rt.FEC_Interaction__r?.CaseNumber + ' | AccContract: ' + rt.FEC_Interaction__r?.FEC_Account_or_Contract__c);
    System.debug('  RelatedTo (lookup):   ' + rt.FEC_Related_To__r?.CaseNumber + ' | AccContract: ' + rt.FEC_Related_To__r?.FEC_Account_or_Contract__c);
    System.debug('  Formula field (FEC_Account_or_Contract_Revelant__c): ' + rt.FEC_Account_or_Contract_Revelant__c);
    System.debug('  Text field (FEC_Account_Contract_Number__c): ' + rt.FEC_Account_Contract_Number__c);
}
