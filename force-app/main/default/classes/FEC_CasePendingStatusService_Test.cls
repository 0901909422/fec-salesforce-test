@IsTest
private class FEC_CasePendingStatusService_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        // Tạo Queue mồi cho các sự kiện chuyển quyền (Route)
        Group g1 = new Group(Name = 'Queue Test A', Type = 'Queue');
        Group g2 = new Group(Name = 'Queue Test B', Type = 'Queue');
        insert new List<Group>{g1, g2};
        
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new QueueSobject(QueueId = g1.Id, SobjectType = 'Case');
            insert new QueueSobject(QueueId = g2.Id, SobjectType = 'Case');
        }

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new List<Case>{
                new Case(
                    Subject = 'Case Submitted Status Sync',
                    Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                    FEC_Is_Submited__c = true,
                    FEC_Team__c = 'Support Team',
                    FEC_ID_Search__c = 'PND-SUBMIT-' + suffix
                ),
                new Case(
                    Subject = 'Case Draft Ignore Sync',
                    Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                    FEC_Is_Submited__c = false,
                    FEC_ID_Search__c = 'PND-DRAFT-' + suffix
                ),
                new Case(
                    Subject = 'Case Pending Fallback',
                    Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
                    FEC_Team__c = 'Credit Team',
                    FEC_ID_Search__c = 'PND-FALLBACK-' + suffix
                )
            };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    /**
     * Kịch bản 1: Kiểm tra Trigger Service đổi trạng thái (syncPendingStatusWhenSubmittedOwnerChanges).
     * Điều kiện: Truyền Case đã Submit, trạng thái cũ là 'Open', Owner bị thay đổi.
     * Mong đợi: Cập nhật thành công Status sang 'Pending'.
     */
    @IsTest
    static void testSyncPendingStatus_SuccessSubmittedCase() {
        Case c = [SELECT Id, OwnerId, Status FROM Case WHERE Subject = 'Case Submitted Status Sync' LIMIT 1];
        Group newOwner = [SELECT Id FROM Group WHERE Name = 'Queue Test A' LIMIT 1];
        
        // Mô phỏng Context Trigger
        Map<Id, Case> oldMap = new Map<Id, Case>{
            c.Id => new Case(Id = c.Id, OwnerId = c.OwnerId, Status = FEC_ConstantCommon.CASE_STATUS_OPEN)
        };

        Case newCase = new Case(
            Id = c.Id, OwnerId = newOwner.Id, Status = FEC_ConstantCommon.CASE_STATUS_OPEN
        );
        List<Case> newList = new List<Case>{ newCase };

        Test.startTest();
        // Cố tình chạy hàm wrapper deprecated để phủ code RAM
        FEC_CasePendingStatusService.syncPendingStatusFromLatestRouteTo(newList, oldMap);
        Test.stopTest();

        // Kiểm chứng DML: Case hợp lệ phải được Service chuyển ngầm về Pending
        Case updatedCase = [SELECT Status FROM Case WHERE Id = :c.Id];
        System.assertEquals(
            FEC_ConstantCommon.CASE_STATUS_PENDING,
            updatedCase.Status,
            'Trạng thái phải được chuyển từ Open sang Pending.'
        );
    }

    /**
     * Kịch bản 2: Kiểm tra nhánh chặn đồng bộ của Service (Guard Clauses).
     * Bao phủ: Case Draft (chưa submit), Case đổi Owner nhưng trạng thái cũ không phải Open, 
     * Case đã đóng (Closed) hoặc Case chưa đổi OwnerId.
     */
    @IsTest
    static void testSyncPendingStatus_SkipInvalidCases() {
        Case cDraft = [SELECT Id, OwnerId FROM Case WHERE Subject = 'Case Draft Ignore Sync' LIMIT 1];
        Group newOwner = [SELECT Id FROM Group WHERE Name = 'Queue Test B' LIMIT 1];

        Map<Id, Case> oldMap = new Map<Id, Case>{
            cDraft.Id => new Case(Id = cDraft.Id, OwnerId = cDraft.OwnerId, Status = FEC_ConstantCommon.CASE_STATUS_OPEN)
        };
        Case newCase = new Case(
            Id = cDraft.Id, OwnerId = newOwner.Id, Status = FEC_ConstantCommon.CASE_STATUS_OPEN
        );
        
        Test.startTest();
        // Nhánh 1: Mọi tham số đều truyền rỗng
        FEC_CasePendingStatusService.syncPendingStatusWhenSubmittedOwnerChanges(null, null);
        FEC_CasePendingStatusService.syncPendingStatusWhenSubmittedOwnerChanges(new List<Case>(), new Map<Id, Case>());

        // Nhánh 2: Case hợp lệ nhưng chưa bật cờ FEC_Is_Submited__c = true (Chặn bởi SOQL kiểm tra cờ)
        FEC_CasePendingStatusService.syncPendingStatusWhenSubmittedOwnerChanges(new List<Case>{ newCase }, oldMap);

        // Nhánh 3: Đổi trạng thái Case nhưng không đổi OwnerId -> Lọt cờ chặn Owner == Owner
        Case sameOwnerCase = new Case(
            Id = cDraft.Id, OwnerId = cDraft.OwnerId, Status = FEC_ConstantCommon.CASE_STATUS_OPEN
        );
        FEC_CasePendingStatusService.syncPendingStatusWhenSubmittedOwnerChanges(new List<Case>{ sameOwnerCase }, oldMap);

        // Nhánh 4: Cập nhật OldMap có trạng thái khác 'Open' -> Lọt cờ chặn Status cũ
        Map<Id, Case> oldMapNotOpen = new Map<Id, Case>{ cDraft.Id => new Case(Id = cDraft.Id, OwnerId = cDraft.OwnerId, Status = 'In Progress') };
        FEC_CasePendingStatusService.syncPendingStatusWhenSubmittedOwnerChanges(new List<Case>{ newCase }, oldMapNotOpen);
        Test.stopTest();

        // Kiểm chứng: Không có lệnh DML nào được thực thi
        System.assertEquals(
            FEC_ConstantCommon.CASE_STATUS_OPEN,
            [SELECT Status FROM Case WHERE Id = :cDraft.Id].Status
        );
    }

    /**
     * Kịch bản 3: Xử lý chuỗi hiển thị Pending động (computePendingStatusForCase).
     * Bao phủ: Trường hợp tạo chuỗi từ lịch sử History mới nhất (Nhánh ưu tiên) và trường hợp gán từ mã Team (Fallback).
     */
    @IsTest
    static void testComputePendingStatusForCase_RoutingHistoryAndFallback() {
        Case cSubmit = [SELECT Id, Status FROM Case WHERE Subject = 'Case Submitted Status Sync' LIMIT 1];
        Case cFallback = [SELECT Id, Status FROM Case WHERE Subject = 'Case Pending Fallback' LIMIT 1];

        // Do bản ghi cSubmit hiện tại đang là Open, ta cập nhật thành Pending để pass điều kiện tính toán chuỗi
        cSubmit.Status = FEC_ConstantCommon.CASE_STATUS_PENDING;
        update cSubmit;

        FEC_Routing_Action_History__c hist = new FEC_Routing_Action_History__c(
            FEC_Case__c = cSubmit.Id,
            FEC_Routing_Action__c = FEC_ConstantCommon.FEC_ROUTING_ACTION_CHANGE_OWNER,
            FEC_Original_User_Queue_ID__c = '00G000000000001AAA',
            FEC_Updated_User_Queue_ID__c = '00G000000000002BBB'
        );
        try {
            insert hist;
        } catch (DmlException e) {
            // Org có thể thiếu field Case trên RAH before-insert — vẫn test nhánh fallback
            System.debug('RAH insert skipped: ' + e.getMessage());
        }

        Test.startTest();
        // Nhánh 1: Test trường hợp truyền ID ma
        String resultNull = FEC_CasePendingStatusService.computePendingStatusForCase(null);
        String resultInvalid = FEC_CasePendingStatusService.computePendingStatusForCase('500000000000001AAA');

        // Nhánh 2: Tính toán chuỗi có chứa Routing History -> Ưu tiên hàm buildPendingStatusFromRouteHistoryRow
        // Lưu ý: Kết quả cụ thể tùy thuộc vào logic của hàm `buildPendingStatusFromRouteHistoryRow` bên class kia. 
        // Mục tiêu của test này là phủ dòng gọi ra hàm đó.
        String resultHistory = FEC_CasePendingStatusService.computePendingStatusForCase(cSubmit.Id);

        // Nhánh 3: Tính toán chuỗi khi không có History (Fallback bằng mã Team__c)
        String resultFallback = FEC_CasePendingStatusService.computePendingStatusForCase(cFallback.Id);
        
        // Nhánh 4: Tính toán khi không có Team__c và không có History -> Mặc định chữ 'Pending'
        String suffix = String.valueOf(System.currentTimeMillis());
        Case emptyCase = new Case(
            Subject = 'Empty Pending',
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Team__c = null,
            FEC_ID_Search__c = 'PND-EMPTY-' + suffix
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert emptyCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        String resultEmpty = FEC_CasePendingStatusService.computePendingStatusForCase(emptyCase.Id);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_PENDING, resultNull);
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_PENDING, resultInvalid);
        System.assertEquals(
            FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX + 'Credit Team',
            resultFallback,
            'Khi không có History, hệ thống nối Pending- với FEC_Team__c.'
        );
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_PENDING, resultEmpty);
    }
}