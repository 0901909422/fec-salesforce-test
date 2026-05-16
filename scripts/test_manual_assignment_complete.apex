// Test complete: Tạo case mới và test manual assignment flow

System.debug('=== CREATE TEST CASE ===');
Case testCase = new Case(
    Subject = 'Test Manual Assignment Flow',
    Status = 'Open',
    Origin = 'Phone'
);
insert testCase;

System.debug('Case created: ' + testCase.Id);

// Query lại để lấy FEC_Assignment_Users__c
testCase = [SELECT Id, CaseNumber, FEC_Assignment_Users__c FROM Case WHERE Id = :testCase.Id];
System.debug('Case Number: ' + testCase.CaseNumber);
System.debug('FEC_Assignment_Users__c INITIAL: ' + testCase.FEC_Assignment_Users__c);

// Test 1: Tạo General assignment (không có FEC_Manual__c)
System.debug('');
System.debug('=== TEST 1: CREATE GENERAL ASSIGNMENT ===');
FEC_Assignment__c generalAssignment = new FEC_Assignment__c(
    FEC_Case__c = testCase.Id,
    FEC_Assignment_Name__c = 'Test General',
    FEC_Assignment_Type__c = 'General',
    FEC_Assignment_Status__c = 'Open'
);
insert generalAssignment;
System.debug('Created General assignment: ' + generalAssignment.Id);

Case cAfterGeneral = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :testCase.Id];
System.debug('FEC_Assignment_Users__c after General: ' + cAfterGeneral.FEC_Assignment_Users__c);
System.debug('Expected: null (no change)');

// Test 2: Update owner của General assignment
System.debug('');
System.debug('=== TEST 2: UPDATE GENERAL ASSIGNMENT OWNER ===');
generalAssignment.FEC_Assignment_Owner__c = UserInfo.getUserId();
update generalAssignment;
System.debug('Updated General assignment owner');

Case cAfterGeneralUpdate = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :testCase.Id];
System.debug('FEC_Assignment_Users__c after update: ' + cAfterGeneralUpdate.FEC_Assignment_Users__c);
System.debug('Expected: null (no change)');

// Test 3: Tạo Routing assignment với FEC_Manual__c = true
System.debug('');
System.debug('=== TEST 3: CREATE MANUAL ROUTING ASSIGNMENT ===');
FEC_Assignment__c manualRoutingAssignment = new FEC_Assignment__c(
    FEC_Case__c = testCase.Id,
    FEC_Assignment_Name__c = 'Routing',
    FEC_Assignment_Type__c = 'Routing',
    FEC_Assignment_Status__c = 'Open',
    FEC_Manual__c = true,
    FEC_OwnerID__c = 'FEC_CS_Card_Risk_Monitoring_Specialist'
);
insert manualRoutingAssignment;
System.debug('Created Manual Routing assignment: ' + manualRoutingAssignment.Id);

Case cAfterManualRouting = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :testCase.Id];
System.debug('FEC_Assignment_Users__c after manual routing: ' + cAfterManualRouting.FEC_Assignment_Users__c);
System.debug('Expected: null (manual routing should not trigger)');

// Test 4: Update owner của Manual Routing assignment
System.debug('');
System.debug('=== TEST 4: UPDATE MANUAL ROUTING ASSIGNMENT OWNER ===');
manualRoutingAssignment.FEC_Assignment_Owner__c = UserInfo.getUserId();
update manualRoutingAssignment;
System.debug('Updated Manual Routing assignment owner');

Case cAfterManualRoutingUpdate = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :testCase.Id];
System.debug('FEC_Assignment_Users__c after manual routing update: ' + cAfterManualRoutingUpdate.FEC_Assignment_Users__c);
System.debug('Expected: null (manual routing should not trigger)');

// Test 5: Tạo Auto Routing assignment (FEC_Manual__c = false hoặc null)
System.debug('');
System.debug('=== TEST 5: CREATE AUTO ROUTING ASSIGNMENT ===');
FEC_Assignment__c autoRoutingAssignment = new FEC_Assignment__c(
    FEC_Case__c = testCase.Id,
    FEC_Assignment_Name__c = 'Routing',
    FEC_Assignment_Type__c = 'Routing',
    FEC_Assignment_Status__c = 'Open',
    FEC_Manual__c = false,
    FEC_OwnerID__c = 'FEC_CS_Card_Risk_Monitoring_Specialist'
);
insert autoRoutingAssignment;
System.debug('Created Auto Routing assignment: ' + autoRoutingAssignment.Id);

Case cAfterAutoRouting = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :testCase.Id];
System.debug('FEC_Assignment_Users__c after auto routing: ' + cAfterAutoRouting.FEC_Assignment_Users__c);
System.debug('Expected: Queue ID (auto routing should trigger)');

// Test 6: Update owner của Auto Routing assignment
System.debug('');
System.debug('=== TEST 6: UPDATE AUTO ROUTING ASSIGNMENT OWNER ===');
autoRoutingAssignment.FEC_Assignment_Owner__c = UserInfo.getUserId();
update autoRoutingAssignment;
System.debug('Updated Auto Routing assignment owner');

Case cAfterAutoRoutingUpdate = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :testCase.Id];
System.debug('FEC_Assignment_Users__c after auto routing update: ' + cAfterAutoRoutingUpdate.FEC_Assignment_Users__c);
System.debug('Expected: User ID (auto routing should trigger)');

// Summary
System.debug('');
System.debug('=== TEST SUMMARY ===');
System.debug('Test 1 - General create: ' + (cAfterGeneral.FEC_Assignment_Users__c == null ? 'PASS' : 'FAIL'));
System.debug('Test 2 - General update: ' + (cAfterGeneralUpdate.FEC_Assignment_Users__c == null ? 'PASS' : 'FAIL'));
System.debug('Test 3 - Manual Routing create: ' + (cAfterManualRouting.FEC_Assignment_Users__c == null ? 'PASS' : 'FAIL'));
System.debug('Test 4 - Manual Routing update: ' + (cAfterManualRoutingUpdate.FEC_Assignment_Users__c == null ? 'PASS' : 'FAIL'));
System.debug('Test 5 - Auto Routing create: ' + (cAfterAutoRouting.FEC_Assignment_Users__c != null ? 'PASS' : 'FAIL'));
System.debug('Test 6 - Auto Routing update: ' + (cAfterAutoRoutingUpdate.FEC_Assignment_Users__c != null ? 'PASS' : 'FAIL'));

// Cleanup
System.debug('');
System.debug('=== CLEANUP ===');
delete testCase;
System.debug('Test completed and cleaned up');
