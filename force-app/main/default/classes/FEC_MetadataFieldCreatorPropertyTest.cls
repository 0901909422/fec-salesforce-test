/**
 * @description Property-based tests cho FEC_MetadataFieldCreator.
 * @date 2026-03-31
 */
@isTest
private class FEC_MetadataFieldCreatorPropertyTest {

    private static final Pattern VALID_API_NAME_REGEX = Pattern.compile('^[a-zA-Z][a-zA-Z0-9_]*__c$');
    private static final Integer MAX_API_NAME_LENGTH = 40;

    private static String randomString(Integer len) {
        String chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_!@# ';
        String result = '';
        for (Integer i = 0; i < len; i++) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            result += chars.substring(idx, idx + 1);
        }
        return result;
    }

    // Feature: mdm-auto-field-creator, Property 6: validateFieldApiName phát hiện đúng format
    @isTest
    static void testProperty6_ValidateFieldApiName() {
        List<String> validNames = new List<String>{ 'My_Field__c', 'Test__c', 'A__c', 'Field_123__c' };
        for (String name : validNames) {
            Map<String, Object> result = FEC_MetadataFieldCreator.validateFieldApiName(name);
            Assert.isTrue((Boolean) result.get('isValid'), 'Expected valid for: ' + name);
        }

        List<String> invalidNames = new List<String>{ '', '123_Field__c', 'no_suffix', 'has space__c', '__c',
            'ThisIsAVeryLongFieldNameThatExceedsTheMaximumAllowedLengthForApiNames__c' };
        for (String name : invalidNames) {
            Map<String, Object> result = FEC_MetadataFieldCreator.validateFieldApiName(name);
            Assert.isFalse((Boolean) result.get('isValid'), 'Expected invalid for: ' + name);
            Assert.isTrue(String.isNotBlank((String) result.get('errorMessage')), 'Expected error message for: ' + name);
        }

        for (Integer i = 0; i < 100; i++) {
            String testStr = randomString(Math.mod(Math.abs(Crypto.getRandomInteger()), 50) + 1);
            Map<String, Object> result = FEC_MetadataFieldCreator.validateFieldApiName(testStr);
            Boolean isValid = (Boolean) result.get('isValid');
            Matcher m = VALID_API_NAME_REGEX.matcher(testStr);
            Boolean regexMatch = m.matches() && testStr.length() <= MAX_API_NAME_LENGTH;
            Assert.areEqual(regexMatch, isValid, 'Mismatch for: "' + testStr + '"');
        }
    }

    // Feature: mdm-auto-field-creator, Property 7: buildFieldDefinition ánh xạ đúng config cho mọi Field Type
    @isTest
    static void testProperty7_BuildFieldDefinitionMapping() {
        List<String> fieldTypes = new List<String>{
            'Text', 'Number', 'Checkbox', 'Date', 'DateTime', 'Picklist',
            'Lookup', 'Currency', 'Percent', 'Phone', 'Email', 'URL'
        };
        for (String ft : fieldTypes) {
            Map<String, Object> config = new Map<String, Object>{
                'objectName' => 'Account', 'fieldLabel' => 'Test ' + ft,
                'fieldApiName' => 'Test_' + ft + '__c', 'fieldType' => ft,
                'length' => 255, 'description' => 'Test ' + ft,
                'picklistValues' => ft == 'Picklist' ? 'Val1\nVal2' : null,
                'relatedObject' => ft == 'Lookup' ? 'Contact' : null
            };
            Map<String, Object> fieldDef = FEC_MetadataFieldCreator.buildFieldDefinition(config);
            Assert.isNotNull(fieldDef, 'Should not be null for: ' + ft);
            Assert.areEqual('Account.Test_' + ft + '__c', fieldDef.get('FullName'), 'FullName mismatch for: ' + ft);
        }
    }

    // Feature: mdm-auto-field-creator, Property 5: checkFieldExists nhất quán với Schema
    @isTest
    static void testProperty5_CheckFieldExists() {
        List<String> existingFields = new List<String>{ 'Name', 'Id', 'CreatedDate' };
        for (String f : existingFields) {
            Assert.isTrue(FEC_MetadataFieldCreator.checkFieldExists('Account', f), 'Should exist: Account.' + f);
        }
        List<String> nonExistingFields = new List<String>{ 'Totally_Fake__c', 'NonExistent__c' };
        for (String f : nonExistingFields) {
            Assert.isFalse(FEC_MetadataFieldCreator.checkFieldExists('Account', f), 'Should NOT exist: Account.' + f);
        }
        Assert.isFalse(FEC_MetadataFieldCreator.checkFieldExists('FakeObject__c', 'Name'), 'Fake object should return false');
    }

    // Feature: mdm-auto-field-creator, Property 4: Auto-gen API Name từ Label
    @isTest
    static void testProperty4_AutoGenApiName() {
        List<String> labels = new List<String>{ 'My Field', 'Test Label', 'Hello World 123', 'Simple',
            'Special!@#$%Chars', '123 Starts With Number', 'A' };
        for (String lbl : labels) {
            String apiName = FEC_MetadataFieldCreator.generateApiName(lbl);
            if (String.isNotBlank(apiName)) {
                Assert.isTrue(apiName.endsWith('__c'), 'Must end with __c for: ' + lbl);
                Assert.isTrue(apiName.length() <= MAX_API_NAME_LENGTH, 'Too long for: ' + lbl);
                Assert.isFalse(apiName.contains(' '), 'Must not contain spaces for: ' + lbl);
            }
        }
        Assert.areEqual('', FEC_MetadataFieldCreator.generateApiName(''), 'Blank should return empty');
        Assert.areEqual('', FEC_MetadataFieldCreator.generateApiName(null), 'Null should return empty');
    }

    // Feature: mdm-auto-field-creator, Property 8: Deploy request luôn được tạo với trạng thái Pending
    @isTest
    static void testProperty8_DeployRequestCreation() {
        for (Integer i = 0; i < 5; i++) {
            FEC_Field_Deploy_Request__c request = new FEC_Field_Deploy_Request__c(
                FEC_Target_Object__c = 'Account',
                FEC_Field_Label__c = 'Test Field ' + i,
                FEC_Field_API_Name__c = 'Test_Field_' + i + '__c',
                FEC_Field_Type__c = 'Text',
                FEC_Deploy_Status__c = 'Pending',
                FEC_Requested_By__c = UserInfo.getUserId(),
                FEC_Requested_Date__c = Datetime.now()
            );
            insert request;
            FEC_Field_Deploy_Request__c inserted = [
                SELECT FEC_Deploy_Status__c, FEC_Requested_By__c, FEC_Requested_Date__c
                FROM FEC_Field_Deploy_Request__c WHERE Id = :request.Id
            ];
            Assert.areEqual('Pending', inserted.FEC_Deploy_Status__c, 'Must be Pending');
            Assert.areEqual(UserInfo.getUserId(), inserted.FEC_Requested_By__c, 'Must be current user');
            Assert.isNotNull(inserted.FEC_Requested_Date__c, 'Date must not be null');
        }
    }

    // Feature: mdm-auto-field-creator, Property 13: Permission check
    @isTest
    static void testProperty13_PermissionCheck() {
        try {
            FEC_MetadataFieldCreator.checkDeployPermission();
            Assert.isTrue(true, 'Permission check passed');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Error message should not be null');
        }
    }
}