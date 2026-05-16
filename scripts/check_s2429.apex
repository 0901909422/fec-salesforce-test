List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Assignment_Count__c,
           FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c,
           FEC_Service_Case_Owner__c, OwnerId, Owner.Name, Owner.Type
    FROM Case WHERE FEC_ID_Search__c = 'S-2429' LIMIT 1
];
if (cases.isEmpty()) { System.debug('Case not found'); return; }
Case c = cases[0];
System.debug('BPId=' + c.FEC_Business_Process__c);
System.debug('BPCode=' + c.FEC_Business_Process__r?.FEC_Code__c);
System.debug('AssignmentCount=' + c.FEC_Assignment_Count__c);
System.debug('ServiceCaseOwner=[' + c.FEC_Service_Case_Owner__c + ']');
System.debug('OwnerId=' + c.OwnerId + ' OwnerName=' + c.Owner?.Name + ' OwnerType=' + c.Owner?.Type);
