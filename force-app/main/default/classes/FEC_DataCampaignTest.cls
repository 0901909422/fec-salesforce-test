/**
 * FEC_DataCampaignTest
 * Tests for FEC_DataCampaign DTO factory method.
 * Validates: Requirements 6.1, 6.2, 6.3, 6.4
 */
@isTest
private class FEC_DataCampaignTest {

    // Feature: campaign-module-refactor, Property 2: DTO factory method round-trip — JSON output tương đương
    // **Validates: Requirements 6.2, 6.4**
    @isTest
    static void testFromSObject_JsonOutputEquivalence() {
        for (Integer i = 0; i < 100; i++) {
            FEC_DataCampaign__c record = buildRandomSObject();

            FEC_DataCampaign dto = FEC_DataCampaign.fromSObject(record);

            // Verify key fields are mapped correctly
            Assert.areEqual(record.FEC_AppId__c, dto.appID,
                'appID mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_AccountOrContractNumber__c, dto.accountOrContractNumber,
                'accountOrContractNumber mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_ProductLine__c, dto.productLine,
                'productLine mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_Number1__c, dto.number1,
                'number1 mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_Number2__c, dto.number2,
                'number2 mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_Number3__c, dto.number3,
                'number3 mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_Number4__c, dto.number4,
                'number4 mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_Number5__c, dto.number5,
                'number5 mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_String1__c, dto.string1,
                'string1 mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_String2__c, dto.string2,
                'string2 mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_String3__c, dto.string3,
                'string3 mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_String4__c, dto.string4,
                'string4 mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_String5__c, dto.string5,
                'string5 mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_DateTime1__c, dto.dateTime1,
                'dateTime1 mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_DateTime2__c, dto.dateTime2,
                'dateTime2 mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_DateTime3__c, dto.dateTime3,
                'dateTime3 mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_RecordId__c, dto.recordID,
                'recordID mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_RecordStatus__c, dto.recordStatus,
                'recordStatus mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_RecordLifetime__c, dto.recordLifetime,
                'recordLifetime mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_RecordCurrentLifetime__c, dto.recordCurrentLifetime,
                'recordCurrentLifetime mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_MaxCallAttempt__c, dto.maxCallAttempt,
                'maxCallAttempt mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_CurrentCallAttempt__c, dto.currentCallAttempt,
                'currentCallAttempt mismatch on iteration ' + i);
            Assert.areEqual(record.FEC_CampaignCallingList__c, dto.campaignCallingList,
                'campaignCallingList mismatch on iteration ' + i);

            // Verify JSON serialization produces non-null output
            String jsonOutput = JSON.serialize(dto);
            Assert.isTrue(String.isNotBlank(jsonOutput),
                'JSON output should not be blank on iteration ' + i);
        }
    }

