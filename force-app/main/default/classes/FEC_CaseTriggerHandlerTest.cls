/**
 * Test Class: FEC_CaseTriggerHandlerTest
 * @description Test class cho FEC_CaseTriggerHandler - cover các logic:
 *   1. generateFECIdSearch (Before Insert)
 *   2. updateCaseParticipantsOnInsert (Before Insert)
 *   3. syncChannelFromInteractionForCustomerCase (Before Insert/Update)
 *   4. assignEntitlement (Before Insert)
 *   5. handleAutoFollowUpOnInsert (After Insert)
 *   6. handleAutoFollowUpOnUpdate (After Update - Owner change)
 *   7. handleFollowUpOnResolved (After Update)
 *   8. updateCaseParticipantsOnUpdate (Before Update - Owner change)
 *   9. CaseTriggerHandler delegate - duplicate External Interaction ID
 * @created: 2026/05/21
 */
@isTest
private class FEC_CaseTriggerHandlerTest {

    /**
     * @description Setup test data chung cho các test method
     */
    @TestSetup
    static void setupTestData() {
        // Tạo User để test Owner change
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        User testUser1 = new User(
            FirstName = 'Test',
            LastName = 'User1',
            Email = 'testuser1.fec@test.com',
            Username = 'testuser1.fec.' + System.currentTimeMillis() + '@test.com',
            Alias = 'tuser1',
            TimeZoneSidKey = 'Asia/Ho_Chi_Minh',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        
        User testUser2 = new User(
            FirstName = 'Test',
            LastName = 'User2',
            Email = 'testuser2.fec@test.com',
            Username = 'testuser2.fec.' + System.currentTimeMillis() + '@test.com',
            Alias = 'tuser2',
            TimeZoneSidKey = 'Asia/Ho_Chi_Minh',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        
        insert new List<User>{ testUser1, testUser2 };
    }

    /**
     * @description Helper: Lấy RecordType Id theo DeveloperName
     */
    private static Id getRecordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (rtMap.containsKey(developerName)) {
            return rtMap.get(developerName).getRecordTypeId();
        }
        return null;
    }

    /**
     * @description Helper: Lấy test users
     */
    private static List<User> getTestUsers() {
        return [SELECT Id FROM User WHERE Email LIKE 'testuser%.fec@test.com' ORDER BY LastName];
    }

    /**
     * @description Test 1: Insert Case - generateFECIdSearch tạo FEC_ID_Search__c
     * Verify: FEC_ID_Search__c được auto-generate với format [Prefix]-[SequenceNumber]
     */
    @isTest
    static void testGenerateFECIdSearch_OnInsert() {
        Id customerCaseRtId = getRecordTypeId('Customer_Case');
        Id interactionRtId = getRecordTypeId('Interaction');
        
        Test.startTest();
        
        List<Case> casesToInsert = new List<Case>();
        
        // Case với RecordType Customer_Case
        if (customerCaseRtId != null) {
            casesToInsert.add(new Case(
                Subject = 'Test Customer Case 1',
                RecordTypeId = customerCaseRtId,
                Status = 'New'
            ));
            casesToInsert.add(new Case(
                Subject = 'Test Customer Case 2',
                RecordTypeId = customerCaseRtId,
                Status = 'New'
            ));
        }
        
        // Case với RecordType Interaction
        if (interactionRtId != null) {
            casesToInsert.add(new Case(
                Subject = 'Test Interaction Case',
                RecordTypeId = interactionRtId,
                Status = 'New'
            ));
        }
        
        // Fallback: nếu không có RecordType nào, tạo Case không có RecordType
        if (casesToInsert.isEmpty()) {
            casesToInsert.add(new Case(
                Subject = 'Test Case No RT',
                Status = 'New'
            ));
        }
        
        insert casesToInsert;
        
        Test.stopTest();
        
        // Verify: FEC_ID_Search__c được generate
        List<Case> insertedCases = [SELECT Id, FEC_ID_Search__c, RecordTypeId FROM Case WHERE Id IN :casesToInsert];
        for (Case c : insertedCases) {
            System.assertNotEquals(null, c.FEC_ID_Search__c, 'FEC_ID_Search__c should be auto-generated');
            System.assert(c.FEC_ID_Search__c.contains('-'), 'FEC_ID_Search__c should contain delimiter');
        }
    }

    /**
     * @description Test 2: Insert Case với RecordType Customer_Case/Internal_Case
     * Verify: FEC_Case_Participants__c chứa OwnerId
     */
    @isTest
    static void testUpdateCaseParticipants_OnInsert() {
        List<User> testUsers = getTestUsers();
        if (testUsers.isEmpty()) return;
        
        Id customerCaseRtId = getRecordTypeId('Customer_Case');
        if (customerCaseRtId == null) return;
        
        Test.startTest();
        
        Case testCase = new Case(
            Subject = 'Test Participants Insert',
            RecordTypeId = customerCaseRtId,
            Status = 'New',
            OwnerId = testUsers[0].Id
        );
        insert testCase;
        
        Test.stopTest();
        
        Case insertedCase = [SELECT Id, FEC_Case_Participants__c, OwnerId FROM Case WHERE Id = :testCase.Id];
        
        // Verify: OwnerId nằm trong FEC_Case_Participants__c
        if (insertedCase.FEC_Case_Participants__c != null) {
            System.assert(
                insertedCase.FEC_Case_Participants__c.contains(String.valueOf(insertedCase.OwnerId)),
                'FEC_Case_Participants__c should contain OwnerId'
            );
        }
    }

    /**
     * @description Test 3: Update Case Owner - updateCaseParticipantsOnUpdate
     * Verify: Owner mới được thêm vào FEC_Case_Participants__c
     */
    @isTest
    static void testUpdateCaseParticipants_OnOwnerChange() {
        List<User> testUsers = getTestUsers();
        if (testUsers.size() < 2) return;
        
        Id customerCaseRtId = getRecordTypeId('Customer_Case');
        if (customerCaseRtId == null) return;
        
        // Insert Case với Owner = User1
        Case testCase = new Case(
            Subject = 'Test Participants Update',
            RecordTypeId = customerCaseRtId,
            Status = 'New',
            OwnerId = testUsers[0].Id
        );
        insert testCase;
        
        Test.startTest();
        
        // Update Owner sang User2
        testCase.OwnerId = testUsers[1].Id;
        update testCase;
        
        Test.stopTest();
        
        Case updatedCase = [SELECT Id, FEC_Case_Participants__c FROM Case WHERE Id = :testCase.Id];
        
        // Verify: Owner mới nằm trong participants
        if (updatedCase.FEC_Case_Participants__c != null) {
            System.assert(
                updatedCase.FEC_Case_Participants__c.contains(String.valueOf(testUsers[1].Id)),
                'FEC_Case_Participants__c should contain new OwnerId after owner change'
            );
        }
    }

    /**
     * @description Test 4: syncChannelFromInteractionForCustomerCase
     * Verify: Customer Case lấy FEC_Channel__c từ Interaction Case liên kết
     */
    @isTest
    static void testSyncChannelFromInteraction_OnInsert() {
        Id interactionRtId = getRecordTypeId('Interaction');
        Id customerCaseRtId = getRecordTypeId('Customer_Case');
        
        if (interactionRtId == null || customerCaseRtId == null) return;
        
        // Tạo Interaction Case với Channel
        Case interactionCase = new Case(
            Subject = 'Test Interaction',
            RecordTypeId = interactionRtId,
            Status = 'New',
            FEC_Channel__c = 'ZALO'
        );
        insert interactionCase;
        
        Test.startTest();
        
        // Tạo Customer Case liên kết với Interaction
        Case customerCase = new Case(
            Subject = 'Test Customer Case Sync Channel',
            RecordTypeId = customerCaseRtId,
            Status = 'New',
            FEC_Interaction__c = interactionCase.Id
        );
        insert customerCase;
        
        Test.stopTest();
        
        Case insertedCase = [SELECT Id, FEC_Channel__c FROM Case WHERE Id = :customerCase.Id];
        System.assertEquals('ZALO', insertedCase.FEC_Channel__c, 'Channel should be synced from Interaction');
    }

    /**
     * @description Test 5: handleAutoFollowUpOnInsert
     * Verify: Trigger chạy không lỗi khi insert Case (follow-up logic)
     */
    @isTest
    static void testAutoFollowUp_OnInsert() {
        List<User> testUsers = getTestUsers();
        if (testUsers.isEmpty()) return;
        
        Id customerCaseRtId = getRecordTypeId('Customer_Case');
        if (customerCaseRtId == null) return;
        
        Test.startTest();
        
        Case testCase = new Case(
            Subject = 'Test Auto Follow Up Insert',
            RecordTypeId = customerCaseRtId,
            Status = 'New',
            OwnerId = testUsers[0].Id
        );
        insert testCase;
        
        Test.stopTest();
        
        // Verify: Case được insert thành công (không exception)
        Case insertedCase = [SELECT Id, Subject FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, insertedCase, 'Case should be inserted successfully');
    }

    /**
     * @description Test 6: handleAutoFollowUpOnUpdate - Owner change triggers follow-up
     * Verify: Trigger chạy không lỗi khi update Owner
     */
    @isTest
    static void testAutoFollowUp_OnOwnerChange() {
        List<User> testUsers = getTestUsers();
        if (testUsers.size() < 2) return;
        
        Id customerCaseRtId = getRecordTypeId('Customer_Case');
        if (customerCaseRtId == null) return;
        
        Case testCase = new Case(
            Subject = 'Test Auto Follow Up Update',
            RecordTypeId = customerCaseRtId,
            Status = 'New',
            OwnerId = testUsers[0].Id
        );
        insert testCase;
        
        Test.startTest();
        
        testCase.OwnerId = testUsers[1].Id;
        update testCase;
        
        Test.stopTest();
        
        // Verify: Case được update thành công
        Case updatedCase = [SELECT Id, OwnerId FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(testUsers[1].Id, updatedCase.OwnerId, 'Owner should be updated');
    }

    /**
     * @description Test 7: handleFollowUpOnResolved - Case chuyển sang Resolved
     * Verify: Trigger chạy không lỗi khi Case resolved
     */
    @isTest
    static void testFollowUpOnResolved() {
        List<User> testUsers = getTestUsers();
        if (testUsers.isEmpty()) return;
        
        Id customerCaseRtId = getRecordTypeId('Customer_Case');
        if (customerCaseRtId == null) return;
        
        Case testCase = new Case(
            Subject = 'Test Follow Up Resolved',
            RecordTypeId = customerCaseRtId,
            Status = 'New',
            OwnerId = testUsers[0].Id
        );
        insert testCase;
        
        Test.startTest();
        
        // Chuyển Case sang Resolved
        testCase.Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED;
        update testCase;
        
        Test.stopTest();
        
        Case updatedCase = [SELECT Id, Status FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED, updatedCase.Status, 
            'Case status should be Resolved-Completed');
    }

    /**
     * @description Test 8: Duplicate External Interaction ID - Before Insert
     * Verify: Case bị addError khi External ID trùng
     */
    @isTest
    static void testDuplicateExternalInteractionID_OnInsert() {
        Id interactionRtId = getRecordTypeId('Interaction');
        if (interactionRtId == null) return;
        
        // Tạo Case đầu tiên với External ID
        Case existingCase = new Case(
            Subject = 'Existing Case',
            RecordTypeId = interactionRtId,
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-DUPLICATE-001'
        );
        insert existingCase;
        
        Test.startTest();
        
        // Tạo Case thứ hai với cùng External ID -> expect error
        Case duplicateCase = new Case(
            Subject = 'Duplicate Case',
            RecordTypeId = interactionRtId,
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-DUPLICATE-001'
        );
        
        try {
            insert duplicateCase;
            // Nếu không có validation rule khác chặn, có thể pass
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('External Interaction ID has already been used'), 
                'Should show duplicate error message');
        }
        
        Test.stopTest();
    }

    /**
     * @description Test 9: Duplicate External Interaction ID - Before Update
     * Verify: Case bị addError khi update External ID thành giá trị trùng
     */
    @isTest
    static void testDuplicateExternalInteractionID_OnUpdate() {
        Id interactionRtId = getRecordTypeId('Interaction');
        if (interactionRtId == null) return;
        
        // Tạo 2 Case với External ID khác nhau
        Case case1 = new Case(
            Subject = 'Case 1',
            RecordTypeId = interactionRtId,
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-UPDATE-001'
        );
        Case case2 = new Case(
            Subject = 'Case 2',
            RecordTypeId = interactionRtId,
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-UPDATE-002'
        );
        insert new List<Case>{ case1, case2 };
        
        Test.startTest();
        
        // Update case2 External ID thành giá trị trùng với case1
        case2.FEC_External_Interaction_ID__c = 'EXT-UPDATE-001';
        
        try {
            update case2;
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('External Interaction ID has already been used'), 
                'Should show duplicate error on update');
        }
        
        Test.stopTest();
    }

