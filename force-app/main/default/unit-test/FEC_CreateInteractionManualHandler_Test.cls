@IsTest
private class FEC_CreateInteractionManualHandler_Test {

    @IsTest
    static void testCreateInteractionManual_Success() {
        // 1. Chuẩn bị dữ liệu đầu vào
        String channel = 'Inbound';
        String subChannel = 'Inbound Call';

        // 2. Gọi phương thức
        Test.startTest();
        FEC_CreateInteractionManualHandler.CreateInteractionManualResponse response = 
            FEC_CreateInteractionManualHandler.createInteractionManual(channel, subChannel);
        Test.stopTest();

        // 3. Kiểm tra kết quả
        // Vì FEC_CreateCaseHandler.createInteractionCaseManual thực hiện insert Case, 
        // chúng ta sẽ kiểm tra xem Case có được tạo trong database không
        System.assertNotEquals(null, response.caseId, 'CaseId không được null.');
        
        Case createdCase = [SELECT Id, FEC_Channel__c, FEC_Interaction_Subchannel__c FROM Case WHERE Id = :response.caseId];
        System.assertEquals(channel, createdCase.FEC_Channel__c, 'Channel phải khớp với tham số truyền vào.');
        System.assertEquals(subChannel, createdCase.FEC_Interaction_Subchannel__c, 'SubChannel phải khớp với tham số truyền vào.');
    }

    @IsTest
    static void testCreateInteractionManual_NullValues() {
        // Kiểm tra trường hợp dữ liệu rỗng (nếu handler xử lý được)
        Test.startTest();
        FEC_CreateInteractionManualHandler.CreateInteractionManualResponse response = 
            FEC_CreateInteractionManualHandler.createInteractionManual(null, null);
        Test.stopTest();

        System.assertNotEquals(null, response.caseId, 'Case vẫn nên được tạo ngay cả khi channel null.');
    }
}