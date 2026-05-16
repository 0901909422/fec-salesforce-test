// tungnm37: Check trạng thái qa01 cho COF/GSR

// 1. Check FEC_CofGsrAssignmentService có tồn tại không
Type t = Type.forName('FEC_CofGsrAssignmentService');
System.debug('FEC_CofGsrAssignmentService exists: ' + (t != null));

// 2. Check FEC_ConstantCommon có ASSIGNMENT_NAME_ROUTING không
System.debug('ASSIGNMENT_NAME_ROUTING: ' + FEC_ConstantCommon.ASSIGNMENT_NAME_ROUTING);

// 3. Check Routing Assignments
List<FEC_Routing_Assignment__c> allRAs = [
    SELECT FEC_Team__c, FEC_Queue__c,
           FEC_Nature_of_Cases__r.FEC_Product_Type__r.Name,
           FEC_Nature_of_Cases__r.FEC_Business_Process__r.FEC_Code__c
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Team__c != null AND FEC_Queue__c != null
    LIMIT 20
];
System.debug('Total RAs: ' + allRAs.size());
for (FEC_Routing_Assignment__c ra : allRAs) {
    System.debug('RA: Team=' + ra.FEC_Team__c + ' | Queue=' + ra.FEC_Queue__c
        + ' | PT=' + ra.FEC_Nature_of_Cases__r?.FEC_Product_Type__r?.Name
        + ' | BP=' + ra.FEC_Nature_of_Cases__r?.FEC_Business_Process__r?.FEC_Code__c);
}

// 4. Check Case S-2303
List<Case> cases = [
    SELECT Id, CaseNumber, Status, OwnerId, Owner.Name, Owner.Type,
           FEC_Product_Type__r.Name, FEC_Actual_Nature_of_Case__c,
           FEC_Current_Case_Stage__c
    FROM Case WHERE CaseNumber = 'S-2303' LIMIT 1
];
if (!cases.isEmpty()) {
    Case c = cases[0];
    System.debug('Case S-2303: Id=' + c.Id + ' | Status=' + c.Status
        + ' | Owner=' + c.Owner?.Name + ' | OwnerType=' + c.Owner?.Type
        + ' | PT=' + c.FEC_Product_Type__r?.Name);
    
    // Check assignments của case này
    Integer aCount = [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id];
    System.debug('Assignments on S-2303: ' + aCount);
    
    // Check routing history
    Integer hCount = [SELECT COUNT() FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c.Id];
    System.debug('Routing Histories on S-2303: ' + hCount);
}

// 5. Check Custom Labels
System.debug('FEC_CC_Queue_Name label: ' + System.Label.FEC_CC_Queue_Name);
System.debug('FEC_CS_Support_Queue_Name label: ' + System.Label.FEC_CS_Support_Queue_Name);