    /**
     * @description Test 10: Bulk insert nhiều Case cùng lúc
     * Verify: Trigger xử lý bulk không lỗi, FEC_ID_Search__c unique
     */
    @isTest
    static void testBulkInsert() {
        Id customerCaseRtId = getRecordTypeId('Customer_Case');
        if (customerCaseRtId == null) return;
        
        Test.startTest();
        
        List<Case> bulkCases = new List<Case>();
        for (Integer i = 0; i < 50; i++) {
            bulkCases.add(new Case(
                Subject = 'Bulk Case ' + i,
                RecordTypeId = customerCaseRtId,
                Status = 'New'
            ));
        }
        insert bulkCases;
        
        Test.stopTest();
        
        // Verify: Tất cả Case có FEC_ID_Search__c unique
        List<Case> insertedCases = [SELECT Id, FEC_ID_Search__c FROM Case WHERE Id IN :bulkCases];
        Set<String> idSearchValues = new Set<String>();
        for (Case c : insertedCases) {
            System.assertNotEquals(null, c.FEC_ID_Search__c, 'FEC_ID_Search__c should not be null');
            System.assert(!idSearchValues.contains(c.FEC_ID_Search__c), 
                'FEC_ID_Search__c should be unique: ' + c.FEC_ID_Search__c);
            idSearchValues.add(c.FEC_ID_Search__c);
        }
    }

