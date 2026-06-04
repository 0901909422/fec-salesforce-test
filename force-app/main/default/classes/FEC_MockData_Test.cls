@IsTest
private class FEC_MockData_Test {

    @IsTest
    static void testGetHardcodedCardInfo() {
        Test.startTest();
        FEC_CardInfoController.CardInfoDTO dto = FEC_MockData.getHardcodedCardInfo();
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO CardInfo không được null.');
        System.assert(dto.cardDeliveries.size() >= 6, 'Phải có ít nhất 6 bản ghi Card Delivery mẫu.');
        System.assert(dto.otherCards.size() >= 3, 'Phải có ít nhất 3 bản ghi Other Cards mẫu.');
    }

    @IsTest
    static void testGetHardcodedCardPaymentRecordsForUI() {
        Test.startTest();
        List<Map<String, Object>> records = FEC_MockData.getHardcodedCardPaymentRecordsForUI();
        Test.stopTest();

        System.assertEquals(2, records.size(), 'Phải trả về đúng 2 bản ghi Card Payment demo.');
        System.assert(records[0].containsKey('FEC_Current_Balance__c'), 'Phải chứa trường Current Balance.');
    }

    @IsTest
    static void testGetHardcodedIPPRecordsForUI() {
        Test.startTest();
        List<FEC_IPPController.IPPRecordDTO> ipps = FEC_MockData.getHardcodedIPPRecordsForUI();
        Test.stopTest();

        System.assert(ipps.size() >= 20, 'Phải trả về đủ 20 bản ghi IPP mock.');
        System.assertNotEquals(null, ipps[0].Id, 'ID của IPP record không được null.');
    }

    @IsTest
    static void testGetHardcodedIPPScheduleDataForUI() {
        Test.startTest();
        // Test với ippRecord = null để lấy placeholder
        Map<String, Object> scheduleData = FEC_MockData.getHardcodedIPPScheduleDataForUI(null);
        Test.stopTest();

        System.assertNotEquals(null, scheduleData.get('schedules'), 'Phải chứa danh sách lịch trả nợ.');
        System.assertNotEquals(null, scheduleData.get('ippRecord'), 'Phải có ippRecord mẫu.');
    }
}