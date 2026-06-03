@IsTest
private class FEC_RelevantTicketTriggerHandler_Test {

    @TestSetup
    static void setupData() {
        // 1. Tạo Stage
        FEC_Case_Stage__c stage1 = new FEC_Case_Stage__c(Name = 'Stage 1', FEC_Code__c = 'S1');
        insert stage1;

        // 2. Tạo Case
        Case c = new Case(Subject = 'Test Case', FEC_Current_Case_Stage__c = stage1.Id);
        insert c;
    }

    @IsTest
    static void testBeforeDelete_Allowed() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        // Tạo ticket có stage khớp với stage của Case (S1)
        FEC_Relevant_Ticket__c rt = new FEC_Relevant_Ticket__c(
            FEC_Interaction__c = c.Id,
            FEC_Stage_Name__c = 'S1'
        );
        insert rt;

        Test.startTest();
        Database.DeleteResult dr = Database.delete(rt, false);
        Test.stopTest();

        System.assert(dr.isSuccess(), 'Ticket cùng stage phải được phép xóa.');
    }

    @IsTest
    static void testBeforeDelete_Blocked() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        // Tạo ticket có stage cũ (khác 'S1')
        FEC_Relevant_Ticket__c rt = new FEC_Relevant_Ticket__c(
            FEC_Interaction__c = c.Id,
            FEC_Stage_Name__c = 'OLD_STAGE'
        );
        insert rt;

        Test.startTest();
        Database.DeleteResult dr = Database.delete(rt, false);
        Test.stopTest();

        System.assert(!dr.isSuccess(), 'Ticket khác stage phải bị chặn xóa.');
        System.assertEquals(
            StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
            dr.getErrors()[0].getStatusCode()
        );
    }

    @IsTest
    static void testBeforeDelete_NoStageCase() {
        // Tạo Case không có stage
        Case c2 = new Case(Subject = 'No Stage Case');
        insert c2;
        
        FEC_Relevant_Ticket__c rt = new FEC_Relevant_Ticket__c(
            FEC_Interaction__c = c2.Id,
            FEC_Stage_Name__c = 'ANY'
        );
        insert rt;

        Test.startTest();
        Database.DeleteResult dr = Database.delete(rt, false);
        Test.stopTest();

        System.assert(dr.isSuccess(), 'Case không có workflow/stage thì được phép xóa tự do.');
    }
}