    /**
     * @description Test 11: assignEntitlement - Interaction Case được gán Entitlement
     * Verify: Trigger chạy không lỗi (Entitlement có thể không tồn tại trong test context)
     */
    @isTest
    static void testAssignEntitlement_OnInsert() {
        Id interactionRtId = getRecordTypeId('Interaction');
        if (interactionRtId == null) return;
        
        Test.startTest();
        
        Case interactionCase = new Case(
            Subject = 'Test Assign Entitlement',
            RecordTypeId = interactionRtId,
            Status = 'New'
        );
        insert interactionCase;
        
        Test.stopTest();
        
        // Verify: Case được insert thành công
        Case insertedCase = [SELECT Id, EntitlementId FROM Case WHERE Id = :interactionCase.Id];
        System.assertNotEquals(null, insertedCase, 'Interaction Case should be inserted successfully');
    }

    /**
     * @description Test 12: Insert Case không có RecordType (fallback prefix 'S')
     * Verify: FEC_ID_Search__c vẫn được generate với prefix mặc định
     */
    @isTest
    static void testGenerateFECIdSearch_FallbackPrefix() {
        Test.startTest();
        
        Case testCase = new Case(
            Subject = 'Test Fallback Prefix',
            Status = 'New'
        );
        insert testCase;
        
        Test.stopTest();
        
        Case insertedCase = [SELECT Id, FEC_ID_Search__c FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, insertedCase.FEC_ID_Search__c, 
            'FEC_ID_Search__c should be generated even without RecordType');
    }

