// Script tạo assignment test để kiểm tra OwnerId = null

System.debug('========== TẠO ASSIGNMENT TEST ==========');

// Tìm Service Case
List<Case> cases = [
    SELECT Id, CaseNumber, OwnerId, FEC_Assignment_Users__c, FEC_Actual_Nature_of_Case__c
    FROM Case
    WHERE RecordType.DeveloperName = 'FEC_Service_Case'
      AND IsClosed = false
    LIMIT 1
];

if (cases.isEmpty()) {
    System.debug('❌ Không tìm thấy Service Case');
} else {
    Case c = cases[0];
    System.debug('✅ Tìm thấy Case: ' + c.CaseNumber + ' (ID: ' + c.Id + ')');
    System.debug('Owner trước: ' + c.OwnerId);
    System.debug('FEC_Assignment_Users__c trước: ' + c.FEC_Assignment_Users__c);
    
    // Xóa assignment cũ nếu có
    List<FEC_Assignment__c> oldAssignments = [
        SELECT Id FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id
    ];
    if (!oldAssignments.isEmpty()) {
        System.debug('Xóa ' + oldAssignments.size() + ' assignment cũ');
        delete oldAssignments;
    }
    
    // Tạo assignment thủ công (không cần NOC)
    System.debug('\n--- TẠO ASSIGNMENT THỦ CÔNG ---');
    
    // Tìm queue để test
    List<Group> queues = [
        SELECT Id, Name, DeveloperName 
        FROM Group 
        WHERE Type = 'Queue' 
          AND (DeveloperName = 'FEC_CC_Queue' OR DeveloperName = 'FEC_CS_Support_Queue')
        LIMIT 2
    ];
    
    if (queues.isEmpty()) {
        System.debug('❌ Không tìm thấy queue để test');
    } else {
        System.debug('Tìm thấy ' + queues.size() + ' queue(s)');
        
        // Tạo assignments
        List<FEC_Assignment__c> newAssignments = new List<FEC_Assignment__c>();
        for (Group q : queues) {
            System.debug('  - Queue: ' + q.Name + ' (ID: ' + q.Id + ')');
            newAssignments.add(new FEC_Assignment__c(
                FEC_Case__c = c.Id,
                FEC_Assignment_Name__c = 'Routing',
                FEC_Assignment_Type__c = 'Routing',
                FEC_Assignment_Status__c = 'Open',
                FEC_OwnerID__c = q.Name, // Lưu Queue Name
                FEC_Assignment_Owner__c = null,
                FEC_Team__c = 'Test Team',
                FEC_Assignment_Remark__c = 'Test assignment',
                FEC_Manual__c = true
            ));
        }
        
        insert newAssignments;
        System.debug('✅ Đã tạo ' + newAssignments.size() + ' assignment(s)');
        
        // Cập nhật Case.OwnerId = null và FEC_Assignment_Users__c
        List<String> queueIds = new List<String>();
        for (Group q : queues) {
            queueIds.add(String.valueOf(q.Id));
        }
        
        System.debug('\n--- CẬP NHẬT CASE ---');
        System.debug('Set OwnerId = null');
        System.debug('Set FEC_Assignment_Users__c = ' + String.join(queueIds, ','));
        
        Database.update(new Case(
            Id = c.Id,
            OwnerId = null,
            FEC_Assignment_Users__c = String.join(queueIds, ',')
        ), AccessLevel.SYSTEM_MODE);
        
        // Kiểm tra kết quả
        Case updatedCase = [
            SELECT Id, CaseNumber, OwnerId, FEC_Assignment_Users__c
            FROM Case
            WHERE Id = :c.Id
        ];
        
        System.debug('\n--- KẾT QUẢ ---');
        System.debug('Case: ' + updatedCase.CaseNumber);
        System.debug('OwnerId sau: ' + updatedCase.OwnerId);
        System.debug('FEC_Assignment_Users__c sau: ' + updatedCase.FEC_Assignment_Users__c);
        
        if (updatedCase.OwnerId == null) {
            System.debug('✅ PASS: OwnerId = null (đúng)');
        } else {
            System.debug('❌ FAIL: OwnerId vẫn = ' + updatedCase.OwnerId);
            System.debug('❌ LỖI: Service case owner phải null khi có assignment!');
        }
        
        if (String.isNotBlank(updatedCase.FEC_Assignment_Users__c)) {
            System.debug('✅ PASS: FEC_Assignment_Users__c đã được set');
        } else {
            System.debug('❌ FAIL: FEC_Assignment_Users__c chưa được set');
        }
    }
}

System.debug('\n========== KẾT THÚC ==========');
