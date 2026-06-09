@IsTest
private class FEC_CaseAssignmentConflictService_Test {

    private static Id getBusinessHoursId() {
        return [SELECT Id FROM BusinessHours LIMIT 1].Id;
    }

    private static FEC_Case_Assignment_NOC__c getNocTemplate() {
        return [
            SELECT
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_Sub_Category__c,
                FEC_Sub_Code__c
            FROM FEC_Case_Assignment_NOC__c
            LIMIT 1
        ];
    }

    @TestSetup
    static void setupData() {
        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'CC',
            FEC_Active__c = true
        );
        insert prod;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Request',
            FEC_Code__c = 'Request',
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'RC27',
            FEC_Code__c = 'RC27',
            FEC_Active__c = true
        );
        insert subCat;
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'RC27.01',
            FEC_Code__c = 'RC27.01',
            FEC_Active__c = true
        );
        insert subCode;

        Id businessHoursId = getBusinessHoursId();
        FEC_Case_Assignment__c existingAssignment = new FEC_Case_Assignment__c(
            Name = 'Existing Active Rule',
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = businessHoursId,
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = 'CS Agent A|1',
            FEC_Scale__c = 1,
            FEC_Select_Queues__c = 'Queue Card Processing',
            FEC_Status__c = 'Draft'
        );
        FEC_Case_Assignment__c conflictAssignment = new FEC_Case_Assignment__c(
            Name = 'New Conflict Rule',
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = businessHoursId,
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = 'CS Agent A|1;CS Agent B|1',
            FEC_Scale__c = 1,
            FEC_Select_Queues__c = 'Queue Card Processing;Queue VIP Customer',
            FEC_Status__c = 'Draft'
        );
        FEC_Case_Assignment__c cleanAssignment = new FEC_Case_Assignment__c(
            Name = 'New Clean Rule',
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = businessHoursId,
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = 'CS Agent A|1',
            FEC_Scale__c = 1,
            FEC_Select_Queues__c = 'Queue Digital Support',
            FEC_Status__c = 'Draft'
        );
        insert new List<FEC_Case_Assignment__c>{
            existingAssignment,
            conflictAssignment,
            cleanAssignment
        };

        insert new FEC_Case_Assignment_NOC__c(
            FEC_Case_Assignment_Name__c = existingAssignment.Id,
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id
        );

        existingAssignment.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update existingAssignment;
    }

    /**
     * Kịch bản 1: Thêm mới bản ghi NOC hoàn toàn hợp lệ, không dính hàng đợi (Queue) trùng lặp.
     * Mong đợi: Tiến trình chạy qua trơn tru, không phát sinh bất kỳ thông báo lỗi chặn `addError` nào.
     */
    @IsTest
    static void testValidateNocConflicts_NoConflictSuccess() {
        FEC_Case_Assignment__c cleanAssign = [SELECT Id FROM FEC_Case_Assignment__c WHERE Name = 'New Clean Rule' LIMIT 1];
        FEC_Case_Assignment_NOC__c template = getNocTemplate();

        List<FEC_Case_Assignment_NOC__c> newList = new List<FEC_Case_Assignment_NOC__c>{
            new FEC_Case_Assignment_NOC__c(
                FEC_Case_Assignment_Name__c = cleanAssign.Id,
                FEC_Product_Type__c = template.FEC_Product_Type__c,
                FEC_Category__c = template.FEC_Category__c,
                FEC_Sub_Category__c = template.FEC_Sub_Category__c,
                FEC_Sub_Code__c = template.FEC_Sub_Code__c
            )
        };

        Test.startTest();
        FEC_CaseAssignmentConflictService.validateNocConflicts(newList, null); // oldMap = null giả lập tầng Insert
        Test.stopTest();

        // Xác minh: Bản ghi không bị gắn cờ lỗi đánh dấu của Salesforce (.hasErrors())
        System.assertEquals(false, newList[0].hasErrors(), 'Bản ghi NOC hợp lệ không được phép dính lỗi chặn.');
    }

    /**
     * Kịch bản 2: Chèn mới bản ghi NOC bị XUNG ĐỘT (Trùng cả cụm NOC định danh và giao nhau ít nhất 1 tên Queue).
     * Mong đợi: Hệ thống phát hiện giao thoa trùng lặp tại Queue 'queue card processing' viết thường, kích hoạt addError.
     */
    @IsTest
    static void testValidateNocConflicts_TriggerOverlapError() {
        FEC_Case_Assignment__c conflictAssign = [SELECT Id FROM FEC_Case_Assignment__c WHERE Name = 'New Conflict Rule' LIMIT 1];
        FEC_Case_Assignment_NOC__c template = getNocTemplate();

        List<FEC_Case_Assignment_NOC__c> newList = new List<FEC_Case_Assignment_NOC__c>{
            new FEC_Case_Assignment_NOC__c(
                FEC_Case_Assignment_Name__c = conflictAssign.Id,
                FEC_Product_Type__c = template.FEC_Product_Type__c,
                FEC_Category__c = template.FEC_Category__c,
                FEC_Sub_Category__c = template.FEC_Sub_Category__c,
                FEC_Sub_Code__c = template.FEC_Sub_Code__c
            )
        };

        Test.startTest();
        FEC_CaseAssignmentConflictService.validateNocConflicts(newList, null);
        Test.stopTest();

        // Xác minh: Hệ thống đã chặn thành công và ném lỗi addError
        System.assertEquals(true, newList[0].hasErrors(), 'Bản ghi dính trùng quy tắc phân bổ bắt buộc phải bị addError.');
    }

    /**
     * Kịch bản 3: Cập nhật sửa đổi bản ghi NOC (Kịch bản Trigger Before Update).
     * Bao phủ: Khối logic so sánh `oldMap` trường `isRelevantChange` (Thay đổi loại sản phẩm, mã phân nhóm, mã code con).
     */
    @IsTest
    static void testValidateNocConflicts_UpdateRelevantChanges() {
        FEC_Case_Assignment__c cleanAssign = [SELECT Id FROM FEC_Case_Assignment__c WHERE Name = 'New Clean Rule' LIMIT 1];
        FEC_Case_Assignment_NOC__c template = getNocTemplate();

        FEC_Case_Assignment_NOC__c oldNoc = new FEC_Case_Assignment_NOC__c(
            FEC_Case_Assignment_Name__c = cleanAssign.Id,
            FEC_Product_Type__c = template.FEC_Product_Type__c,
            FEC_Category__c = template.FEC_Category__c,
            FEC_Sub_Category__c = template.FEC_Sub_Category__c,
            FEC_Sub_Code__c = null
        );
        insert oldNoc;

        FEC_Case_Assignment_NOC__c updatedNoc = new FEC_Case_Assignment_NOC__c(
            Id = oldNoc.Id,
            FEC_Case_Assignment_Name__c = cleanAssign.Id,
            FEC_Product_Type__c = template.FEC_Product_Type__c,
            FEC_Category__c = template.FEC_Category__c,
            FEC_Sub_Category__c = template.FEC_Sub_Category__c,
            FEC_Sub_Code__c = template.FEC_Sub_Code__c
        );

        Map<Id, FEC_Case_Assignment_NOC__c> oldMap = new Map<Id, FEC_Case_Assignment_NOC__c>{ oldNoc.Id => oldNoc };
        List<FEC_Case_Assignment_NOC__c> newList = new List<FEC_Case_Assignment_NOC__c>{ updatedNoc };

        Test.startTest();
        FEC_CaseAssignmentConflictService.validateNocConflicts(newList, oldMap);
        Test.stopTest();

        System.assertEquals(false, newList[0].hasErrors(), 'Luật sạch sửa đổi liên quan vẫn pass mượt mà.');
    }

    /**
     * Kịch bản 4: Cập nhật sửa đổi bản ghi NOC nhưng KHÔNG thay đổi bất kỳ trường nghiệp vụ lõi nào.
     * Mong đợi: Hàm `isRelevantChange` phát hiện không có biến động, câu lệnh `continue` được kích hoạt để bỏ qua sớm, tối ưu hóa hiệu năng.
     */
    @IsTest
    static void testValidateNocConflicts_UpdateNoRelevantChanges() {
        FEC_Case_Assignment__c cleanAssign = [SELECT Id FROM FEC_Case_Assignment__c WHERE Name = 'New Clean Rule' LIMIT 1];
        FEC_Case_Assignment_NOC__c template = getNocTemplate();

        FEC_Case_Assignment_NOC__c oldNoc = new FEC_Case_Assignment_NOC__c(
            FEC_Case_Assignment_Name__c = cleanAssign.Id,
            FEC_Product_Type__c = template.FEC_Product_Type__c,
            FEC_Category__c = template.FEC_Category__c,
            FEC_Sub_Category__c = template.FEC_Sub_Category__c
        );
        insert oldNoc;

        FEC_Case_Assignment_NOC__c updatedNoc = new FEC_Case_Assignment_NOC__c(
            Id = oldNoc.Id,
            FEC_Case_Assignment_Name__c = cleanAssign.Id,
            FEC_Product_Type__c = template.FEC_Product_Type__c,
            FEC_Category__c = template.FEC_Category__c,
            FEC_Sub_Category__c = template.FEC_Sub_Category__c
        );

        Map<Id, FEC_Case_Assignment_NOC__c> oldMap = new Map<Id, FEC_Case_Assignment_NOC__c>{ oldNoc.Id => oldNoc };
        List<FEC_Case_Assignment_NOC__c> newList = new List<FEC_Case_Assignment_NOC__c>{ updatedNoc };

        Test.startTest();
        FEC_CaseAssignmentConflictService.validateNocConflicts(newList, oldMap);
        Test.stopTest();

        System.assertEquals(false, newList[0].hasErrors());
    }

    /**
     * Kịch bản 5: Kiểm tra các dải điều kiện biên xử lý chuỗi Queue trống ký tự hoặc sai cấu trúc phân tách (Split Utility Edge Cases).
     * Bao phủ: Trường hợp `FEC_Select_Queues__c` nhận chuỗi null, chuỗi rỗng, hoặc dấu phân tách thừa thãi.
     */
    @IsTest
    static void testValidateNocConflicts_QueueRawValueEdgeCases() {
        // Tạo một luật Active nhưng để trống hoàn toàn danh sách chuỗi hàng đợi tuyển chọn
        FEC_Case_Assignment__c emptyQueueAssign = new FEC_Case_Assignment__c(
            Name = 'Empty Queue Assignment Rule',
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = getBusinessHoursId(),
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = 'CS Agent A|1',
            FEC_Scale__c = 1,
            FEC_Select_Queues__c = ' ; , \n ',
            FEC_Status__c = 'Draft'
        );
        insert emptyQueueAssign;

        FEC_Case_Assignment_NOC__c template = getNocTemplate();
        insert new FEC_Case_Assignment_NOC__c(
            FEC_Case_Assignment_Name__c = emptyQueueAssign.Id,
            FEC_Product_Type__c = template.FEC_Product_Type__c,
            FEC_Category__c = template.FEC_Category__c,
            FEC_Sub_Category__c = template.FEC_Sub_Category__c
        );

        emptyQueueAssign.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update emptyQueueAssign;

        List<FEC_Case_Assignment_NOC__c> newList = new List<FEC_Case_Assignment_NOC__c>{
            new FEC_Case_Assignment_NOC__c(
                FEC_Case_Assignment_Name__c = emptyQueueAssign.Id,
                FEC_Product_Type__c = template.FEC_Product_Type__c,
                FEC_Category__c = template.FEC_Category__c,
                FEC_Sub_Category__c = template.FEC_Sub_Category__c
            )
        };

        Test.startTest();
        FEC_CaseAssignmentConflictService.validateNocConflicts(newList, null);
        
        // Guard clause: Truyền danh sách rỗng đầu vào bảo vệ biên
        FEC_CaseAssignmentConflictService.validateNocConflicts(new List<FEC_Case_Assignment_NOC__c>(), null);
        Test.stopTest();

        System.assertEquals(false, newList[0].hasErrors(), 'Hàng đợi trống ký tự thô sẽ được hàm extractQueues bỏ qua an toàn.');
    }
}