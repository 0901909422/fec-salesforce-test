/**
 * @description Proof-of-concept test class chứng minh pattern dùng FEC_TestDataFactory
 *              cho bulk testing (200+ records) và governor limits assertion.
 *              Đây là 5 test methods proof-of-concept cho Phase 3 Task 17 của spec
 *              kiro-config-refactor — không sửa các test class existing để giảm risk.
 *              Mỗi method:
 *                - Dùng FEC_TestDataFactory thay vì hardcode
 *                - Insert/process 200 records (bulk pattern)
 *                - Assert Limits.getQueries() / Limits.getDmlStatements() để verify
 *                  governor limits không bị vi phạm khi bulk
 * @author Kiro
 * @created 2026-05-23
 * @module Test Infrastructure
 */
@IsTest
private class FEC_TestDataFactoryTest {

    private static final Integer BULK_SIZE = 200;

    /**
     * Test 1: Bulk MDM Channel — verify factory bulk insert + governor limits.
     */
    @IsTest
    static void test_bulkMDMChannels_respectsGovernorLimits() {
        Test.startTest();
        Integer queriesBefore = Limits.getQueries();
        Integer dmlBefore = Limits.getDmlStatements();

        List<SObject> channels = FEC_TestDataFactory.createMDMChannels(BULK_SIZE);

        Integer queriesAfter = Limits.getQueries();
        Integer dmlAfter = Limits.getDmlStatements();
        Test.stopTest();

        Assert.areEqual(BULK_SIZE, channels.size(), 'Phải tạo đủ ' + BULK_SIZE + ' channel');
        Assert.isTrue((dmlAfter - dmlBefore) <= 1,
            'Bulk insert phải dùng <=1 DML statement, actual=' + (dmlAfter - dmlBefore));
        Assert.isTrue(queriesAfter < Limits.getLimitQueries(),
            'Số SOQL queries không được vượt quá governor limit');

        // Verify ID có sẵn (đã insert thành công)
        for (SObject c : channels) {
            Assert.isNotNull(c.Id, 'Channel ID phải có sau insert');
        }
    }

    /**
     * Test 2: Bulk MDM Additional Field — verify factory + governor limits.
     */
    @IsTest
    static void test_bulkMDMAdditionalFields_respectsGovernorLimits() {
        Test.startTest();
        Integer dmlBefore = Limits.getDmlStatements();

        List<SObject> fields = FEC_TestDataFactory.createMDMAdditionalFields(BULK_SIZE);

        Integer dmlAfter = Limits.getDmlStatements();
        Test.stopTest();

        Assert.areEqual(BULK_SIZE, fields.size(), 'Phải tạo đủ ' + BULK_SIZE + ' additional field');
        Assert.isTrue((dmlAfter - dmlBefore) <= 1,
            'Bulk insert phải dùng <=1 DML statement, actual=' + (dmlAfter - dmlBefore));
    }

    /**
     * Test 3: Bulk Account — verify bulk Account creation with governor limits assertion.
     */
    @IsTest
    static void test_bulkAccounts_respectsGovernorLimits() {
        Test.startTest();
        Integer dmlBefore = Limits.getDmlStatements();

        List<Account> accs = FEC_TestDataFactory.createAccounts(BULK_SIZE);

        Integer dmlAfter = Limits.getDmlStatements();
        Test.stopTest();

        Assert.areEqual(BULK_SIZE, accs.size(), 'Phải tạo đủ ' + BULK_SIZE + ' Account');
        Assert.isTrue((dmlAfter - dmlBefore) <= 1,
            'Bulk insert phải dùng <=1 DML statement');
        Assert.isNotNull(accs[0].Id, 'Account đầu tiên phải có ID sau insert');
        Assert.isNotNull(accs[BULK_SIZE - 1].Id, 'Account cuối cùng phải có ID sau insert');
    }

    /**
     * Test 4: Bulk Case + Account scenario — verify cross-object bulk pattern.
     * Note: Case có thể có triggers chạy thêm DML, nên assertion DML <= 5 thay vì 1.
     */
    @IsTest
    static void test_bulkCases_respectsGovernorLimits() {
        Account parent = FEC_TestDataFactory.createAccount(null);

        Test.startTest();
        Integer dmlBefore = Limits.getDmlStatements();
        Integer queriesBefore = Limits.getQueries();

        List<Case> cases = FEC_TestDataFactory.createCases(parent.Id, BULK_SIZE);

        Integer dmlAfter = Limits.getDmlStatements();
        Integer queriesAfter = Limits.getQueries();
        Test.stopTest();

        Assert.areEqual(BULK_SIZE, cases.size(), 'Phải tạo đủ ' + BULK_SIZE + ' Case');
        // Case có thể có triggers thực hiện thêm DML, nhưng phải bulk-safe (<=5 thay vì N=200)
        Assert.isTrue((dmlAfter - dmlBefore) <= 5,
            'Bulk insert Case phải bulk-safe (<=5 DML), actual=' + (dmlAfter - dmlBefore));
        // Verify governor limits không vượt
        Assert.isTrue(queriesAfter < Limits.getLimitQueries(),
            'Tổng SOQL queries phải nằm trong governor limit');
    }

    /**
     * Test 5: Override pattern — verify factory chấp nhận overrides Map.
     */
    @IsTest
    static void test_overridesPattern_appliesCustomFields() {
        Test.startTest();
        Account custom = FEC_TestDataFactory.createAccount(new Map<String, Object>{
            'Name' => 'Custom Account Name'
        });

        SObject channel = FEC_TestDataFactory.createMDMChannel(new Map<String, Object>{
            FEC_FieldConstants.FIELD_NAME => 'Override Channel'
        });
        Test.stopTest();

        Assert.areEqual('Custom Account Name', custom.Name, 'Override Account.Name phải được áp dụng');
        Assert.areEqual('Override Channel', (String) channel.get(FEC_FieldConstants.FIELD_NAME),
            'Override Channel.Name phải được áp dụng');
    }
}