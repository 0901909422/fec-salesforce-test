// Restore FEC_Send_To__c về tsalesforce63@gmail.com cho case 00002165
Case c = new Case(
    Id = '500Az00000NHCxFIAX',
    FEC_Send_To__c = 'tsalesforce63@gmail.com',
    FEC_Interaction_Email__c = 'minhtung2108@gmail.com'
);
update c;
System.debug('✅ Restored case 00002165');
Case verify = [SELECT FEC_Send_To__c, FEC_Interaction_Email__c FROM Case WHERE Id = '500Az00000NHCxFIAX'];
System.debug('SendTo: ' + verify.FEC_Send_To__c + ' | InteractionEmail: ' + verify.FEC_Interaction_Email__c);
