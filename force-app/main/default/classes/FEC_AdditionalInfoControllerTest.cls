/**
 * @description Test class cho FEC_AdditionalInfoController.
 *              Kiểm tra truy vấn dữ liệu FEC_Additional_Info__c với FLS, sorting, và limit.
 * @author      DAT NGO
 * @date        2026-06-02
 * @module      MDM
 */
@IsTest
private class FEC_AdditionalInfoControllerTest {

    /**
     * @description Helper tạo Case + FEC_Additional_Info__c records.
     * @param count Số lượng FEC_Additional_Info__c cần tạo
     * @return List<FEC_Additional_Info__c> records đã insert
     */
    private static List<FEC_Additional_Info__c> createTestRecords(Integer count) {
        Case testCase = new Case(Subject = 'Test Case for Additional Info');
        insert testCase;

        List<FEC_Additional_Info__c> records = new List<FEC_Additional_Info__c>();
        for (Integer i = 0; i < count; i++) {
            records.add(new FEC_Additional_Info__c(
                FEC_Case__c = testCase.Id,
                FEC_Callback__c = 'Yes',
                FEC_Gender__c = 'M'
            ));
        }
        insert records;
        return records;
    }

    /**
     * @description Test trả về dữ liệu thành công với đúng fields.
     */
    @IsTest
    static void testGetAdditionalInfoRecords_WithData() {
        List<FEC_Additional_Info__c> inserted = createTestRecords(3);

        Test.startTest();
        List<FEC_Additional_Info__c> results = FEC_AdditionalInfoController.getAdditionalInfoRecords();
        Test.stopTest();

        Assert.areEqual(3, results.size(), 'Should return 3 records');
        // Verify fields are populated (stripInaccessible may remove some, but Name and FEC_Case__c should be present)
        for (FEC_Additional_Info__c rec : results) {
            Map<String, Object> populated = rec.getPopulatedFieldsAsMap();
            Assert.isTrue(populated.containsKey('Name'), 'Name field should be present');
            Assert.isTrue(populated.containsKey('FEC_Case__c'), 'FEC_Case__c field should be present');
        }
    }

    /**
     * @description Test trả về list rỗng khi không có data.
     */
    @IsTest
    static void testGetAdditionalInfoRecords_EmptyResult() {
        Test.startTest();
        List<FEC_Additional_Info__c> results = FEC_AdditionalInfoController.getAdditionalInfoRecords();
        Test.stopTest();

        Assert.isTrue(results.isEmpty(), 'Should return empty list when no records exist');
    }

    /**
     * @description Test giới hạn kết quả tối đa 200 bản ghi.
     */
    @IsTest
    static void testGetAdditionalInfoRecords_Limit200() {
        createTestRecords(210);

        Test.startTest();
        List<FEC_Additional_Info__c> results = FEC_AdditionalInfoController.getAdditionalInfoRecords();
        Test.stopTest();

        Assert.isTrue(results.size() <= 200, 'Should return at most 200 records, got: ' + results.size());
    }

    /**
     * @description Test sắp xếp theo CreatedDate giảm dần.
     */
    @IsTest
    static void testGetAdditionalInfoRecords_SortOrder() {
        createTestRecords(5);

        Test.startTest();
        List<FEC_Additional_Info__c> results = FEC_AdditionalInfoController.getAdditionalInfoRecords();
        Test.stopTest();

        Assert.isFalse(results.isEmpty(), 'Should have results');
        // Verify DESC order: each record's CreatedDate >= next record's CreatedDate
        for (Integer i = 0; i < results.size() - 1; i++) {
            Assert.isTrue(
                results[i].CreatedDate >= results[i + 1].CreatedDate,
                'Records should be sorted by CreatedDate DESC. Index ' + i + ': ' +
                results[i].CreatedDate + ' should be >= ' + results[i + 1].CreatedDate
            );
        }
    }

    @IsTest
    static void testDeleteRecord_NullId() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_AdditionalInfoController.deleteRecord(null);
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'null Id phải throw');
    }

    @IsTest
    static void testDeleteRecord_Success() {
        List<FEC_Additional_Info__c> recs = createTestRecords(1);
        Id recId = recs[0].Id;

        Test.startTest();
        FEC_AdditionalInfoController.deleteRecord(recId);
        Test.stopTest();

        Integer remaining = [SELECT COUNT() FROM FEC_Additional_Info__c WHERE Id = :recId];
        Assert.areEqual(0, remaining);
    }
}