// Debug: thử insert với S-0290 làm Interaction, S-0424 làm RelatedTo
List<Case> interaction = [SELECT Id, FEC_ID_Search__c, RecordType.DeveloperName, OwnerId FROM Case WHERE FEC_ID_Search__c = 'S-0290' LIMIT 1];
List<Case> relatedTo  = [SELECT Id, FEC_ID_Search__c FROM Case WHERE FEC_ID_Search__c = 'S-0424' LIMIT 1];

System.debug('Interaction (S-0290): ' + interaction);
System.debug('RelatedTo  (S-0424): ' + relatedTo);

if (!interaction.isEmpty() && !relatedTo.isEmpty()) {
    try {
        FEC_Relevant_Ticket__c rt = new FEC_Relevant_Ticket__c(
            FEC_Interaction__c = interaction[0].Id,
            FEC_Related_To__c  = relatedTo[0].Id
        );
        insert rt;
        System.debug('SUCCESS: ' + rt.Id);
    } catch(Exception e) {
        System.debug('FAILED: ' + e.getMessage());
        System.debug('Type: ' + e.getTypeName());
    }
}