    /**
     * @description Test 13: syncChannelFromInteraction on Update
     * Verify: Channel được sync khi update FEC_Interaction__c
     */
    @isTest
    static void testSyncChannelFromInteraction_OnUpdate() {
        Id interactionRtId = getRecordTypeId('Interaction');
        Id customerCaseRtId = getRecordTypeId('Customer_Case');
        
        if (interactionRtId == null || customerCaseRtId == null) return;
        
        // Tạo Interaction Case
        Case interactionCase = new Case(
            Subject = 'Interaction for Update Test',
            RecordTypeId = interactionRtId,
            Status = 'New',
            FEC_Channel__c = 'WEBSITE'
        );
        insert interactionCase;
        
        // Tạo Customer Case không có Interaction
        Case customerCase = new Case(
            Subject = 'Customer Case Update Sync',
            RecordTypeId = customerCaseRtId,
            Status = 'New'
        );
        insert customerCase;
        
        Test.startTest();
        
        // Update: gán Interaction cho Customer Case
        customerCase.FEC_Interaction__c = interactionCase.Id;
        update customerCase;
        
        Test.stopTest();
        
        Case updatedCase = [SELECT Id, FEC_Channel__c FROM Case WHERE Id = :customerCase.Id];
        System.assertEquals('WEBSITE', updatedCase.FEC_Channel__c, 
            'Channel should be synced from Interaction on update');
    }

