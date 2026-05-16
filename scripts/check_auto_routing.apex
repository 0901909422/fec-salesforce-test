// Tìm case COF/GSR auto routing (owner là Queue, có assignment auto)
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Assignment_Users__c, OwnerId, Owner.Name, Owner.Type,
           FEC_Service_Case_Owner__c, FEC_Business_Process__r.FEC_Code__c
    FROM Case
    WHERE FEC_Business_Process__r.FEC_Code__c LIKE 'COF%'
      AND FEC_Is_Submited__c = true
    ORDER BY LastModifiedDate DESC LIMIT 5
];
for (Case c : cases) {
    System.debug('Case=' + c.FEC_ID_Search__c
        + ' BP=' + c.FEC_Business_Process__r?.FEC_Code__c
        + ' OwnerType=' + c.Owner?.Type
        + ' OwnerName=' + c.Owner?.Name
        + ' AssignUsers=[' + c.FEC_Assignment_Users__c + ']'
        + ' ServiceOwner=[' + c.FEC_Service_Case_Owner__c + ']');
    List<FEC_Assignment__c> autos = [SELECT Id FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id AND FEC_Manual__c = false LIMIT 1];
    System.debug('  HasAutoAssignment=' + !autos.isEmpty());
}
