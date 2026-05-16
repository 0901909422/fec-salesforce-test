// Check Assignment A-000025 fields
List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_User__c, FEC_User_Role__c, FEC_OwnerID__c, FEC_Assignment_Owner__c,
           FEC_Team__c, FEC_Assignment_Status__c, CreatedById, CreatedBy.Email
    FROM FEC_Assignment__c ORDER BY CreatedDate DESC LIMIT 3
];
for (FEC_Assignment__c a : assignments) {
    System.debug('Assignment=' + a.Name + ' User(formula)=' + a.FEC_User__c + ' UserRole=' + a.FEC_User_Role__c + ' OwnerID=' + a.FEC_OwnerID__c + ' AssignmentOwner=' + a.FEC_Assignment_Owner__c + ' CreatedBy=' + a.CreatedBy?.Email);
}

// Check Case Remarks
List<FEC_Case_Remarks__c> remarks = [
    SELECT Id, Remark_Type__c, FEC_User__c, FEC_Assignment__c, FEC_Stage_Name__c, CreatedDate
    FROM FEC_Case_Remarks__c ORDER BY CreatedDate DESC LIMIT 5
];
for (FEC_Case_Remarks__c r : remarks) {
    System.debug('Remark Id=' + r.Id + ' Type=' + r.Remark_Type__c + ' User=' + r.FEC_User__c + ' Assignment=' + r.FEC_Assignment__c + ' Stage=' + r.FEC_Stage_Name__c);
}