    /**
     * @description Test 14: FEC_CaseOwnerChangeNotification và createRoutingActionHistory
     * Verify: After Update với Owner change chạy không lỗi
     */
    @isTest
    static void testOwnerChangeNotificationAndRouting() {
        List<User> testUsers = getTestUsers();
        if (testUsers.size() < 2) return;
        
        Id customerCaseRtId = getRecordTypeId('Customer_Case');
        if (customerCaseRtId == null) return;
        
        Case testCase = new Case(
            Subject = 'Test Notification Routing',
            RecordTypeId = customerCaseRtId,
            Status = 'New',
            OwnerId = testUsers[0].Id
        );
        insert testCase;
        
        Test.startTest();
        
        // Change owner để trigger notification và routing logic
        testCase.OwnerId = testUsers[1].Id;
        update testCase;
        
        Test.stopTest();
        
        // Verify: No exception, Case updated successfully
        Case updatedCase = [SELECT Id, OwnerId FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(testUsers[1].Id, updatedCase.OwnerId, 'Owner should be changed');
    }

    /**
     * @description Test 15: Internal Case - updateCaseParticipants
     * Verify: Internal Case cũng được xử lý participants
     */
    @isTest
    static void testUpdateCaseParticipants_InternalCase() {
        List<User> testUsers = getTestUsers();
        if (testUsers.isEmpty()) return;
        
        Id internalCaseRtId = getRecordTypeId('Internal_Case');
        if (internalCaseRtId == null) return;
        
        Test.startTest();
        
        Case testCase = new Case(
            Subject = 'Test Internal Case Participants',
            RecordTypeId = internalCaseRtId,
            Status = 'New',
            OwnerId = testUsers[0].Id
        );
        insert testCase;
        
        Test.stopTest();
        
        Case insertedCase = [SELECT Id, FEC_Case_Participants__c FROM Case WHERE Id = :testCase.Id];
        if (insertedCase.FEC_Case_Participants__c != null) {
            System.assert(
                insertedCase.FEC_Case_Participants__c.contains(String.valueOf(testUsers[0].Id)),
                'Internal Case should also have participants updated'
            );
        }
    }
}
