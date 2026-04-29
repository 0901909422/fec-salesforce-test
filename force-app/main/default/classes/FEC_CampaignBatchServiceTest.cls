/**
 * FEC_CampaignBatchServiceTest
 * Tests for FEC_CampaignBatchService — chunking, evaluateCallStatus, query builders.
 * Validates: Requirements 1.4, 2.2, 3.3, 10.2, 10.3, 10.4
 */
@isTest
private class FEC_CampaignBatchServiceTest {

    // Feature: campaign-module-refactor, Property 1: Chunking bảo toàn dữ liệu và tuân thủ giới hạn kích thước
    // **Validates: Requirements 1.4, 2.2**
    @isTest
    static void testChunkBySize_PreservesDataAndRespectsLimit() {
        for (Integer i = 0; i < 100; i++) {
            Integer listSize = Math.mod(Math.abs(Crypto.getRandomInteger()), 20) + 1;
            // Random maxJsonSize between 1KB and 100KB (keep small for governor limits)
            Integer maxJsonSize = Math.mod(Math.abs(Crypto.getRandomInteger()), 99000) + 1000;

            List<FEC_DataCampaign> models = new List<FEC_DataCampaign>();
            for (Integer j = 0; j < listSize; j++) {
                models.add(buildRandomDto());
            }

            List<List<FEC_DataCampaign>> chunks = FEC_CampaignBatchService.chunkBySize(models, maxJsonSize);

            // (a) Each chunk JSON size <= maxJsonSize
            for (List<FEC_DataCampaign> chunk : chunks) {
                Integer chunkSize = Blob.valueOf(JSON.serialize(chunk)).size();
                Assert.isTrue(chunkSize <= maxJsonSize || chunk.size() == 1,
                    'Chunk size ' + chunkSize + ' exceeds limit ' + maxJsonSize +
                    ' with ' + chunk.size() + ' items on iteration ' + i);
            }

            // (b) Concatenated chunks == original list (order + content)
            List<FEC_DataCampaign> reassembled = new List<FEC_DataCampaign>();
            for (List<FEC_DataCampaign> chunk : chunks) {
                reassembled.addAll(chunk);
            }
            Assert.areEqual(models.size(), reassembled.size(),
                'Reassembled size mismatch on iteration ' + i);
            for (Integer k = 0; k < models.size(); k++) {
                Assert.areEqual(
                    JSON.serialize(models[k]),
                    JSON.serialize(reassembled[k]),
                    'Data mismatch at index ' + k + ' on iteration ' + i
                );
            }
        }
    }

    // Feature: campaign-module-refactor, Property 7: evaluateCallStatus mapping nhất quán
    // **Validates: Requirements 3.3**
    @isTest
    static void testEvaluateCallStatus_ConsistentMapping() {
        // Known mappings
        Map<String, String> knownMappings = new Map<String, String>{
            '33' => FEC_Constants.CAMPAIGN_STATUS_RESOLVED_COMPLETED,
            '9'  => FEC_Constants.CAMPAIGN_STATUS_RESOLVED_COMPLETED,
            '52' => FEC_Constants.CAMPAIGN_STATUS_RESOLVED_CANCELLED,
            '51' => FEC_Constants.CAMPAIGN_STATUS_RESOLVED_CANCELLED,
            '47' => FEC_Constants.CAMPAIGN_STATUS_PENDING_CALLBACK,
            '48' => FEC_Constants.CAMPAIGN_STATUS_PENDING_CALLBACK,
            '4'  => FEC_Constants.CAMPAIGN_STATUS_PENDING_CALLBACK
        };

        // Test known codes
        for (String code : knownMappings.keySet()) {
            String result = FEC_CampaignBatchService.evaluateCallStatus(code);
            Assert.areEqual(knownMappings.get(code), result,
                'Known code ' + code + ' should map to ' + knownMappings.get(code));
        }

        // Test null and blank → Pending-Retry
        Assert.areEqual(FEC_Constants.CAMPAIGN_STATUS_PENDING_RETRY,
            FEC_CampaignBatchService.evaluateCallStatus(null));
        Assert.areEqual(FEC_Constants.CAMPAIGN_STATUS_PENDING_RETRY,
            FEC_CampaignBatchService.evaluateCallStatus(''));

        Set<String> validStatuses = new Set<String>{
            FEC_Constants.CAMPAIGN_STATUS_RESOLVED_COMPLETED,
            FEC_Constants.CAMPAIGN_STATUS_RESOLVED_CANCELLED,
            FEC_Constants.CAMPAIGN_STATUS_PENDING_CALLBACK,
            FEC_Constants.CAMPAIGN_STATUS_PENDING_RETRY
        };

        // 100 random codes — result must always be one of the valid statuses
        for (Integer i = 0; i < 100; i++) {
            String randomCode = String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 200));
            String result = FEC_CampaignBatchService.evaluateCallStatus(randomCode);
            Assert.isTrue(validStatuses.contains(result),
                'Random code ' + randomCode + ' returned invalid status: ' + result);

