@IsTest
private class FEC_InsertCustomerDataQueueable_Test {

    private static Boolean hasContentVersionCommentsField() {
        return Schema.SObjectType.ContentVersion.fields.getMap()
            .containsKey('fec_comments__c');
    }

    @IsTest
    static void testInsertCustomerDataQueueable() {
        String suffix = String.valueOf(System.currentTimeMillis());

        FEC_CustomerAdditionalInfoConfig__c config = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_Status__c = FEC_ConstantCommon.PROCESSING_STATUS
        );
        insert config;

        ContentVersion cv = new ContentVersion(
            Title = 'Test Excel',
            PathOnClient = 'test.xlsx',
            VersionData = Blob.valueOf('Test Content')
        );
        insert cv;
        Id docId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ].ContentDocumentId;

        List<FEC_CustomerAdditionalInfo__c> dataList = new List<FEC_CustomerAdditionalInfo__c>();
        for (Integer i = 0; i < 10; i++) {
            dataList.add(new FEC_CustomerAdditionalInfo__c(
                FEC_CompositeKey__c = 'KEY_' + suffix + '_' + i,
                FEC_LinkedFilename__c = 'test_file_' + suffix
            ));
        }

        Set<Id> configIds = new Set<Id>{ config.Id };
        List<Id> cvIds = new List<Id>{ cv.Id };
        Set<Id> docIds = new Set<Id>{ docId };

        Test.startTest();
        System.enqueueJob(
            new FEC_InsertCustomerDataQueueable(dataList, configIds, cvIds, docIds)
        );
        Test.stopTest();

        FEC_CustomerAdditionalInfoConfig__c updatedConfig = [
            SELECT FEC_Status__c
            FROM FEC_CustomerAdditionalInfoConfig__c
            WHERE Id = :config.Id
        ];
        System.assertEquals(
            FEC_ConstantCommon.PROCESSED_STATUS,
            updatedConfig.FEC_Status__c
        );

        if (hasContentVersionCommentsField()) {
            ContentVersion updatedCv = [
                SELECT FEC_Comments__c
                FROM ContentVersion
                WHERE Id = :cv.Id
            ];
            System.assertEquals(
                FEC_ConstantCommon.PROCESSED_STATUS,
                updatedCv.FEC_Comments__c
            );
        }

        System.assertEquals(
            10,
            [SELECT COUNT() FROM FEC_CustomerAdditionalInfo__c WHERE FEC_CompositeKey__c LIKE :('KEY_' + suffix + '_%')]
        );

        List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE Id = :docId];
        System.assertEquals(0, docs.size(), 'JSON ContentDocument should be deleted.');
    }

    @IsTest
    static void testInsertWithError() {
        FEC_CustomerAdditionalInfoConfig__c config = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_Status__c = FEC_ConstantCommon.PROCESSING_STATUS
        );
        insert config;

        List<FEC_CustomerAdditionalInfo__c> dataList = new List<FEC_CustomerAdditionalInfo__c>{
            new FEC_CustomerAdditionalInfo__c(FEC_CompositeKey__c = null)
        };

        Test.startTest();
        System.enqueueJob(
            new FEC_InsertCustomerDataQueueable(
                dataList,
                new Set<Id>{ config.Id },
                null,
                null
            )
        );
        Test.stopTest();

        FEC_CustomerAdditionalInfoConfig__c failedConfig = [
            SELECT FEC_Status__c
            FROM FEC_CustomerAdditionalInfoConfig__c
            WHERE Id = :config.Id
        ];
        System.assertEquals(
            FEC_ConstantCommon.FAILURE_STATUS,
            failedConfig.FEC_Status__c
        );
    }
}
