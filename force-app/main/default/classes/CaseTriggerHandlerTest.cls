/**
 * Test Class: CaseTriggerHandlerTest
 * @description Test class cho CaseTriggerHandler - kiểm tra logic duplicate External Interaction ID
 * Covers:
 *   1. onBeforeInsert - detect duplicate External ID khi insert
 *   2. onBeforeUpdate - detect duplicate External ID khi update
 *   3. Bulk insert/update scenarios
 *   4. Case không có External ID (no-op path)
 *   5. Case có External ID unique (happy path)
 * @created: 2026/05/21
 */
@isTest
private class CaseTriggerHandlerTest {

    /**
     * @description Helper: Lấy RecordType Id cho Interaction
     */
    private static Id getInteractionRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (rtMap.containsKey('Interaction')) {
            return rtMap.get('Interaction').getRecordTypeId();
        }
        return null;
    }

    /**
     * @description Test 1: Insert Case với External ID unique - không lỗi
     */
    @isTest
    static void testInsert_UniqueExternalID_Success() {
        Id rtId = getInteractionRecordTypeId();

        Case c1 = new Case(
            Subject = 'Case Unique 1',
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-UNIQUE-001'
        );
        if (rtId != null) c1.RecordTypeId = rtId;

        Case c2 = new Case(
            Subject = 'Case Unique 2',
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-UNIQUE-002'
        );
        if (rtId != null) c2.RecordTypeId = rtId;

        Test.startTest();
        insert new List<Case>{ c1, c2 };
        Test.stopTest();

        // Verify: cả 2 Case được insert thành công
        List<Case> inserted = [SELECT Id, FEC_External_Interaction_ID__c FROM Case WHERE Id IN :new List<Id>{ c1.Id, c2.Id }];
        System.assertEquals(2, inserted.size(), 'Both cases should be inserted successfully');
    }

    /**
     * @description Test 2: Insert Case với External ID trùng với Case đã tồn tại - expect error
     */
    @isTest
    static void testInsert_DuplicateExternalID_Error() {
        Id rtId = getInteractionRecordTypeId();

        // Tạo Case đầu tiên
        Case existingCase = new Case(
            Subject = 'Existing Case',
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-DUP-INSERT-001'
        );
        if (rtId != null) existingCase.RecordTypeId = rtId;
        insert existingCase;

        // Tạo Case thứ hai với cùng External ID
        Case duplicateCase = new Case(
            Subject = 'Duplicate Case',
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-DUP-INSERT-001'
        );
        if (rtId != null) duplicateCase.RecordTypeId = rtId;

        Test.startTest();

        Boolean hasError = false;
        try {
            insert duplicateCase;
        } catch (DmlException e) {
            hasError = true;
            System.assert(e.getMessage().contains('External Interaction ID has already been used'),
                'Error message should indicate duplicate External ID. Got: ' + e.getMessage());
        }

        Test.stopTest();

        System.assert(hasError, 'DmlException should be thrown for duplicate External Interaction ID');
    }

    /**
     * @description Test 3: Update Case External ID thành giá trị trùng - expect error
     */
    @isTest
    static void testUpdate_DuplicateExternalID_Error() {
        Id rtId = getInteractionRecordTypeId();

        Case case1 = new Case(
            Subject = 'Case 1',
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-UPD-001'
        );
        if (rtId != null) case1.RecordTypeId = rtId;

        Case case2 = new Case(
            Subject = 'Case 2',
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-UPD-002'
        );
        if (rtId != null) case2.RecordTypeId = rtId;

        insert new List<Case>{ case1, case2 };

        Test.startTest();

        // Update case2 External ID thành giá trị trùng với case1
        case2.FEC_External_Interaction_ID__c = 'EXT-UPD-001';

        Boolean hasError = false;
        try {
            update case2;
        } catch (DmlException e) {
            hasError = true;
            System.assert(e.getMessage().contains('External Interaction ID has already been used'),
                'Error message should indicate duplicate on update. Got: ' + e.getMessage());
        }

        Test.stopTest();

        System.assert(hasError, 'DmlException should be thrown for duplicate External ID on update');
    }

    /**
     * @description Test 4: Update Case External ID thành giá trị unique - không lỗi
     */
    @isTest
    static void testUpdate_UniqueExternalID_Success() {
        Id rtId = getInteractionRecordTypeId();

        Case case1 = new Case(
            Subject = 'Case Update Unique',
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-ORIG-001'
        );
        if (rtId != null) case1.RecordTypeId = rtId;
        insert case1;

        Test.startTest();

        // Update sang giá trị mới unique
        case1.FEC_External_Interaction_ID__c = 'EXT-NEW-UNIQUE-001';
        update case1;

        Test.stopTest();

        Case updated = [SELECT Id, FEC_External_Interaction_ID__c FROM Case WHERE Id = :case1.Id];
        System.assertEquals('EXT-NEW-UNIQUE-001', updated.FEC_External_Interaction_ID__c,
            'External ID should be updated to new unique value');
    }

    /**
     * @description Test 5: Insert Case không có External ID - no-op, không lỗi
     */
    @isTest
    static void testInsert_NoExternalID_Success() {
        Id rtId = getInteractionRecordTypeId();

        Case c = new Case(
            Subject = 'Case No External ID',
            Status = 'New'
        );
        if (rtId != null) c.RecordTypeId = rtId;

        Test.startTest();
        insert c;
        Test.stopTest();

        Case inserted = [SELECT Id, FEC_External_Interaction_ID__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(null, inserted.FEC_External_Interaction_ID__c,
            'External ID should remain null');
    }

    /**
     * @description Test 6: Update Case nhưng External ID không thay đổi - no-op
     */
    @isTest
    static void testUpdate_ExternalIDUnchanged_NoCheck() {
        Id rtId = getInteractionRecordTypeId();

        Case c = new Case(
            Subject = 'Case Unchanged External ID',
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-UNCHANGED-001'
        );
        if (rtId != null) c.RecordTypeId = rtId;
        insert c;

        Test.startTest();

        // Update field khác, External ID giữ nguyên
        c.Subject = 'Updated Subject';
        update c;

        Test.stopTest();

        Case updated = [SELECT Id, Subject, FEC_External_Interaction_ID__c FROM Case WHERE Id = :c.Id];
        System.assertEquals('Updated Subject', updated.Subject, 'Subject should be updated');
        System.assertEquals('EXT-UNCHANGED-001', updated.FEC_External_Interaction_ID__c,
            'External ID should remain unchanged');
    }

    /**
     * @description Test 7: Bulk insert - nhiều Case với External ID unique
     */
    @isTest
    static void testBulkInsert_UniqueExternalIDs() {
        Id rtId = getInteractionRecordTypeId();

        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 50; i++) {
            Case c = new Case(
                Subject = 'Bulk Case ' + i,
                Status = 'New',
                FEC_External_Interaction_ID__c = 'EXT-BULK-' + String.valueOf(i).leftPad(3, '0')
            );
            if (rtId != null) c.RecordTypeId = rtId;
            cases.add(c);
        }

        Test.startTest();
        insert cases;
        Test.stopTest();

        List<Case> inserted = [SELECT Id FROM Case WHERE Id IN :cases];
        System.assertEquals(50, inserted.size(), 'All 50 cases should be inserted successfully');
    }

    /**
     * @description Test 8: Bulk insert - một số Case có External ID trùng với existing
     */
    @isTest
    static void testBulkInsert_SomeDuplicates() {
        Id rtId = getInteractionRecordTypeId();

        // Tạo Case existing
        Case existing = new Case(
            Subject = 'Existing Bulk',
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-BULK-DUP-005'
        );
        if (rtId != null) existing.RecordTypeId = rtId;
        insert existing;

        // Bulk insert: 1 Case trùng, 2 Case unique
        List<Case> cases = new List<Case>();
        
        Case uniqueCase1 = new Case(
            Subject = 'Unique Bulk 1',
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-BULK-DUP-001'
        );
        if (rtId != null) uniqueCase1.RecordTypeId = rtId;
        cases.add(uniqueCase1);

        Case duplicateCase = new Case(
            Subject = 'Duplicate Bulk',
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-BULK-DUP-005'
        );
        if (rtId != null) duplicateCase.RecordTypeId = rtId;
        cases.add(duplicateCase);

        Case uniqueCase2 = new Case(
            Subject = 'Unique Bulk 2',
            Status = 'New',
            FEC_External_Interaction_ID__c = 'EXT-BULK-DUP-010'
        );
        if (rtId != null) uniqueCase2.RecordTypeId = rtId;
        cases.add(uniqueCase2);

        Test.startTest();

        Database.SaveResult[] results = Database.insert(cases, false);

        Test.stopTest();

        // Case unique nên thành công, Case trùng nên fail
        System.assert(results[0].isSuccess(), 'Unique case 1 should succeed');
        System.assert(!results[1].isSuccess(), 'Duplicate case should fail');
        System.assert(results[1].getErrors()[0].getMessage().contains('External Interaction ID has already been used'),
            'Error message should indicate duplicate');
        System.assert(results[2].isSuccess(), 'Unique case 2 should succeed');
    }
}
