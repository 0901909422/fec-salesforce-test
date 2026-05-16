// Script test assignment tự động và thủ công - kiểm tra OwnerId = null

// ============================================
// TEST 1: LUỒNG TỰ ĐỘNG (createAssignmentsOnRoute)
// ============================================
System.debug('========== TEST LUỒNG TỰ ĐỘNG ==========');

// Tìm 1 case để test
List<Case> testCases = [
    SELECT Id, CaseNumber, OwnerId, FEC_Assignment_Users__c, 
           FEC_Actual_Nature_of_Case__c
    FROM Case 
    WHERE RecordType.DeveloperName = 'FEC_Service_Case'
      AND IsClosed = false
      AND FEC_Actual_Nature_of_Case__c != null
    LIMIT 1
];

if (testCases.isEmpty()) {
    System.debug('ERROR: Không tìm thấy Service Case để test');
} else {
    Case testCase = testCases[0];
    System.debug('Test Case: ' + testCase.CaseNumber + ' (Id: ' + testCase.Id + ')');
    System.debug('Owner trước khi test: ' + testCase.OwnerId);
    System.debug('FEC_Assignment_Users__c trước: ' + testCase.FEC_Assignment_Users__c);
    
    // Lấy Nature of Case để test
    String nocId = testCase.FEC_Actual_Nature_of_Case__c;
    
    if (String.isBlank(nocId)) {
        System.debug('ERROR: Case không có Nature of Case');
    } else {
        System.debug('Nature of Case ID: ' + nocId);
        
        // Kiểm tra có Routing Assignment không
        List<FEC_Routing_Assignment__c> routingAssignments = [
            SELECT Id, FEC_Team__c, FEC_Queue__c, FEC_Nature_of_Cases__c
            FROM FEC_Routing_Assignment__c
            WHERE FEC_Nature_of_Cases__c = :nocId
              AND FEC_Active__c = true
              AND FEC_Team__c != null
              AND FEC_Queue__c != null
            LIMIT 3
        ];
        
        if (routingAssignments.isEmpty()) {
            System.debug('WARNING: Không có Routing Assignment cho NOC này');
            System.debug('Cần tạo Routing Assignment trước khi test');
        } else {
            System.debug('Tìm thấy ' + routingAssignments.size() + ' Routing Assignment(s)');
            for (FEC_Routing_Assignment__c ra : routingAssignments) {
                System.debug('  - Team: ' + ra.FEC_Team__c + ', Queue: ' + ra.FEC_Queue__c);
            }
            
            // Xóa assignment cũ nếu có
            List<FEC_Assignment__c> oldAssignments = [
                SELECT Id FROM FEC_Assignment__c 
                WHERE FEC_Case__c = :testCase.Id
            ];
            if (!oldAssignments.isEmpty()) {
                System.debug('Xóa ' + oldAssignments.size() + ' assignment cũ');
                delete oldAssignments;
            }
            
            // Gọi method tạo assignment tự động
            try {
                User currentUser = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId()];
                Set<Id> nocIds = new Set<Id>{nocId};
                
                System.debug('\n--- Gọi createAssignmentsOnRoute ---');
                FEC_CofGsrAssignmentService.createAssignmentsOnRoute(
                    testCase.Id, 
                    nocIds, 
                    currentUser, 
                    null, 
                    'Test Stage',
                    'Test remark for automatic assignment'
                );
                
                // Kiểm tra kết quả
                Case updatedCase = [
                    SELECT Id, OwnerId, FEC_Assignment_Users__c 
                    FROM Case 
                    WHERE Id = :testCase.Id
                ];
                
                System.debug('\n--- KẾT QUẢ LUỒNG TỰ ĐỘNG ---');
                System.debug('OwnerId sau khi tạo assignment: ' + updatedCase.OwnerId);
                System.debug('FEC_Assignment_Users__c: ' + updatedCase.FEC_Assignment_Users__c);
                
                if (updatedCase.OwnerId == null) {
                    System.debug('✅ PASS: OwnerId = null (đúng)');
                } else {
                    System.debug('❌ FAIL: OwnerId vẫn còn giá trị = ' + updatedCase.OwnerId);
                }
                
                // Kiểm tra assignment được tạo
                List<FEC_Assignment__c> newAssignments = [
                    SELECT Id, FEC_Assignment_Owner__c, FEC_OwnerID__c, FEC_Team__c, FEC_Manual__c
                    FROM FEC_Assignment__c
                    WHERE FEC_Case__c = :testCase.Id
                ];
                System.debug('Số assignment được tạo: ' + newAssignments.size());
                for (FEC_Assignment__c a : newAssignments) {
                    System.debug('  - Team: ' + a.FEC_Team__c + ', OwnerID: ' + a.FEC_OwnerID__c + ', Manual: ' + a.FEC_Manual__c);
                }
                
            } catch (Exception e) {
                System.debug('❌ ERROR: ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
            }
        }
    }
}