            // If it's a known code, verify exact mapping
            if (knownMappings.containsKey(randomCode)) {
                Assert.areEqual(knownMappings.get(randomCode), result);
            }
        }
    }

    // Feature: campaign-module-refactor, Property 6: Query builder tạo đúng filter theo ngày trong tuần
    // **Validates: Requirements 10.2, 10.3, 10.4**
    @isTest
    static void testBuildScheduledQuery_CorrectFilterByDay() {
        String fields = 'Id, FEC_AppId__c';

        // Saturday
        String satQuery = FEC_CampaignBatchService.buildScheduledQuery(fields, 'Saturday');
        Assert.isTrue(satQuery.contains('FEC_SaturdaySchedule__c = true'),
            'Saturday query must contain Saturday filter');
        Assert.isFalse(satQuery.contains('FEC_SundaySchedule__c = true'),
            'Saturday query must NOT contain Sunday filter');

        // Sunday
        String sunQuery = FEC_CampaignBatchService.buildScheduledQuery(fields, 'Sunday');
        Assert.isTrue(sunQuery.contains('FEC_SundaySchedule__c = true'),
            'Sunday query must contain Sunday filter');
        Assert.isFalse(sunQuery.contains('FEC_SaturdaySchedule__c = true'),
            'Sunday query must NOT contain Saturday filter');

        // Weekdays — neither Saturday nor Sunday filter
        List<String> weekdays = new List<String>{
            'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'
        };
        for (String day : weekdays) {
            String query = FEC_CampaignBatchService.buildScheduledQuery(fields, day);
            Assert.isFalse(query.contains('FEC_SaturdaySchedule__c = true'),
                day + ' query must NOT contain Saturday filter');
            Assert.isFalse(query.contains('FEC_SundaySchedule__c = true'),
                day + ' query must NOT contain Sunday filter');
        }

        // All queries must contain base conditions
        for (String day : new List<String>{'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'}) {
            String query = FEC_CampaignBatchService.buildScheduledQuery(fields, day);
            Assert.isTrue(query.contains('FEC_ScheduleCampaign__c = true'),
                day + ' query must contain schedule filter');
            Assert.isTrue(query.contains('FEC_IsWithinLifetime__c = true'),
                day + ' query must contain lifetime filter');
        }
    }

    @isTest
    static void testMapToModel_ValidRecord() {
        FEC_DataCampaign__c rec = new FEC_DataCampaign__c(
            FEC_AppId__c = 'APP001',
            FEC_AccountOrContractNumber__c = 'ACC001',
            FEC_ProductLine__c = 'Loan',
            FEC_Number1__c = 100,
            FEC_String1__c = 'TestStr'
        );

        Test.startTest();
        FEC_DataCampaign dto = FEC_CampaignBatchService.mapToModel(rec);
        Test.stopTest();

        Assert.areEqual('APP001', dto.appID);
        Assert.areEqual('ACC001', dto.accountOrContractNumber);
        Assert.areEqual('Loan', dto.productLine);
        Assert.areEqual(100, dto.number1);
        Assert.areEqual('TestStr', dto.string1);
    }

    @isTest
    static void testMapToModel_NullRecord() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            FEC_CampaignBatchService.mapToModel(null);
        } catch (IllegalArgumentException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Should throw IllegalArgumentException for null record');
    }

    @isTest
    static void testChunkBySize_EmptyList() {
        List<List<FEC_DataCampaign>> chunks = FEC_CampaignBatchService.chunkBySize(
            new List<FEC_DataCampaign>(), 1000
        );
        Assert.areEqual(0, chunks.size(), 'Empty list should produce no chunks');
    }

    @isTest
    static void testChunkBySize_NullList() {
        List<List<FEC_DataCampaign>> chunks = FEC_CampaignBatchService.chunkBySize(null, 1000);
        Assert.areEqual(0, chunks.size(), 'Null list should produce no chunks');
    }

    @isTest
    static void testChunkBySize_InvalidMaxSize() {
        Boolean exceptionThrown = false;
        try {
            FEC_CampaignBatchService.chunkBySize(
                new List<FEC_DataCampaign>{ new FEC_DataCampaign() }, 0
            );
        } catch (IllegalArgumentException e) {
            exceptionThrown = true;
        }
        Assert.isTrue(exceptionThrown, 'Should throw for zero maxJsonSize');
    }

    @isTest
    static void testBuildInstantPushQuery_ReturnsNonEmpty() {
        String query = FEC_CampaignBatchService.buildInstantPushQuery();
        Assert.isTrue(String.isNotBlank(query), 'Instant push query should not be blank');
        Assert.isTrue(query.contains('FEC_DataCampaign__c'),
            'Query should reference FEC_DataCampaign__c');
        Assert.isTrue(query.contains('FEC_PushInstant__c'),
            'Query should contain PushInstant filter');
    }

    // ─── Helper ────────────────────────────────────────────────────

    private static FEC_DataCampaign buildRandomDto() {
        FEC_DataCampaign dto = new FEC_DataCampaign();
        dto.appID = 'APP' + Math.mod(Math.abs(Crypto.getRandomInteger()), 10000);
        dto.accountOrContractNumber = 'ACC' + Math.mod(Math.abs(Crypto.getRandomInteger()), 10000);
        dto.productLine = Math.mod(Math.abs(Crypto.getRandomInteger()), 2) == 0 ? 'Loan' : 'Card';
        dto.number1 = Math.mod(Math.abs(Crypto.getRandomInteger()), 1000);
        dto.string1 = 'S' + Math.mod(Math.abs(Crypto.getRandomInteger()), 10000);
        return dto;
    }
}
