// Test fix Flow FEC_Assignment_Set_User_Role trên QA01
// Tạo Assignment mới với FEC_User_Role__c đã set từ Apex → Flow không được override

String caseId = '5008500000HvjJbAAJ'; // S-3073

// Lấy NOC của case
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Product_Type__c, FEC_Category__c,
           FEC_SubCategory__c, FEC_SubCode__c, FEC_Stage_Name__c
    FROM Case WHERE Id = :caseId LIMIT 1
];
if (cases.isEmpty()) { System.debug('Case not found'); return; }
Case c = cases[0];
System.debug('Case: ' + c.FEC_ID_Search__c + ' | Stage: ' + c.FEC_Stage_Name__c);

// Tạo Assignment với FEC_User_Role__c đã set
User currentUser = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
System.debug('Running as: ' + currentUser.Email + ' | Role: ' + currentUser.UserRole?.Name);

FEC_Assignment__c testAssignment = new FEC_Assignment__c(
    FEC_Case__c = caseId,
    FEC_Assignment_Type__c = 'Routing',
    FEC_Assignment_Status__c = 'Open',
    FEC_Assignment_Name__c = 'Routing',
    FEC_OwnerID__c = 'DQ - CS Support',
    FEC_User_Role__c = currentUser.UserRole?.Name,  // Set từ Apex
    FEC_Manual__c = false
);
insert testAssignment;

// Verify sau insert - Flow có override không?
FEC_Assignment__c result = [
    SELECT Id, Name, FEC_User_Role__c, CreatedBy.UserRole.Name
    FROM FEC_Assignment__c WHERE Id = :testAssignment.Id LIMIT 1
];
System.debug('=== RESULT ===');
System.debug('Assignment: ' + result.Name);
System.debug('FEC_User_Role__c = ' + result.FEC_User_Role__c);
System.debug('CreatedBy.UserRole.Name = ' + result.CreatedBy?.UserRole?.Name);

Boolean pass = result.FEC_User_Role__c == currentUser.UserRole?.Name;
System.debug(pass ? '✓ PASS - UserRole preserved' : '✗ FAIL - UserRole overridden to: ' + result.FEC_User_Role__c);
