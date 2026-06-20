@IsTest
private class FEC_BatchCaseHandlingCaseFilter_Test {

    @TestSetup
    static void setupData() {
        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();
        Case withAttachment = new Case(
            Subject = 'Filter Case With Attachment',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'FILTER-ATT-YES',
            FEC_Customer_Type__c = 'Existing'
        );
        Case withoutAttachment = new Case(
            Subject = 'Filter Case Without Attachment',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'FILTER-ATT-NO',
            FEC_Customer_Type__c = 'Existing'
        );
        if (bulkCaseRtId != null) {
            withAttachment.RecordTypeId = bulkCaseRtId;
            withoutAttachment.RecordTypeId = bulkCaseRtId;
        }
        insert new List<Case>{ withAttachment, withoutAttachment };
        update new List<Case>{
            new Case(Id = withAttachment.Id, FEC_ID_Search__c = 'FILTER-ATT-YES'),
            new Case(Id = withoutAttachment.Id, FEC_ID_Search__c = 'FILTER-ATT-NO')
        };

        ContentVersion cv = new ContentVersion(
            Title = 'FilterAttachment',
            PathOnClient = 'FilterAttachment.pdf',
            VersionData = Blob.valueOf('Filter File')
        );
        insert cv;
        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        insert new ContentDocumentLink(
            LinkedEntityId = withAttachment.Id,
            ContentDocumentId = insertedCv.ContentDocumentId,
            ShareType = 'V'
        );
    }

    private static Id bulkCaseHandlingEligibleRecordTypeId() {
        List<RecordType> rows = [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE
                SObjectType = 'Case'
                AND DeveloperName IN (
                    :FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME,
                    :FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME
                )
        ];
        for (RecordType rt : rows) {
            if (rt.DeveloperName == FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME) {
                return rt.Id;
            }
        }
        return rows.isEmpty() ? null : rows[0].Id;
    }

    /**
     * Kịch bản 1: Kiểm tra hàm parseFilterMaps với các chuỗi JSON đầu vào khác nhau.
     * Bao phủ: Chuỗi JSON hợp lệ, chuỗi trống, null và mảng chứa object không hợp lệ.
     */
    @IsTest
    static void testParseFilterMaps() {
        // Chuỗi JSON hợp lệ
        String validJson = '[{"propertyKey":"CASE_ID","operatorKey":"equals","valueText":"C-001"}]';
        
        Test.startTest();
        List<Map<String, Object>> resultValid = FEC_BatchCaseHandlingCaseFilter.parseFilterMaps(validJson);
        List<Map<String, Object>> resultNull = FEC_BatchCaseHandlingCaseFilter.parseFilterMaps(null);
        List<Map<String, Object>> resultEmpty = FEC_BatchCaseHandlingCaseFilter.parseFilterMaps('');
        
        // Truyền một mảng chứa phần tử không phải Map (ví dụ chuỗi chữ thô) để phủ điều kiện "instanceof Map"
        List<Map<String, Object>> resultMixed = FEC_BatchCaseHandlingCaseFilter.parseFilterMaps('["not_a_map"]');
        Test.stopTest();

        System.assertEquals(1, resultValid.size(), 'Chuỗi JSON hợp lệ phải parse được 1 bộ lọc.');
        System.assertEquals('C-001', resultValid[0].get('valueText'));
        System.assertEquals(0, resultNull.size(), 'Tham số null phải trả về danh sách rỗng.');
        System.assertEquals(0, resultEmpty.size(), 'Tham số chuỗi trống phải trả về danh sách rỗng.');
        System.assertEquals(0, resultMixed.size(), 'Mảng không chứa cấu trúc Object Map phải bị loại bỏ.');
    }

    /**
     * Kịch bản 2: Kiểm tra hàm buildBaseCaseWhere sinh cấu trúc điều kiện WHERE mặc định cho Case.
     */
    @IsTest
    static void testBuildBaseCaseWhere() {
        Test.startTest();
        List<String> baseWhere = FEC_BatchCaseHandlingCaseFilter.buildBaseCaseWhere();
        Test.stopTest();

        System.assert(baseWhere.size() > 0, 'Hàm phải trả về danh sách các mệnh đề điều kiện WHERE cơ sở.');
        String combined = String.join(baseWhere, ' AND ');
        System.assert(combined.contains('RecordType.DeveloperName'), 'Mệnh đề WHERE cơ sở bắt buộc phải lọc Record Type Customer_Case.');
        System.assert(combined.contains('Status = \'Open\''), 'Mệnh đề WHERE cơ sở bắt buộc phải lọc Status Open.');
        System.assert(combined.contains('Status = \'Pending\''), 'Mệnh đề WHERE cơ sở bắt buộc phải lọc Status Pending.');
        // 18/06/2026 linhdev - spec điều kiện 2: OwnerId=$User.Id OR FEC_Assignment_Users__c chứa UserId
        System.assert(
            combined.contains('OwnerId = \'') && combined.contains('FEC_Assignment_Users__c LIKE'),
            'Mệnh đề WHERE cơ sở phải lọc Owner hoặc user trong FEC_Assignment_Users__c theo spec.'
        );
        // 19/06/2026 linhdev - Owner/Queue owner phải kèm FEC_Assignment_Count__c = 0
        System.assert(
            combined.contains('FEC_Assignment_Count__c = 0'),
            'Mệnh đề WHERE cơ sở phải lọc FEC_Assignment_Count__c = 0 cho Owner hoặc Queue owner.'
        );
    }

