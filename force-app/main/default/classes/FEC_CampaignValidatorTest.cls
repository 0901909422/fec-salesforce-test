/**
 * FEC_CampaignValidatorTest
 * Tests for FEC_CampaignValidator — validation and duplicate checking.
 * Validates: Requirements 7.1, 7.2, 7.3, 7.4
 */
@isTest
private class FEC_CampaignValidatorTest {

    private static final String EXPECTED_CODE = 'CAMP001';

    // Feature: campaign-module-refactor, Property 3: Validation trả về lỗi chi tiết cho mọi field không hợp lệ
    // **Validates: Requirements 7.1, 7.3**
    @isTest
    static void testValidateUploadData_ReportsAllInvalidFields() {
        for (Integer i = 0; i < 100; i++) {
            Integer rowCount = Math.mod(Math.abs(Crypto.getRandomInteger()), 5) + 1;
            List<Map<String, Object>> rows = new List<Map<String, Object>>();

            for (Integer r = 0; r < rowCount; r++) {
                rows.add(buildInvalidRow());
            }

            List<FEC_CampaignValidator.ValidationResult> results =
                FEC_CampaignValidator.validateUploadData(rows, EXPECTED_CODE);

            // Each row has at least one invalid field → each should appear in results
            Assert.areEqual(rowCount, results.size(),
                'All rows should be invalid on iteration ' + i);

            for (FEC_CampaignValidator.ValidationResult vr : results) {
                Assert.isFalse(vr.isValid,
                    'Row ' + vr.rowIndex + ' should be invalid on iteration ' + i);
                Assert.isTrue(vr.errors.size() >= 1,
                    'Row ' + vr.rowIndex + ' should have at least 1 error on iteration ' + i);
                // Each error message should contain a field name reference
                for (String err : vr.errors) {
                    Assert.isTrue(
                        err.contains('Field') || err.contains('Row'),
                        'Error should reference field or row: ' + err
                    );
                }
            }
        }
    }

    // Feature: campaign-module-refactor, Property 4: Validation chấp nhận tất cả dữ liệu hợp lệ
    // **Validates: Requirements 7.4**
    @isTest
    static void testValidateUploadData_AcceptsAllValidRows() {
        for (Integer i = 0; i < 100; i++) {
            Integer rowCount = Math.mod(Math.abs(Crypto.getRandomInteger()), 5) + 1;
            List<Map<String, Object>> rows = new List<Map<String, Object>>();

            for (Integer r = 0; r < rowCount; r++) {
                rows.add(buildValidRow());
            }

            List<FEC_CampaignValidator.ValidationResult> results =
                FEC_CampaignValidator.validateUploadData(rows, EXPECTED_CODE);

            Assert.areEqual(0, results.size(),
                'Valid rows should produce no errors on iteration ' + i);
        }
    }

    @isTest
    static void testValidateRow_InvalidCampaignId() {
        Map<String, Object> row = buildValidRow();
        row.put('Campaign ID', 'WRONG_CODE');

        FEC_CampaignValidator.ValidationResult result =
            FEC_CampaignValidator.validateRow(row, EXPECTED_CODE, 0);

        Assert.isFalse(result.isValid);
        Assert.isTrue(result.errors.size() >= 1);
        Boolean hasCampaignIdError = false;
        for (String err : result.errors) {
            if (err.contains('Campaign ID')) hasCampaignIdError = true;
        }
        Assert.isTrue(hasCampaignIdError, 'Should report Campaign ID error');
    }

    @isTest
    static void testValidateRow_BlankProductLine() {
        Map<String, Object> row = buildValidRow();
        row.put('ProductLine', '');

        FEC_CampaignValidator.ValidationResult result =
            FEC_CampaignValidator.validateRow(row, EXPECTED_CODE, 0);

        Assert.isFalse(result.isValid);
        Boolean hasProductLineError = false;
        for (String err : result.errors) {
            if (err.contains('ProductLine')) hasProductLineError = true;
        }
        Assert.isTrue(hasProductLineError, 'Should report ProductLine error');
    }

    @isTest
    static void testValidateRow_InvalidProductLineValue() {
        Map<String, Object> row = buildValidRow();
        row.put('ProductLine', 'Insurance');

        FEC_CampaignValidator.ValidationResult result =
            FEC_CampaignValidator.validateRow(row, EXPECTED_CODE, 0);

        Assert.isFalse(result.isValid);
    }

    @isTest
    static void testValidateRow_ProductLineTooLong() {
        Map<String, Object> row = buildValidRow();
        row.put('ProductLine', 'LoanExtraLong1');  // > 12 chars

        FEC_CampaignValidator.ValidationResult result =
            FEC_CampaignValidator.validateRow(row, EXPECTED_CODE, 0);

        Assert.isFalse(result.isValid);
    }

    @isTest
    static void testValidateRow_BlankAppId() {
        Map<String, Object> row = buildValidRow();
        row.put('App ID', '');

        FEC_CampaignValidator.ValidationResult result =
            FEC_CampaignValidator.validateRow(row, EXPECTED_CODE, 0);

        Assert.isFalse(result.isValid);
    }

