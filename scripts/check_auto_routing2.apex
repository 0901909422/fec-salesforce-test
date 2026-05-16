// Tìm case COF/GSR qua Actual NOC
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Assignment_Users__c, OwnerId, Owner.Name, Owner.Type,
           FEC_Service_Case_Owner__c, FEC_Business_Process__c,
           FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c
    FROM Case
    WHERE FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c LIKE 'COF%'
      AND FEC_Is_Submited__c = true
    ORDER BY LastModifiedDate DESC LIMIT 5
];
System.debug('Found: ' + cases.size());
for (Case c : cases) {
    System.debug('Case=' + c.FEC_ID_Search__c
        + ' BP_direct=' + c.FEC_Business_Process__c
        + ' BP_via_NOC=' + c.FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c
        + ' OwnerType=' + c.Owner?.Type
        + ' AssignUsers=[' + c.FEC_Assignment_Users__c + ']'
        + ' ServiceOwner=[' + c.FEC_Service_Case_Owner__c + ']');
}
