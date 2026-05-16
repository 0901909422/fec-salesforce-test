// Check case COF/GSR mới nhất xem FEC_Assignment_Users__c có prefix AUTO: không
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Assignment_Users__c, FEC_Service_Case_Owner__c,
           FEC_Is_Submited__c, Owner.Name, Owner.Type
    FROM Case
    WHERE FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c LIKE 'COF%'
      AND FEC_Is_Submited__c = true
    ORDER BY LastModifiedDate DESC LIMIT 5
];
for (Case c : cases) {
    Boolean hasAutoPrefix = String.isNotBlank(c.FEC_Assignment_Users__c) && c.FEC_Assignment_Users__c.startsWith('AUTO:');
    System.debug('Case=' + c.FEC_ID_Search__c
        + ' AssignUsers=[' + c.FEC_Assignment_Users__c + ']'
        + ' HasAutoPrefix=' + hasAutoPrefix
        + ' ServiceOwner=[' + c.FEC_Service_Case_Owner__c + ']'
        + ' OwnerType=' + c.Owner?.Type);
}