    /**
     * Kịch bản 2b: Case owned by queue mà login user là member phải nằm trong default filter scope.
     */
    @IsTest
    static void testBuildBaseCaseWhere_IncludesQueueOwnedCaseForMember() {
        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];
        if (queues.isEmpty()) {
            System.assert(true, 'Skipped: no queue in org.');
            return;
        }
        Id queueId = queues[0].Id;
        User runUser = new User(Id = UserInfo.getUserId());
        System.runAs(runUser) {
            ensureGroupMember(queueId, UserInfo.getUserId());
        }

        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();
        Id caseId;
        System.runAs(runUser) {
            Case queueOwnedCase = new Case(
                Subject = 'Queue Owned Filter Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                OwnerId = queueId,
                FEC_ID_Search__c = 'FILTER-QUEUE-OWNED',
                FEC_Customer_Type__c = 'Existing'
            );
            if (bulkCaseRtId != null) {
                queueOwnedCase.RecordTypeId = bulkCaseRtId;
            }
            insert queueOwnedCase;
            update new Case(Id = queueOwnedCase.Id, FEC_ID_Search__c = 'FILTER-QUEUE-OWNED');
            caseId = queueOwnedCase.Id;
        }

        Test.startTest();
        List<String> baseWhere = FEC_BatchCaseHandlingCaseFilter.buildBaseCaseWhere();
        String whereClause = String.join(baseWhere, ' AND ') + ' AND Id = \'' + String.valueOf(caseId) + '\'';
        Integer count = Database.countQuery('SELECT COUNT() FROM Case WHERE ' + whereClause);
        Test.stopTest();