    @isTest
    static void testValidateRow_BlankAccountNumber() {
        Map<String, Object> row = buildValidRow();
        row.put('Account or Contract number', '');

        FEC_CampaignValidator.ValidationResult result =
            FEC_CampaignValidator.validateRow(row, EXPECTED_CODE, 0);

        Assert.isFalse(result.isValid);
    }

    @isTest
    static void testValidateRow_InvalidNumber() {
        Map<String, Object> row = buildValidRow();
        row.put('Number 1', 'abc');

        FEC_CampaignValidator.ValidationResult result =
            FEC_CampaignValidator.validateRow(row, EXPECTED_CODE, 0);

        Assert.isFalse(result.isValid);
        Boolean hasNumberError = false;
        for (String err : result.errors) {
            if (err.contains('Number 1')) hasNumberError = true;
        }
        Assert.isTrue(hasNumberError, 'Should report Number 1 error');
    }

    @isTest
    static void testValidateRow_NullRow() {
        FEC_CampaignValidator.ValidationResult result =
            FEC_CampaignValidator.validateRow(null, EXPECTED_CODE, 0);

        Assert.isFalse(result.isValid);
        Assert.isTrue(result.errors.size() >= 1);
    }

    @isTest
    static void testCheckDuplicateKeys_WithDuplicates() {
        Map<String, Object> fixedRow = new Map<String, Object>{
            'Campaign ID' => EXPECTED_CODE,
            'ProductLine' => 'Loan',
            'App ID' => 'APP001',
            'Account or Contract number' => 'ACC001',
            'Number 1' => 100,
            'Number 2' => 200,
            'Number 3' => 300
        };
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        rows.add(fixedRow);
        rows.add(fixedRow); // same key

        List<String> errors = FEC_CampaignValidator.checkDuplicateKeys(rows);
        Assert.isTrue(errors.size() >= 1, 'Should detect duplicate keys');
        Assert.isTrue(errors[0].contains('Duplicate'), 'Error should mention duplicate');
    }

    @isTest
    static void testCheckDuplicateKeys_NoDuplicates() {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        Map<String, Object> row1 = buildValidRow();
        Map<String, Object> row2 = buildValidRow();
        row2.put('App ID', 'APP999');
        rows.add(row1);
        rows.add(row2);

        List<String> errors = FEC_CampaignValidator.checkDuplicateKeys(rows);
        Assert.areEqual(0, errors.size(), 'No duplicates should produce no errors');
    }

    @isTest
    static void testCheckDuplicateKeys_EmptyList() {
        List<String> errors = FEC_CampaignValidator.checkDuplicateKeys(
            new List<Map<String, Object>>()
        );
        Assert.areEqual(0, errors.size());
    }

    @isTest
    static void testCheckDuplicateKeys_NullList() {
        List<String> errors = FEC_CampaignValidator.checkDuplicateKeys(null);
        Assert.areEqual(0, errors.size());
    }

    @isTest
    static void testValidateUploadData_EmptyList() {
        List<FEC_CampaignValidator.ValidationResult> results =
            FEC_CampaignValidator.validateUploadData(
                new List<Map<String, Object>>(), EXPECTED_CODE
            );
        Assert.areEqual(0, results.size());
    }

    @isTest
    static void testValidateUploadData_NullList() {
        List<FEC_CampaignValidator.ValidationResult> results =
            FEC_CampaignValidator.validateUploadData(null, EXPECTED_CODE);
        Assert.areEqual(0, results.size());
    }

    // ─── Helpers ───────────────────────────────────────────────────

    private static Map<String, Object> buildValidRow() {
        return new Map<String, Object>{
            'Campaign ID' => EXPECTED_CODE,
            'ProductLine' => (Math.mod(Math.abs(Crypto.getRandomInteger()), 2) == 0 ? 'Loan' : 'Card'),
            'App ID' => 'APP' + Math.mod(Math.abs(Crypto.getRandomInteger()), 10000),
            'Account or Contract number' => 'ACC' + Math.mod(Math.abs(Crypto.getRandomInteger()), 10000),
            'Number 1' => Math.mod(Math.abs(Crypto.getRandomInteger()), 1000),
            'Number 2' => Math.mod(Math.abs(Crypto.getRandomInteger()), 1000),
            'Number 3' => Math.mod(Math.abs(Crypto.getRandomInteger()), 1000)
        };
    }

    private static Map<String, Object> buildInvalidRow() {
        // Always has at least one invalid field: wrong Campaign ID
        Map<String, Object> row = new Map<String, Object>{
            'Campaign ID' => 'WRONG_' + Math.mod(Math.abs(Crypto.getRandomInteger()), 100),
            'ProductLine' => 'Loan',
            'App ID' => 'APP001',
            'Account or Contract number' => 'ACC001',
            'Number 1' => 100,
            'Number 2' => 200,
            'Number 3' => 300
        };

        // Randomly add more invalid fields
        Integer extraInvalid = Math.mod(Math.abs(Crypto.getRandomInteger()), 4);
        if (extraInvalid >= 1) row.put('ProductLine', '');
        if (extraInvalid >= 2) row.put('App ID', '');
        if (extraInvalid >= 3) row.put('Number 1', 'notANumber');

        return row;
    }
}