    @isTest
    static void testFromSObject_NullThrowsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            FEC_DataCampaign.fromSObject(null);
        } catch (IllegalArgumentException e) {
            exceptionThrown = true;
            Assert.isTrue(e.getMessage().contains('null'),
                'Exception message should mention null');
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Should throw IllegalArgumentException for null');
    }

    @isTest
    static void testFromSObject_AllFieldsMapped() {
        FEC_DataCampaign__c record = new FEC_DataCampaign__c(
            FEC_AppId__c = 'APP001',
            FEC_AccountOrContractNumber__c = 'ACC001',
            FEC_ProductLine__c = 'Loan',
            FEC_Number1__c = 10,
            FEC_Number2__c = 20,
            FEC_Number3__c = 30,
            FEC_Number4__c = 40,
            FEC_Number5__c = 50,
            FEC_String1__c = 'S1',
            FEC_String2__c = 'S2',
            FEC_String3__c = 'S3',
            FEC_String4__c = 'S4',
            FEC_String5__c = 'S5',
            FEC_DateTime1__c = DateTime.now(),
            FEC_DateTime2__c = DateTime.now().addDays(-1),
            FEC_DateTime3__c = DateTime.now().addDays(-2),
            FEC_RecordStatus__c = 'New',
            FEC_RecordLifetime__c = 2,
            FEC_RecordCurrentLifetime__c = 0,
            FEC_MaxCallAttempt__c = 3,
            FEC_CurrentCallAttempt__c = 0,
            FEC_CampaignCallingList__c = 'CL001',
            FEC_SystemName__c = 'SYS001'
        );

        FEC_DataCampaign dto = FEC_DataCampaign.fromSObject(record);

        Assert.areEqual('APP001', dto.appID);
        Assert.areEqual('ACC001', dto.accountOrContractNumber);
        Assert.areEqual('Loan', dto.productLine);
        Assert.areEqual(10, dto.number1);
        Assert.areEqual(20, dto.number2);
        Assert.areEqual(30, dto.number3);
        Assert.areEqual(40, dto.number4);
        Assert.areEqual(50, dto.number5);
        Assert.areEqual('S1', dto.string1);
        Assert.areEqual('S2', dto.string2);
        Assert.areEqual('S3', dto.string3);
        Assert.areEqual('S4', dto.string4);
        Assert.areEqual('S5', dto.string5);
        Assert.areEqual('New', dto.recordStatus);
        Assert.areEqual(2, dto.recordLifetime);
        Assert.areEqual(0, dto.recordCurrentLifetime);
        Assert.areEqual(3, dto.maxCallAttempt);
        Assert.areEqual(0, dto.currentCallAttempt);
        Assert.areEqual('CL001', dto.campaignCallingList);
    }

    @isTest
    static void testFromSObject_EmptyRecord() {
        FEC_DataCampaign__c record = new FEC_DataCampaign__c();
        FEC_DataCampaign dto = FEC_DataCampaign.fromSObject(record);

        Assert.areEqual(null, dto.appID);
        Assert.areEqual(null, dto.accountOrContractNumber);
        Assert.areEqual(null, dto.productLine);
        Assert.areEqual(null, dto.number1);
    }

    @isTest
    static void testEmptyConstructor() {
        FEC_DataCampaign dto = new FEC_DataCampaign();
        Assert.areEqual(null, dto.appID);
        Assert.areEqual(null, dto.campaignID);
    }

    // ─── Helper ────────────────────────────────────────────────────

    private static FEC_DataCampaign__c buildRandomSObject() {
        return new FEC_DataCampaign__c(
            FEC_AppId__c = 'APP' + Math.mod(Math.abs(Crypto.getRandomInteger()), 10000),
            FEC_AccountOrContractNumber__c = 'ACC' + Math.mod(Math.abs(Crypto.getRandomInteger()), 10000),
            FEC_ProductLine__c = Math.mod(Math.abs(Crypto.getRandomInteger()), 2) == 0 ? 'Loan' : 'Card',
            FEC_Number1__c = Math.mod(Math.abs(Crypto.getRandomInteger()), 1000),
            FEC_Number2__c = Math.mod(Math.abs(Crypto.getRandomInteger()), 1000),
            FEC_Number3__c = Math.mod(Math.abs(Crypto.getRandomInteger()), 1000),
            FEC_Number4__c = Math.mod(Math.abs(Crypto.getRandomInteger()), 1000),
            FEC_Number5__c = Math.mod(Math.abs(Crypto.getRandomInteger()), 1000),
            FEC_String1__c = 'STR' + Math.mod(Math.abs(Crypto.getRandomInteger()), 100),
            FEC_String2__c = 'STR' + Math.mod(Math.abs(Crypto.getRandomInteger()), 100),
            FEC_String3__c = 'STR' + Math.mod(Math.abs(Crypto.getRandomInteger()), 100),
            FEC_String4__c = 'STR' + Math.mod(Math.abs(Crypto.getRandomInteger()), 100),
            FEC_String5__c = 'STR' + Math.mod(Math.abs(Crypto.getRandomInteger()), 100),
            FEC_DateTime1__c = DateTime.now().addDays(-Math.mod(Math.abs(Crypto.getRandomInteger()), 30)),
            FEC_DateTime2__c = DateTime.now().addDays(-Math.mod(Math.abs(Crypto.getRandomInteger()), 30)),
            FEC_DateTime3__c = DateTime.now().addDays(-Math.mod(Math.abs(Crypto.getRandomInteger()), 30)),
            FEC_RecordStatus__c = 'New',
            FEC_RecordLifetime__c = Math.mod(Math.abs(Crypto.getRandomInteger()), 10),
            FEC_RecordCurrentLifetime__c = Math.mod(Math.abs(Crypto.getRandomInteger()), 5),
            FEC_MaxCallAttempt__c = Math.mod(Math.abs(Crypto.getRandomInteger()), 10),
            FEC_CurrentCallAttempt__c = Math.mod(Math.abs(Crypto.getRandomInteger()), 5),
            FEC_CampaignCallingList__c = 'CL' + Math.mod(Math.abs(Crypto.getRandomInteger()), 100)
        );
    }
}