System.debug('\n\n========== TEST LUỒNG THỦ CÔNG ==========');

// ============================================
// TEST 2: LUỒNG THỦ CÔNG (createAssignmentsFromManualItems)
// ============================================

// Tìm case khác để test
List<Case> testCases2 = [
    SELECT Id, CaseNumber, OwnerId, FEC_Assignment_Users__c
    FROM Case 
    WHERE RecordType.DeveloperName = 'FEC_Service_Case'
      AND IsClosed = false
    LIMIT 1 OFFSET 1
];

if (testCases2.isEmpty()) {
    System.debug('WARNING: Dùng lại case đầu tiên');
    testCases2 = testCases;
}

if (!testCases2.isEmpty()) {
    Case testCase2 = testCases2[0];
    System.debug('Test Case: ' + testCase2.CaseNumber + ' (Id: ' + testCase2.Id + ')');
    System.debug('Owner trước khi test: ' + testCase2.OwnerId);
    
    // Xóa assignment cũ
    delete [SELECT Id FROM FEC_Assignment__c WHERE FEC_Case__c = :testCase2.Id];
    
    // Tạo manual items JSON
    String manualItemsJson = '[' +
        '{"teamName":"Test Team 1","queueName":"FEC_CC_Queue","remark":"Manual test remark 1"},' +
        '{"teamName":"Test Team 2","queueName":"FEC_CS_Support_Queue","remark":"Manual test remark 2"}' +
    ']';
    
    try {
        User currentUser = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId()];
        
        System.debug('\n--- Gọi createAssignmentsFromManualItems ---');
        FEC_CofGsrAssignmentService.createAssignmentsFromManualItems(
            testCase2.Id,
            manualItemsJson,
            currentUser,
            'Test Stage Manual'
        );
        
        // Kiểm tra kết quả
        Case updatedCase2 = [
            SELECT Id, OwnerId, FEC_Assignment_Users__c 
            FROM Case 
            WHERE Id = :testCase2.Id
        ];
        
        System.debug('\n--- KẾT QUẢ LUỒNG THỦ CÔNG ---');
        System.debug('OwnerId sau khi tạo assignment: ' + updatedCase2.OwnerId);
        System.debug('FEC_Assignment_Users__c: ' + updatedCase2.FEC_Assignment_Users__c);
        
        if (updatedCase2.OwnerId == null) {
            System.debug('✅ PASS: OwnerId = null (đúng)');
        } else {
            System.debug('❌ FAIL: OwnerId vẫn còn giá trị = ' + updatedCase2.OwnerId);
        }
        
        // Kiểm tra assignment được tạo
        List<FEC_Assignment__c> newAssignments2 = [
            SELECT Id, FEC_Assignment_Owner__c, FEC_OwnerID__c, FEC_Team__c, FEC_Manual__c
            FROM FEC_Assignment__c
            WHERE FEC_Case__c = :testCase2.Id
        ];
        System.debug('Số assignment được tạo: ' + newAssignments2.size());
        for (FEC_Assignment__c a : newAssignments2) {
            System.debug('  - Team: ' + a.FEC_Team__c + ', OwnerID: ' + a.FEC_OwnerID__c + ', Manual: ' + a.FEC_Manual__c);
        }
        
    } catch (Exception e) {
        System.debug('❌ ERROR: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
    }
}

System.debug('\n========== KẾT THÚC TEST ==========');