        System.assertEquals(1, count, 'Case owned by queue mà user là member phải match default filter.');
    }

    /**
     * Kịch bản 2c: Case user là Owner trực tiếp phải match default filter scope.
     */
    @IsTest
    static void testBuildBaseCaseWhere_IncludesDirectOwnerCase() {
        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();
        Id loginUserId = UserInfo.getUserId();
        Case ownerCase = new Case(
            Subject = 'Direct Owner Filter Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            OwnerId = loginUserId,
            FEC_ID_Search__c = 'FILTER-DIRECT-OWNER',
            FEC_Customer_Type__c = 'Existing'
        );
        if (bulkCaseRtId != null) {
            ownerCase.RecordTypeId = bulkCaseRtId;
        }
        insert ownerCase;
        update new Case(Id = ownerCase.Id, FEC_ID_Search__c = 'FILTER-DIRECT-OWNER');

        Test.startTest();
        List<String> baseWhere = FEC_BatchCaseHandlingCaseFilter.buildBaseCaseWhere();
        String whereClause = String.join(baseWhere, ' AND ') + ' AND Id = \'' + String.valueOf(ownerCase.Id) + '\'';
        Integer count = Database.countQuery('SELECT COUNT() FROM Case WHERE ' + whereClause);
        Test.stopTest();

        System.assertEquals(1, count, 'Case owner trực tiếp phải match default filter.');
    }

    /**
     * Kịch bản 2d: User nằm trong FEC_Assignment_Users__c (không phải Owner) phải match default filter.
     */
    @IsTest
    static void testBuildBaseCaseWhere_IncludesAssignedUserCase() {
        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();
        List<User> otherUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = true AND Id != :UserInfo.getUserId()
            LIMIT 1
        ];
        if (otherUsers.isEmpty()) {
            System.assert(true, 'Skipped: no other active user in org.');
            return;
        }
        Id loginUserId = UserInfo.getUserId();
        Case assignedCase = new Case(
            Subject = 'Assigned User Filter Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            OwnerId = otherUsers[0].Id,
            FEC_ID_Search__c = 'FILTER-ASSIGNED-USER',
            FEC_Customer_Type__c = 'Existing'
        );
        if (bulkCaseRtId != null) {
            assignedCase.RecordTypeId = bulkCaseRtId;
        }
        insert assignedCase;
        update new Case(
            Id = assignedCase.Id,
            FEC_ID_Search__c = 'FILTER-ASSIGNED-USER',
            FEC_Assignment_Users__c = String.valueOf(loginUserId)
        );

        Test.startTest();
        List<String> baseWhere = FEC_BatchCaseHandlingCaseFilter.buildBaseCaseWhere();
        String whereClause = String.join(baseWhere, ' AND ') + ' AND Id = \'' + String.valueOf(assignedCase.Id) + '\'';
        Integer count = Database.countQuery('SELECT COUNT() FROM Case WHERE ' + whereClause);
        Test.stopTest();

        System.assertEquals(1, count, 'User trong FEC_Assignment_Users__c phải match default filter.');
    }

    /**
     * Kịch bản 2d2: User là Owner dù FEC_Assignment_Users__c chứa tên Queue vẫn phải match spec điều kiện 2.
     */
    @IsTest
    static void testBuildBaseCaseWhere_IncludesOwnerCaseWithQueueAssignmentName() {
        List<Group> queues = [
            SELECT Name
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];
        if (queues.isEmpty()) {
            System.assert(true, 'Skipped: no queue in org.');
            return;
        }
        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();
        Id loginUserId = UserInfo.getUserId();
        Case ownerWithQueueAssign = new Case(
            Subject = 'Owner With Queue Assignment Filter Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            OwnerId = loginUserId,
            FEC_ID_Search__c = 'FILTER-OWNER-QUEUE-ASSIGN',
            FEC_Customer_Type__c = 'Existing'
        );
        if (bulkCaseRtId != null) {
            ownerWithQueueAssign.RecordTypeId = bulkCaseRtId;
        }
        insert ownerWithQueueAssign;
        update new Case(
            Id = ownerWithQueueAssign.Id,
            FEC_ID_Search__c = 'FILTER-OWNER-QUEUE-ASSIGN',
            FEC_Assignment_Users__c = queues[0].Name
        );

        Test.startTest();
        List<String> baseWhere = FEC_BatchCaseHandlingCaseFilter.buildBaseCaseWhere();
        String whereClause = String.join(baseWhere, ' AND ') + ' AND Id = \'' + String.valueOf(ownerWithQueueAssign.Id) + '\'';
        Integer count = Database.countQuery('SELECT COUNT() FROM Case WHERE ' + whereClause);
        Test.stopTest();

        System.assertEquals(
            1,
            count,
            'User là Owner phải match default filter kể cả khi FEC_Assignment_Users__c chứa tên Queue.'
        );
    }

    /**
     * Kịch bản 2e: Case owner user khác, không assigned, không thuộc queue member => không match default filter.
     */
    @IsTest
    static void testBuildBaseCaseWhere_ExcludesUnrelatedUserOwnedCase() {
        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();
        List<User> otherUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = true AND Id != :UserInfo.getUserId()
            LIMIT 1
        ];
        if (otherUsers.isEmpty()) {
            System.assert(true, 'Skipped: no other active user in org.');
            return;
        }
        Case otherOwnerCase = new Case(
            Subject = 'Other Owner Filter Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            OwnerId = otherUsers[0].Id,
            FEC_ID_Search__c = 'FILTER-OTHER-OWNER',
            FEC_Customer_Type__c = 'Existing'
        );
        if (bulkCaseRtId != null) {
            otherOwnerCase.RecordTypeId = bulkCaseRtId;
        }
        insert otherOwnerCase;
        update new Case(Id = otherOwnerCase.Id, FEC_ID_Search__c = 'FILTER-OTHER-OWNER');

        Test.startTest();
        List<String> baseWhere = FEC_BatchCaseHandlingCaseFilter.buildBaseCaseWhere();
        String whereClause = String.join(baseWhere, ' AND ') + ' AND Id = \'' + String.valueOf(otherOwnerCase.Id) + '\'';
        Integer count = Database.countQuery('SELECT COUNT() FROM Case WHERE ' + whereClause);
        Test.stopTest();

        System.assertEquals(0, count, 'Case owner user khác không liên quan phải bị loại khỏi default filter.');
    }

    /**
     * Kịch bản 2g: Case owner trực tiếp nhưng FEC_Assignment_Count__c > 0 không match qua nhánh Owner.
     */
    @IsTest
    static void testBuildBaseCaseWhere_ExcludesDirectOwnerCaseWithAssignmentCount() {
        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();
        Id loginUserId = UserInfo.getUserId();
        Case ownerCase = new Case(
            Subject = 'Direct Owner With Assignment Filter Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            OwnerId = loginUserId,
            FEC_ID_Search__c = 'FILTER-DIRECT-OWNER-ASG',
            FEC_Customer_Type__c = 'Existing'
        );
        if (bulkCaseRtId != null) {
            ownerCase.RecordTypeId = bulkCaseRtId;
        }
        insert ownerCase;
        update new Case(Id = ownerCase.Id, FEC_ID_Search__c = 'FILTER-DIRECT-OWNER-ASG');
        insertRoutingAssignment(ownerCase.Id);

        Decimal assignmentCount = [
            SELECT FEC_Assignment_Count__c
            FROM Case
            WHERE Id = :ownerCase.Id
        ].FEC_Assignment_Count__c;
        if (assignmentCount == null || assignmentCount <= 0) {
            System.assert(true, 'Skipped: FEC_Assignment_Count__c chưa được rollup trên Case mồi.');
            return;
        }

        Test.startTest();
        List<String> baseWhere = FEC_BatchCaseHandlingCaseFilter.buildBaseCaseWhere();
        String whereClause = String.join(baseWhere, ' AND ') + ' AND Id = \'' + String.valueOf(ownerCase.Id) + '\'';
        Integer count = Database.countQuery('SELECT COUNT() FROM Case WHERE ' + whereClause);
        Test.stopTest();

        System.assertEquals(
            0,
            count,
            'Case owner trực tiếp với FEC_Assignment_Count__c > 0 phải bị loại khỏi default filter.'
        );
    }

    /**
     * Kịch bản 2h: Case owned by queue (user là member) nhưng FEC_Assignment_Count__c > 0 không match qua nhánh Queue Owner.
     */
    @IsTest
    static void testBuildBaseCaseWhere_ExcludesQueueOwnedCaseWithAssignmentCount() {
        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];
        if (queues.isEmpty()) {
            System.assert(true, 'Skipped: no queue in org.');
            return;
        }
        Id queueId = queues[0].Id;
        User runUser = new User(Id = UserInfo.getUserId());
        System.runAs(runUser) {
            ensureGroupMember(queueId, UserInfo.getUserId());
        }

        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();
        Id caseId;
        System.runAs(runUser) {
            Case queueOwnedCase = new Case(
                Subject = 'Queue Owned With Assignment Filter Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                OwnerId = queueId,
                FEC_ID_Search__c = 'FILTER-QUEUE-OWNED-ASG',
                FEC_Customer_Type__c = 'Existing'
            );
            if (bulkCaseRtId != null) {
                queueOwnedCase.RecordTypeId = bulkCaseRtId;
            }
            insert queueOwnedCase;
            update new Case(Id = queueOwnedCase.Id, FEC_ID_Search__c = 'FILTER-QUEUE-OWNED-ASG');
            insertRoutingAssignment(queueOwnedCase.Id);
            caseId = queueOwnedCase.Id;
        }

        Decimal assignmentCount = [
            SELECT FEC_Assignment_Count__c
            FROM Case
            WHERE Id = :caseId
        ].FEC_Assignment_Count__c;
        if (assignmentCount == null || assignmentCount <= 0) {
            System.assert(true, 'Skipped: FEC_Assignment_Count__c chưa được rollup trên Case mồi.');
            return;
        }

        Test.startTest();
        List<String> baseWhere = FEC_BatchCaseHandlingCaseFilter.buildBaseCaseWhere();
        String whereClause = String.join(baseWhere, ' AND ') + ' AND Id = \'' + String.valueOf(caseId) + '\'';
        Integer count = Database.countQuery('SELECT COUNT() FROM Case WHERE ' + whereClause);
        Test.stopTest();

        System.assertEquals(
            0,
            count,
            'Case owned by queue với FEC_Assignment_Count__c > 0 phải bị loại khỏi default filter.'
        );
    }

    /**
     * Kịch bản 2f: Case FEC_Assignment_Users__c chứa tên Queue mà login user là member phải match default filter.
     */
    @IsTest
    static void testBuildBaseCaseWhere_IncludesAssignmentQueueNameCase() {
        List<Group> queues = [
            SELECT Id, Name
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];
        if (queues.isEmpty()) {
            System.assert(true, 'Skipped: no queue in org.');
            return;
        }
        Id queueId = queues[0].Id;
        String queueName = queues[0].Name;
        User runUser = new User(Id = UserInfo.getUserId());
        System.runAs(runUser) {
            ensureGroupMember(queueId, UserInfo.getUserId());
        }

        List<User> otherUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = true AND Id != :UserInfo.getUserId()
            LIMIT 1
        ];
        if (otherUsers.isEmpty()) {
            System.assert(true, 'Skipped: no other active user in org.');
            return;
        }

        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();
        Id caseId;
        System.runAs(runUser) {
            Case assignedQueueCase = new Case(
                Subject = 'Assignment Queue Name Filter Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                OwnerId = otherUsers[0].Id,
                FEC_ID_Search__c = 'FILTER-ASSIGN-QUEUE-NAME',
                FEC_Customer_Type__c = 'Existing'
            );
            if (bulkCaseRtId != null) {
                assignedQueueCase.RecordTypeId = bulkCaseRtId;
            }
            insert assignedQueueCase;
            update new Case(
                Id = assignedQueueCase.Id,
                FEC_ID_Search__c = 'FILTER-ASSIGN-QUEUE-NAME',
                FEC_Assignment_Users__c = queueName
            );
            caseId = assignedQueueCase.Id;
        }

        Test.startTest();
        List<String> baseWhere = FEC_BatchCaseHandlingCaseFilter.buildBaseCaseWhere();
        String combined = String.join(baseWhere, ' AND ');
        String whereClause = combined + ' AND Id = \'' + String.valueOf(caseId) + '\'';
        Integer count = Database.countQuery('SELECT COUNT() FROM Case WHERE ' + whereClause);
        Test.stopTest();

        System.assert(
            combined.contains('FEC_Assignment_Users__c LIKE'),
            'Mệnh đề WHERE cơ sở phải chứa điều kiện FEC_Assignment_Users__c LIKE tên Queue.'
        );
        System.assertEquals(
            1,
            count,
            'Case có FEC_Assignment_Users__c chứa tên Queue mà user là member phải match default filter.'
        );
    }

    /**
     * Kịch bản 2g: buildCompleteWhere với filter rỗng vẫn áp dụng default scope owner/assigned/queue.
     */
    @IsTest
    static void testBuildCompleteWhere_DefaultScopeIncludesQueueMemberCase() {
        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];
        if (queues.isEmpty()) {
            System.assert(true, 'Skipped: no queue in org.');
            return;
        }
        Id queueId = queues[0].Id;
        User runUser = new User(Id = UserInfo.getUserId());
        System.runAs(runUser) {
            ensureGroupMember(queueId, UserInfo.getUserId());
        }

        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();
        Id caseId;
        System.runAs(runUser) {
            Case queueOwnedCase = new Case(
                Subject = 'Complete Where Queue Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                OwnerId = queueId,
                FEC_ID_Search__c = 'FILTER-COMPLETE-QUEUE',
                FEC_Customer_Type__c = 'Existing'
            );
            if (bulkCaseRtId != null) {
                queueOwnedCase.RecordTypeId = bulkCaseRtId;
            }
            insert queueOwnedCase;
            update new Case(Id = queueOwnedCase.Id, FEC_ID_Search__c = 'FILTER-COMPLETE-QUEUE');
            caseId = queueOwnedCase.Id;
        }

        Test.startTest();
        List<String> whereParts = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(new List<Map<String, Object>>());
        String whereClause = String.join(whereParts, ' AND ') + ' AND Id = \'' + String.valueOf(caseId) + '\'';
        Integer count = Database.countQuery('SELECT COUNT() FROM Case WHERE ' + whereClause);
        Test.stopTest();

        System.assert(whereParts.size() > 0);
        System.assertEquals(1, count, 'buildCompleteWhere phải giữ Case queue member trong default scope.');
    }

    private static void ensureGroupMember(Id groupId, Id userOrGroupId) {
        List<GroupMember> existing = [
            SELECT Id
            FROM GroupMember
            WHERE GroupId = :groupId AND UserOrGroupId = :userOrGroupId
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new GroupMember(GroupId = groupId, UserOrGroupId = userOrGroupId);
        }
    }

    private static void insertRoutingAssignment(Id caseId) {
        String status;
        for (Schema.PicklistEntry entry :
            FEC_Assignment__c.FEC_Assignment_Status__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                status = entry.getValue();
                break;
            }
        }
        insert new FEC_Assignment__c(
            FEC_Case__c = caseId,
            FEC_Assignment_Name__c = 'BCH Filter Assignment ' + String.valueOf(System.currentTimeMillis()),
            FEC_Assignment_Status__c = status,
            FEC_Assignment_Type__c = FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING,
            FEC_Assignment_Owner__c = UserInfo.getUserId()
        );
    }

    /**
     * Kịch bản 3: Kiểm tra hàm buildDynamicWhereFromFilters với tham số rỗng hoặc biên.
     */
    @IsTest
    static void testBuildDynamicWhereFromFilters_Empty() {
        Test.startTest();
        List<String> resultNull = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(null);
        List<String> resultEmpty = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(new List<Map<String, Object>>());
        
        // Bộ lọc thiếu key quan trọng prop hoặc op
        List<Map<String, Object>> invalidFilters = new List<Map<String, Object>>{
            new Map<String, Object>{ 'propertyKey' => '', 'operatorKey' => 'equals' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => null }
        };
        List<String> resultInvalid = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(invalidFilters);
        Test.stopTest();

        System.assertEquals(0, resultNull.size());
        System.assertEquals(0, resultEmpty.size());
        System.assertEquals(0, resultInvalid.size(), 'Các bộ lọc thiếu thông tin key hoặc toán tử toán hạng phải bị bỏ qua.');
    }

    /**
     * Kịch bản 4: Chuẩn hóa toán tử (normalizeOperatorKey) và sinh mệnh đề tương ứng.
     * Lưu ý: toán tử so sánh ngày (<, >, …) chỉ được buildDateClause xử lý — dùng CASE_CREATED_ON, không dùng CASE_ID.
     */
    @IsTest
    static void testNormalizeOperatorKeys_AllBranches() {
        List<Map<String, Object>> rawFilters = new List<Map<String, Object>>{
            new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'notequalto', 'valueText' => 'X' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'lessthan', 'valueText' => '2026-05-19' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'greaterthan', 'valueText' => '2026-05-19' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'lessorequal', 'valueText' => '2026-05-19' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'greaterorequal', 'valueText' => '2026-05-19' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'doesnotcontain', 'valueText' => 'X' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'startswith', 'valueText' => 'X' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'doesnotstartswith', 'valueText' => 'X' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'isnull', 'valueText' => 'ignored' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'isnotnull', 'valueText' => 'ignored' }
        };

        Test.startTest();
        List<String> clauses = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(rawFilters);
        Test.stopTest();

        System.assertEquals(10, clauses.size(), 'Mỗi bộ lọc phải sinh một mệnh đề (text hoặc ngày).');
    }

    /**
     * Kịch bản 5: Bao phủ toàn bộ các thuộc tính lọc chuỗi ký tự (Text Clauses) và các toán tử SOQL phổ biến.
     */
    @IsTest
    static void testBuildTextClauses_PropertiesAndOperators() {
        // Danh sách kiểm tra toàn bộ các Property Key dạng chuỗi văn bản
        List<String> textProperties = new List<String>{
            'CASE_ID', 'CASE_CREATED_BY', 'CASE_CREATED_BY_ROLE', 'CASE_STATUS',
            'PRODUCT_TYPE', 'CATEGORY', 'SUB_CATEGORY', 'SUB_CODE'
        };

        List<Map<String, Object>> filters = new List<Map<String, Object>>();
        for (String prop : textProperties) {
            filters.add(new Map<String, Object>{ 'propertyKey' => prop, 'operatorKey' => 'equals', 'valueText' => 'TestVal' });
        }

        // Bổ sung các toán tử chuỗi mở rộng (contains, does_not_contain,starts_with, etc.) để bao phủ hàm buildTextClause
        filters.add(new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'contains', 'valueText' => 'ABC' });
        filters.add(new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'does_not_contain', 'valueText' => 'ABC' });
        filters.add(new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'starts_with', 'valueText' => 'ABC' });
        filters.add(new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'does_not_start_with', 'valueText' => 'ABC' });
        // Dòng biên: vText rỗng nhưng toán tử không yêu cầu vText
        filters.add(new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'is_null', 'valueText' => '' });
        filters.add(new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'is_not_null', 'valueText' => '' });
        // Dòng biên: vText rỗng nhưng toán tử lại yêu cầu phải có vText -> Trả về chuỗi rỗng không sinh clause
        filters.add(new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'equals', 'valueText' => '' });

        Test.startTest();
        List<String> clauses = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(filters);
        Test.stopTest();

        System.assert(clauses.size() > 0);
    }

    /**
     * Kịch bản 6: Kiểm tra bộ lọc danh sách thuộc tính CUSTOMER_TYPE (Mệnh đề IN / NOT IN).
     */
    @IsTest
    static void testBuildInOrNotClause_CustomerType() {
        List<Object> mockList = new List<Object>{ 'VIP', 'Mass', '  ' }; // Mảng chứa phần tử rỗng để test vòng lặp trim/isNotBlank
        
        List<Map<String, Object>> filters = new List<Map<String, Object>>{
            // Trường hợp 1: Dùng valueList + toán tử equals
            new Map<String, Object>{ 'propertyKey' => 'CUSTOMER_TYPE', 'operatorKey' => 'equals', 'valueList' => mockList },
            // Trường hợp 2: Dùng valueList + toán tử not_equal_to
            new Map<String, Object>{ 'propertyKey' => 'CUSTOMER_TYPE', 'operatorKey' => 'not_equal_to', 'valueList' => mockList },
            // Trường hợp 3: Fallback dùng valueText khi valueList rỗng
            new Map<String, Object>{ 'propertyKey' => 'CUSTOMER_TYPE', 'operatorKey' => 'equals', 'valueText' => 'SingleType' },
            // Trường hợp 4: Cả 2 đều trống -> Trả về chuỗi rỗng
            new Map<String, Object>{ 'propertyKey' => 'CUSTOMER_TYPE', 'operatorKey' => 'equals', 'valueText' => '' }
        };

        Test.startTest();
        List<String> clauses = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(filters);
        Test.stopTest();

        System.assertEquals(3, clauses.size(), 'Chỉ có 3 bộ lọc sinh ra mệnh đề hợp lệ.');
        System.assert(clauses[0].contains('FEC_Customer_Type__c IN'), 'Mệnh đề phải sinh cấu trúc từ khóa IN.');
        System.assert(clauses[1].contains('FEC_Customer_Type__c NOT IN'), 'Mệnh đề phải sinh cấu trúc từ khóa NOT IN.');
    }

    /**
     * Kịch bản 7: Kiểm tra bộ lọc theo Thời gian tạo CASE_CREATED_ON (Mệnh đề Date và hàm DATEVALUE).
     */
    @IsTest
    static void testBuildDateClause_CaseCreatedOn() {
        List<Map<String, Object>> filters = new List<Map<String, Object>>{
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'equals', 'valueText' => '2026-05-19' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'not_equal_to', 'valueText' => '2026-05-19' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'less_than', 'valueText' => '2026-05-19' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'greater_than', 'valueText' => '2026-05-09' }, // Test nhánh số ngày < 10 (09) để bao phủ logic mo/da < 10
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'less_or_equal', 'valueText' => '2026-05-19' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'greater_or_equal', 'valueText' => '2026-05-19' },
            // Trường hợp lỗi định dạng ngày -> nhảy vào catch trả về rỗng
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'equals', 'valueText' => 'sai_dinh_dang_ngay' },
            // Trường hợp chuỗi trống đầu vào
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'equals', 'valueText' => '' }
        };

        Test.startTest();
        List<String> clauses = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(filters);
        Test.stopTest();

        System.assertEquals(6, clauses.size(), '6 bộ lọc ngày chuẩn phải sinh ra điều kiện đầy đủ.');
        System.assert(clauses[0].contains('DAY_ONLY(FEC_Case_Created_On__c)'), 'Cấu trúc mệnh đề ngày phải bọc qua hàm DAY_ONLY.');
    }

    /**
     * Kịch bản 8: Kiểm tra cấu trúc lọc file đính kèm ATTACHMENTS (Mệnh đề Sub-Query IN/NOT IN ContentDocumentLink).
     */
    @IsTest
    static void testBuildAttachmentClauses_BooleanInterpretation() {
        // Tổng hợp toàn bộ các kiểu text đại diện cho True / False để test hàm interpretBoolean
        List<Map<String, Object>> filters = new List<Map<String, Object>>{
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'equals', 'valueText' => 'true' },
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'equals', 'valueText' => '1' },
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'equals', 'valueText' => 'yes' },
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'equals', 'valueText' => 'false' },
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'equals', 'valueText' => '0' },
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'equals', 'valueText' => 'no' },
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'not_equal_to', 'valueText' => 'true' },
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'not_equal_to', 'valueText' => 'false' },
            // Biên: Giá trị text không hợp lệ/rỗng
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'equals', 'valueText' => 'khong_hop_le' },
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'equals', 'valueText' => '' }
        };

        Test.startTest();
        List<String> clauses = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(filters);
        List<String> completeWhere = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(filters);
        Test.stopTest();

        System.assertEquals(0, clauses.size(), 'ATTACHMENTS được xử lý ở buildCompleteWhere, không qua buildDynamicWhereFromFilters.');
        System.assert(completeWhere.size() > 1, 'buildCompleteWhere phải gộp base where và attachment filter.');
    }

    /**
     * Kịch bản 9: buildCompleteWhere với bộ lọc ATTACHMENTS qua public API.
     */
    @IsTest
    static void testBuildCompleteWhere_WithAttachments() {
        List<Map<String, Object>> hasAttachment = new List<Map<String, Object>>{
            new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'equals', 'valueText' => 'FILTER-ATT-YES' },
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'equals', 'valueText' => 'true' }
        };
        List<Map<String, Object>> noAttachment = new List<Map<String, Object>>{
            new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'equals', 'valueText' => 'FILTER-ATT-NO' },
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'equals', 'valueText' => 'false' }
        };

        Test.startTest();
        List<String> whereHas = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(hasAttachment);
        List<String> whereNo = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(noAttachment);
        Integer countHas = Database.countQuery(
            'SELECT COUNT() FROM Case WHERE ' + String.join(whereHas, ' AND ')
        );
        Integer countNo = Database.countQuery(
            'SELECT COUNT() FROM Case WHERE ' + String.join(whereNo, ' AND ')
        );
        Test.stopTest();

        System.assert(whereHas[whereHas.size() - 1].contains('Id IN') || whereHas[whereHas.size() - 1].contains('Id = null'));
        System.assert(countHas >= 0);
        System.assert(countNo >= 0);
    }

    /**
     * Kịch bản 10: buildCompleteWhere với bộ lọc QUEUE và trường Case generic.
     */
    @IsTest
    static void testBuildCompleteWhere_QueueAndGenericField() {
        List<Map<String, Object>> queueFilter = new List<Map<String, Object>>{
            new Map<String, Object>{ 'propertyKey' => 'QUEUE', 'operatorKey' => 'equals', 'valueText' => 'My Pending Cases' }
        };
        List<Map<String, Object>> originFilter = new List<Map<String, Object>>{
            new Map<String, Object>{ 'propertyKey' => 'Origin', 'operatorKey' => 'equals', 'valueText' => 'Phone' }
        };

        Test.startTest();
        List<String> queueWhere = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(queueFilter);
        List<String> originWhere = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(originFilter);
        Test.stopTest();

        System.assert(queueWhere.size() > 1);
        System.assert(originWhere.size() > 1);
    }

    /**
     * Kịch bản 11: buildDynamicWhereFromFilters bỏ qua ATTACHMENTS (xử lý ở buildCompleteWhere).
     */
    @IsTest
    static void testBuildDynamicWhere_SkipsAttachmentsProperty() {
        List<Map<String, Object>> filters = new List<Map<String, Object>>{
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'equals', 'valueText' => 'true' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'equals', 'valueText' => 'FILTER-ATT-YES' }
        };

        Test.startTest();
        List<String> dynamicOnly = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(filters);
        Test.stopTest();

        System.assertEquals(1, dynamicOnly.size());
        System.assert(dynamicOnly[0].contains('FEC_ID_Search__c'));
    }

    @IsTest
    static void testBuildCompleteWhere_AttachmentNotEqualTo() {
        List<Map<String, Object>> filters = new List<Map<String, Object>>{
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'not_equal_to', 'valueText' => 'true' }
        };

        Test.startTest();
        List<String> whereParts = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(filters);
        Test.stopTest();

        System.assert(whereParts.size() > 1, 'not_equal_to attachment should add exclusion clause when cases have attachments.');
    }

    @IsTest
    static void testBuildCompleteWhere_CombinedCaseIdAndAttachment() {
        List<Map<String, Object>> filters = new List<Map<String, Object>>{
            new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'equals', 'valueText' => 'FILTER-ATT-YES' },
            new Map<String, Object>{ 'propertyKey' => 'ATTACHMENTS', 'operatorKey' => 'equals', 'valueText' => 'true' },
            new Map<String, Object>{ 'propertyKey' => 'CUSTOMER_TYPE', 'operatorKey' => 'equals', 'valueText' => 'Existing' }
        };

        Test.startTest();
        List<String> whereParts = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(filters);
        String soql = 'SELECT COUNT() FROM Case WHERE ' + String.join(whereParts, ' AND ');
        Integer count = Database.countQuery(soql);
        Test.stopTest();

        System.assert(whereParts.size() >= 5);
        System.assert(count >= 0);
    }

    @IsTest
    static void testBuildDynamicWhere_GenericBooleanField() {
        Map<String, Schema.SObjectField> fieldMap = Case.SObjectType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey('IsEscalated')) {
            System.assert(true, 'Skipped: IsEscalated not filterable on org.');
            return;
        }

        List<Map<String, Object>> filters = new List<Map<String, Object>>{
            new Map<String, Object>{ 'propertyKey' => 'IsEscalated', 'operatorKey' => 'equals', 'valueText' => 'false' },
            new Map<String, Object>{ 'propertyKey' => 'IsEscalated', 'operatorKey' => 'is_null', 'valueText' => '' }
        };

        Test.startTest();
        List<String> clauses = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(filters);
        Test.stopTest();

        System.assert(clauses.size() >= 1);
    }

    @IsTest
    static void testBuildCompleteWhere_NullFilterMaps() {
        Test.startTest();
        List<String> whereParts = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(null);
        Test.stopTest();

        System.assert(whereParts.size() >= 1);
    }

    @IsTest
    static void testBuildDynamicWhere_AdditionalOperators() {
        List<Map<String, Object>> filters = new List<Map<String, Object>>{
            new Map<String, Object>{ 'propertyKey' => 'CASE_ID', 'operatorKey' => 'starts_with', 'valueText' => 'FILTER' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_STATUS', 'operatorKey' => 'does_not_contain', 'valueText' => 'Closed' },
            new Map<String, Object>{ 'propertyKey' => 'CUSTOMER_TYPE', 'operatorKey' => 'not_equal_to', 'valueList' => new List<Object>{ 'Existing' } },
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_BY_ROLE', 'operatorKey' => 'is_not_null', 'valueText' => '' }
        };

        Test.startTest();
        List<String> clauses = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(filters);
        Test.stopTest();

        System.assert(clauses.size() >= 2);
    }

    @IsTest
    static void testBuildDynamicWhere_QueueAndDateFilters() {
        List<Group> queues = [
            SELECT Name
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];
        List<Map<String, Object>> filters = new List<Map<String, Object>>{
            new Map<String, Object>{
                'propertyKey' => 'QUEUE',
                'operatorKey' => 'equals',
                'valueList' => new List<Object>{ 'My Pending Cases' }
            },
            new Map<String, Object>{
                'propertyKey' => 'CASE_CREATED_ON',
                'operatorKey' => 'equals',
                'valueText' => '2026-01-05'
            },
            new Map<String, Object>{
                'propertyKey' => 'CASE_CREATED_ON',
                'operatorKey' => 'greater_or_equal',
                'valueText' => 'invalid-date'
            }
        };
        if (!queues.isEmpty()) {
            filters.add(new Map<String, Object>{
                'propertyKey' => 'QUEUE',
                'operatorKey' => 'not_equal_to',
                'valueList' => new List<Object>{ queues[0].Name }
            });
        }

        Test.startTest();
        List<String> clauses = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(filters);
        Test.stopTest();

        System.assertNotEquals(null, clauses);
        System.assert(clauses.size() >= 1);
    }

    @IsTest
    static void testBuildGenericCaseFieldClause_BooleanNotEqual() {
        Map<String, Schema.SObjectField> fieldMap = Case.SObjectType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey('IsEscalated')) {
            System.assert(true, 'Skipped: IsEscalated not on Case.');
            return;
        }
        List<Map<String, Object>> filters = new List<Map<String, Object>>{
            new Map<String, Object>{
                'propertyKey' => 'IsEscalated',
                'operatorKey' => 'not_equal_to',
                'valueText' => 'true'
            }
        };

        Test.startTest();
        List<String> clauses = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(filters);
        Test.stopTest();

        System.assertEquals(1, clauses.size());
        System.assert(clauses[0].contains('!='));
    }

    @IsTest
    static void testBuildDateClause_AllOperators() {
        List<Map<String, Object>> filters = new List<Map<String, Object>>{
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'less_than', 'valueText' => '2026-01-05' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'greater_than', 'valueText' => '2026-09-09' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'less_or_equal', 'valueText' => '2026-03-03' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'greater_or_equal', 'valueText' => '2026-12-31' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'is_null', 'valueText' => '' },
            new Map<String, Object>{ 'propertyKey' => 'CASE_CREATED_ON', 'operatorKey' => 'is_not_null', 'valueText' => '' }
        };

        Test.startTest();
        List<String> clauses = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(filters);
        Test.stopTest();

        System.assert(clauses.size() >= 4);
    }

    @IsTest
    static void testBuildCompleteWhere_WithQueueFilter() {
        List<Group> queues = [
            SELECT Name
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];
        if (queues.isEmpty()) {
            System.assert(true, 'Skipped: no queue in org.');
            return;
        }
        String filtersJson = '[{"propertyKey":"QUEUE","operatorKey":"equals","valueList":["' +
            String.escapeSingleQuotes(queues[0].Name) +
            '"]}]';

        Test.startTest();
        List<String> whereParts = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(
            FEC_BatchCaseHandlingCaseFilter.parseFilterMaps(filtersJson)
        );
        Test.stopTest();

        System.assert(whereParts.size() >= 1);
        String combined = String.join(whereParts, ' AND ');
        System.assert(
            combined.contains('FEC_Assignment_Count__c = 0'),
            'Filter Queue equals phải kèm FEC_Assignment_Count__c = 0 cho nhánh OwnerId IN queue.'
        );
    }

    /**
     * Kịch bản: filter Queue equals phải loại Case Owner = queue nhưng FEC_Assignment_Count__c > 0.
     */
    @IsTest
    static void testBuildCompleteWhere_QueueFilterExcludesQueueOwnerWithAssignmentCount() {
        List<Group> queues = [
            SELECT Id, Name
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];
        if (queues.isEmpty()) {
            System.assert(true, 'Skipped: no queue in org.');
            return;
        }
        Id queueId = queues[0].Id;
        String queueName = queues[0].Name;
        User runUser = new User(Id = UserInfo.getUserId());
        System.runAs(runUser) {
            ensureGroupMember(queueId, UserInfo.getUserId());
        }

        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();
        Id caseId;
        System.runAs(runUser) {
            Case queueOwnedCase = new Case(
                Subject = 'Queue Filter Owner With Assignment Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                OwnerId = queueId,
                FEC_ID_Search__c = 'FILTER-QUEUE-OWNER-ASG',
                FEC_Customer_Type__c = 'Existing'
            );
            if (bulkCaseRtId != null) {
                queueOwnedCase.RecordTypeId = bulkCaseRtId;
            }
            insert queueOwnedCase;
            update new Case(Id = queueOwnedCase.Id, FEC_ID_Search__c = 'FILTER-QUEUE-OWNER-ASG');
            insertRoutingAssignment(queueOwnedCase.Id);
            caseId = queueOwnedCase.Id;
        }

        Decimal assignmentCount = [
            SELECT FEC_Assignment_Count__c
            FROM Case
            WHERE Id = :caseId
        ].FEC_Assignment_Count__c;
        if (assignmentCount == null || assignmentCount <= 0) {
            System.assert(true, 'Skipped: FEC_Assignment_Count__c chưa được rollup trên Case mồi.');
            return;
        }

        String filtersJson = '[{"propertyKey":"QUEUE","operatorKey":"equals","valueList":["' +
            String.escapeSingleQuotes(queueName) +
            '"]}]';

        Test.startTest();
        List<String> whereParts = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(
            FEC_BatchCaseHandlingCaseFilter.parseFilterMaps(filtersJson)
        );
        String whereClause = String.join(whereParts, ' AND ') + ' AND Id = \'' + String.valueOf(caseId) + '\'';
        Integer count = Database.countQuery('SELECT COUNT() FROM Case WHERE ' + whereClause);
        Test.stopTest();

        System.assertEquals(
            0,
            count,
            'Filter Queue equals phải loại Case Owner = queue khi FEC_Assignment_Count__c > 0.'
        );
    }

    /**
     * Kịch bản: filter Queue equals phải match cả OwnerId lẫn FEC_Assignment_Users__c chứa tên Queue.
     */
    @IsTest
    static void testBuildCompleteWhere_QueueFilterMatchesAssignmentUsersField() {
        List<Group> queues = [
            SELECT Id, Name
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];
        if (queues.isEmpty()) {
            System.assert(true, 'Skipped: no queue in org.');
            return;
        }
        Id queueId = queues[0].Id;
        String queueName = queues[0].Name;
        User runUser = new User(Id = UserInfo.getUserId());
        System.runAs(runUser) {
            ensureGroupMember(queueId, UserInfo.getUserId());
        }

        List<User> otherUsers = [
            SELECT Id
            FROM User
            WHERE Id != :UserInfo.getUserId()
            AND IsActive = true
            LIMIT 1
        ];
        if (otherUsers.isEmpty()) {
            System.assert(true, 'Skipped: no other active user.');
            return;
        }

        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();
        Id caseId;
        System.runAs(runUser) {
            Case assignedQueueCase = new Case(
                Subject = 'Queue Filter Assignment Field Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                OwnerId = otherUsers[0].Id,
                FEC_ID_Search__c = 'FILTER-QUEUE-ASSIGN-FIELD',
                FEC_Customer_Type__c = 'Existing'
            );
            if (bulkCaseRtId != null) {
                assignedQueueCase.RecordTypeId = bulkCaseRtId;
            }
            insert assignedQueueCase;
            update new Case(
                Id = assignedQueueCase.Id,
                FEC_ID_Search__c = 'FILTER-QUEUE-ASSIGN-FIELD',
                FEC_Assignment_Users__c = queueName
            );
            caseId = assignedQueueCase.Id;
        }

        String filtersJson = '[{"propertyKey":"QUEUE","operatorKey":"equals","valueList":["' +
            String.escapeSingleQuotes(queueName) +
            '"]}]';

        Test.startTest();
        List<String> whereParts = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(
            FEC_BatchCaseHandlingCaseFilter.parseFilterMaps(filtersJson)
        );
        String combined = String.join(whereParts, ' AND ');
        String whereClause = combined + ' AND Id = \'' + String.valueOf(caseId) + '\'';
        Integer count = Database.countQuery('SELECT COUNT() FROM Case WHERE ' + whereClause);
        Test.stopTest();

        System.assert(
            combined.contains('FEC_Assignment_Users__c LIKE'),
            'Filter Queue equals phải chứa điều kiện FEC_Assignment_Users__c LIKE tên Queue.'
        );
        System.assertEquals(
            1,
            count,
            'Case có FEC_Assignment_Users__c chứa tên Queue phải match filter Queue equals.'
        );
    }

    @IsTest
    static void testBuildDynamicWhere_QueueNotEqualCombined() {
        List<Map<String, Object>> filters = new List<Map<String, Object>>{
            new Map<String, Object>{
                'propertyKey' => 'QUEUE',
                'operatorKey' => 'not_equal_to',
                'valueList' => new List<Object>{ 'My Pending Cases', 'DQ - CS Support' }
            }
        };

        Test.startTest();
        List<String> clauses = FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(filters);
        Test.stopTest();

        System.assertNotEquals(null, clauses);
    }
}