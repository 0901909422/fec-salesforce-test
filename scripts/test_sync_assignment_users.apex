// ============================================================
// TEST: syncAssignmentUsersToCase
// Rule: FEC_Assignment_Users__c = FEC_Assignment_Owner__c nếu có
//       nếu null → lấy Queue Id từ FEC_OwnerID__c
// ============================================================

System.debug('=== TEST syncAssignmentUsersToCase ===');

// ---- TEST 1: Chuyển assignment sang USER ----
// Tìm assignment OPEN đang ở queue (Owner = null)
List<FEC_Assignment__c> queueAssign = [
    SELECT Id, FEC_Case__c, FEC_Assignment_Owner__c, FEC_OwnerID__c
    FROM FEC_Assignment__c
    WHERE FEC_Assignment_Owner__c = null
      AND FEC_OwnerID__c != null
      AND FEC_Assignment_Status__c = 'Open'
    ORDER BY LastModifiedDate DESC
    LIMIT 1
];

if (!queueAssign.isEmpty()) {
    FEC_Assignment__c a = queueAssign[0];
    Id caseId = a.FEC_Case__c;

    // Lấy 1 user bất kỳ để transfer sang
    User targetUser = [SELECT Id FROM User WHERE IsActive = true AND Id != :UserInfo.getUserId() LIMIT 1];

    Case cBefore = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :caseId LIMIT 1];
    System.debug('--- Test 1: Transfer Queue → User ---');
    System.debug('Assignment Id          : ' + a.Id);
    System.debug('Case Id                : ' + caseId);
    System.debug('Target User Id         : ' + targetUser.Id);
    System.debug('BEFORE FEC_Assignment_Users__c : ' + cBefore.FEC_Assignment_Users__c);

    try {
        FEC_AssignmentRoutingActionHandler.execute(
            caseId,
            a.Id,
            'Transfer',           // action
            'Test remark user',   // remark
            'USER',               // decision = USER (phải all caps)
            String.valueOf(targetUser.Id) // subDecision = userId
        );
    } catch (Exception e) {
        System.debug('Transfer error: ' + e.getMessage());
    }

    Case cAfter = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :caseId LIMIT 1];
    FEC_Assignment__c aAfter = [SELECT Id, FEC_Assignment_Owner__c, FEC_OwnerID__c FROM FEC_Assignment__c WHERE Id = :a.Id LIMIT 1];
    System.debug('AFTER FEC_Assignment_Owner__c  : ' + aAfter.FEC_Assignment_Owner__c);
    System.debug('AFTER FEC_Assignment_Users__c  : ' + cAfter.FEC_Assignment_Users__c);
    Boolean pass = cAfter.FEC_Assignment_Users__c == String.valueOf(targetUser.Id);
    System.debug('>>> PASS: ' + pass + ' (expected: ' + targetUser.Id + ')');
} else {
    System.debug('Test 1: Không tìm thấy assignment Queue OPEN nào');
}

System.debug('');

// ---- TEST 2: Chuyển assignment từ User về QUEUE ----
List<FEC_Assignment__c> userAssign = [
    SELECT Id, FEC_Case__c, FEC_Assignment_Owner__c, FEC_OwnerID__c
    FROM FEC_Assignment__c
    WHERE FEC_Assignment_Owner__c != null
      AND FEC_Assignment_Status__c = 'Open'
    ORDER BY LastModifiedDate DESC
    LIMIT 1
];

if (!userAssign.isEmpty()) {
    FEC_Assignment__c a = userAssign[0];
    Id caseId = a.FEC_Case__c;

    // Tìm queue id từ FEC_OwnerID__c
    String queueIdStr = null;
    try {
        Id qid = (Id) a.FEC_OwnerID__c;
        queueIdStr = String.valueOf(qid);
    } catch (Exception ex) {
        List<Group> grps = [SELECT Id FROM Group WHERE Name = :a.FEC_OwnerID__c AND Type = 'Queue' LIMIT 1];
        if (!grps.isEmpty()) queueIdStr = String.valueOf(grps[0].Id);
    }

    Case cBefore = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :caseId LIMIT 1];
    System.debug('--- Test 2: Transfer User → Queue ---');
    System.debug('Assignment Id          : ' + a.Id);
    System.debug('Case Id                : ' + caseId);
    System.debug('Queue Id from OwnerID  : ' + queueIdStr);
    System.debug('BEFORE FEC_Assignment_Users__c : ' + cBefore.FEC_Assignment_Users__c);

    try {
        FEC_AssignmentRoutingActionHandler.execute(
            caseId,
            a.Id,
            'Transfer',
            'Test remark queue',
            'QUEUE',              // decision = QUEUE
            queueIdStr            // subDecision = queue id
        );
    } catch (Exception e) {
        System.debug('Transfer error: ' + e.getMessage());
    }

    Case cAfter = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :caseId LIMIT 1];
    FEC_Assignment__c aAfter = [SELECT Id, FEC_Assignment_Owner__c, FEC_OwnerID__c FROM FEC_Assignment__c WHERE Id = :a.Id LIMIT 1];
    System.debug('AFTER FEC_Assignment_Owner__c  : ' + aAfter.FEC_Assignment_Owner__c);
    System.debug('AFTER FEC_Assignment_Users__c  : ' + cAfter.FEC_Assignment_Users__c);
    Boolean pass = cAfter.FEC_Assignment_Users__c == queueIdStr;
    System.debug('>>> PASS: ' + pass + ' (expected: ' + queueIdStr + ')');
} else {
    System.debug('Test 2: Không tìm thấy assignment User OPEN nào');
}
