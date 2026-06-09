@IsTest
private class FEC_RelevantTicketController_Test {

    @TestSetup
    static void setupData() {
        // Tạo Stage
        FEC_Case_Stage__c stage1 = new FEC_Case_Stage__c(Name = 'Stage 1', FEC_Code__c = 'S1');
        insert stage1;

        // Tạo Cases
        Case c1 = new Case(Subject = 'Case 1', FEC_Current_Case_Stage__c = stage1.Id);
        Case c2 = new Case(Subject = 'Case 2', FEC_Current_Case_Stage__c = stage1.Id);
        insert new List<Case>{c1, c2};
    }

    @IsTest
    static void testGetRelevantTickets_Success() {
        Case c1 = [SELECT Id FROM Case WHERE Subject = 'Case 1' LIMIT 1];
        Case c2 = [SELECT Id FROM Case WHERE Subject = 'Case 2' LIMIT 1];

        // Tạo ticket liên kết
        FEC_Relevant_Ticket__c rt = new FEC_Relevant_Ticket__c(
            FEC_Related_To__c = c1.Id, 
            FEC_Interaction__c = c2.Id
        );
        insert rt;

        Test.startTest();
        // Test query 2 chiều
        List<FEC_Relevant_Ticket__c> res1 = FEC_RelevantTicketController.getRelevantTickets(c1.Id);
        List<FEC_Relevant_Ticket__c> res2 = FEC_RelevantTicketController.getRelevantTickets(c2.Id);
        Test.stopTest();

        System.assertEquals(1, res1.size());
        System.assertEquals(1, res2.size());
    }

    @IsTest
    static void testCreateAndStageCode() {
        Case c1 = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        Id rtId = FEC_RelevantTicketController.createRelevantTicket(c1.Id, c1.Id);
        Test.stopTest();

        FEC_Relevant_Ticket__c rt = [SELECT FEC_Stage_Name__c FROM FEC_Relevant_Ticket__c WHERE Id = :rtId];
        System.assertEquals('S1', rt.FEC_Stage_Name__c, 'Stage code phải được lưu từ Case.');
    }

    @IsTest
    static void testDeleteRelevantTicket_Logic() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        // Tạo ticket có stage S1
        FEC_Relevant_Ticket__c rt = new FEC_Relevant_Ticket__c(
            FEC_Interaction__c = c.Id, 
            FEC_Stage_Name__c = 'S1'
        );
        insert rt;

        Test.startTest();
        // Xóa thành công (cùng stage)
        FEC_RelevantTicketController.deleteRelevantTicket(rt.Id);
        
        // Test chặn xóa (khác stage)
        FEC_Relevant_Ticket__c rt2 = new FEC_Relevant_Ticket__c(
            FEC_Interaction__c = c.Id, 
            FEC_Stage_Name__c = 'OLD_STAGE'
        );
        insert rt2;
        
        try {
            FEC_RelevantTicketController.deleteRelevantTicket(rt2.Id);
            System.assert(false, 'Phải chặn xóa nếu khác stage.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testSearchAndGetCase() {
        Case c = [SELECT Id, CaseNumber FROM Case WHERE Subject = 'Case 1' LIMIT 1];

        Test.startTest();
        // Test tìm kiếm
        List<Map<String, String>> searchRes = FEC_RelevantTicketController.searchCases(c.CaseNumber.substring(0, 3));
        // Test get by Id
        Map<String, String> caseRes = FEC_RelevantTicketController.getCaseById(c.Id);
        Test.stopTest();

        System.assert(searchRes.size() > 0);
        System.assertEquals(c.Id, caseRes.get('id'));
    }
}