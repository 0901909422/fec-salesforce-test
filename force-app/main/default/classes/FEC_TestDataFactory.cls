/**
 * @description Centralized test data factory cho FEC Salesforce CSM project.
 *              Cung cấp factory methods để tạo test records cho các object chính (Account, Contact, Case, MDM objects).
 *              Mỗi method chấp nhận optional Map<String, Object> overrides để custom field values.
 *              Mục tiêu: tránh hardcode test data, đảm bảo bulk testing dễ dàng (200+ records).
 * @author Dat Ngo
 * @created 2026-05-23
 * @module Test Infrastructure
 */
@IsTest
public class FEC_TestDataFactory {

    // ============================================================
    // Standard Salesforce Objects
    // ============================================================

    /**
     * Tạo 1 Account với defaults, optional overrides.
     */
    public static Account createAccount(Map<String, Object> overrides) {
        Account acc = new Account(Name = 'FEC Test Account');
        applyOverrides(acc, overrides);
        insert acc;
        return acc;
    }

    /**
     * Tạo nhiều Account cho bulk testing.
     */
    public static List<Account> createAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'FEC Test Account ' + i));
        }
        insert accounts;
        return accounts;
    }

    /**
     * Tạo 1 Contact gắn với Account, optional overrides.
     */
    public static Contact createContact(Id accountId, Map<String, Object> overrides) {
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = accountId
        );
        applyOverrides(con, overrides);
        insert con;
        return con;
    }

    /**
     * Tạo 1 Case gắn với Account, optional overrides.
     */
    public static Case createCase(Id accountId, Map<String, Object> overrides) {
        Case c = new Case(
            Subject = 'FEC Test Case',
            Status = 'New',
            Origin = 'Web',
            AccountId = accountId
        );
        applyOverrides(c, overrides);
        insert c;
        return c;
    }

    /**
     * Tạo nhiều Case cho bulk testing.
     */
    public static List<Case> createCases(Id accountId, Integer count) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cases.add(new Case(
                Subject = 'FEC Test Case ' + i,
                Status = 'New',
                Origin = 'Web',
                AccountId = accountId
            ));
        }
        insert cases;
        return cases;
    }

    // ============================================================
    // MDM Objects (FEC_MDM_*)
    // ============================================================

    /**
     * Tạo MDM Product Type.
     */
    public static SObject createMDMProductType(Map<String, Object> overrides) {
        SObject obj = (SObject) Type.forName(FEC_ObjectConstants.OBJ_MDM_PRODUCT_TYPE).newInstance();
        obj.put(FEC_FieldConstants.FIELD_NAME, 'Test Product Type');
        obj.put(FEC_FieldConstants.FIELD_CODE, generateUniqueCode('PT'));
        obj.put(FEC_FieldConstants.FIELD_NAME_VN, 'Loại sản phẩm test');
        obj.put(FEC_FieldConstants.FIELD_POS_ORDER, 1);
        obj.put(FEC_FieldConstants.FIELD_ACTIVE, true);
        applyOverrides(obj, overrides);
        insert obj;
        return obj;
    }

    /**
     * Tạo MDM Business Process.
     */
    public static SObject createMDMBusinessProcess(Map<String, Object> overrides) {
        SObject obj = (SObject) Type.forName(FEC_ObjectConstants.OBJ_MDM_BUSINESS_PROCESS).newInstance();
        obj.put(FEC_FieldConstants.FIELD_NAME, 'Test Business Process');
        obj.put(FEC_FieldConstants.FIELD_CODE, generateUniqueCode('BP'));
        obj.put(FEC_FieldConstants.FIELD_NAME_VN, 'Quy trình test');
        obj.put(FEC_FieldConstants.FIELD_FEC_ORDER, 1);
        obj.put(FEC_FieldConstants.FIELD_ACTIVE, true);
        applyOverrides(obj, overrides);
        insert obj;
        return obj;
    }

    /**
     * Tạo MDM Category gắn với product type optional.
     */
    public static SObject createMDMCategory(Map<String, Object> overrides) {
        SObject obj = (SObject) Type.forName(FEC_ObjectConstants.OBJ_MDM_CATEGORY).newInstance();
        obj.put(FEC_FieldConstants.FIELD_NAME, 'Test Category');
        obj.put(FEC_FieldConstants.FIELD_CODE, generateUniqueCode('CAT'));
        obj.put(FEC_FieldConstants.FIELD_NAME_VN, 'Danh mục test');
        obj.put(FEC_FieldConstants.FIELD_POS_ORDER, 1);
        obj.put(FEC_FieldConstants.FIELD_ACTIVE, true);
        applyOverrides(obj, overrides);
        insert obj;
        return obj;
    }

    /**
     * Tạo MDM Nature of Case (junction object 5 cấp).
     * Required: parentIds map chứa product, business process, category, sub category, sub code IDs.
     */
    public static SObject createMDMNatureOfCase(Map<String, Object> overrides) {
        SObject obj = (SObject) Type.forName(FEC_ObjectConstants.OBJ_MDM_NATURE_OF_CASE).newInstance();
        obj.put(FEC_FieldConstants.FIELD_CODE, generateUniqueCode('NOC'));
        obj.put(FEC_FieldConstants.FIELD_CUSTOMER_TYPE, 'Individual');
        applyOverrides(obj, overrides);
        insert obj;
        return obj;
    }

    /**
     * Tạo MDM Master Data Setting (config field-level).
     */
    public static SObject createMDMMasterDataSetting(Map<String, Object> overrides) {
        SObject obj = (SObject) Type.forName(FEC_ObjectConstants.OBJ_MDM_MASTER_DATA_SETTING).newInstance();
        obj.put(FEC_FieldConstants.FIELD_CODE, generateUniqueCode('MDS'));
        obj.put(FEC_FieldConstants.FIELD_FIELD_STATUS, true);
        obj.put(FEC_FieldConstants.FIELD_FIELD_READONLY, false);
        obj.put(FEC_FieldConstants.FIELD_FIELD_MANDATORY, false);
        obj.put(FEC_FieldConstants.FIELD_FIELD_ORDER_DISPLAY, 1);
        applyOverrides(obj, overrides);
        insert obj;
        return obj;
    }

    /**
     * Tạo MDM Case Stage gắn với business process.
     */
    public static SObject createMDMCaseStage(Map<String, Object> overrides) {
        SObject obj = (SObject) Type.forName(FEC_ObjectConstants.OBJ_MDM_CASE_STAGE).newInstance();
        obj.put(FEC_FieldConstants.FIELD_NAME, 'Test Stage');
        obj.put(FEC_FieldConstants.FIELD_CODE, generateUniqueCode('STG'));
        obj.put(FEC_FieldConstants.FIELD_NAME_VN, 'Giai đoạn test');
        obj.put(FEC_FieldConstants.FIELD_STATUS, true);
        obj.put(FEC_FieldConstants.FIELD_ACTIVE, true);
        obj.put(FEC_FieldConstants.FIELD_POS_ORDER, 1);
        applyOverrides(obj, overrides);
        insert obj;
        return obj;
    }

    /**
     * Tạo MDM Channel.
     */
    public static SObject createMDMChannel(Map<String, Object> overrides) {
        SObject obj = (SObject) Type.forName(FEC_ObjectConstants.OBJ_MDM_CHANNEL).newInstance();
        obj.put(FEC_FieldConstants.FIELD_NAME, 'Test Channel');
        obj.put(FEC_FieldConstants.FIELD_CHANNEL_ID, generateUniqueCode('CH'));
        obj.put(FEC_FieldConstants.FIELD_CHANNEL_VI_NAME, 'Kênh test');
        obj.put(FEC_FieldConstants.FIELD_CHANNEL_STATUS, true);
        applyOverrides(obj, overrides);
        insert obj;
        return obj;
    }

    /**
     * Bulk: Tạo nhiều MDM Channel cho governor-limits testing.
     */
    public static List<SObject> createMDMChannels(Integer count) {
        List<SObject> records = new List<SObject>();
        Schema.SObjectType sotype = Schema.getGlobalDescribe().get(FEC_ObjectConstants.OBJ_MDM_CHANNEL);
        for (Integer i = 0; i < count; i++) {
            SObject obj = sotype.newSObject();
            obj.put(FEC_FieldConstants.FIELD_NAME, 'Bulk Channel ' + i);
            obj.put(FEC_FieldConstants.FIELD_CHANNEL_ID, generateUniqueCode('CHB' + i));
            obj.put(FEC_FieldConstants.FIELD_CHANNEL_VI_NAME, 'Kênh bulk ' + i);
            obj.put(FEC_FieldConstants.FIELD_CHANNEL_STATUS, true);
            records.add(obj);
        }
        insert records;
        return records;
    }

    /**
     * Tạo MDM Additional Field.
     */
    public static SObject createMDMAdditionalField(Map<String, Object> overrides) {
        SObject obj = (SObject) Type.forName(FEC_ObjectConstants.OBJ_MDM_ADDITIONAL_FIELD).newInstance();
        obj.put(FEC_FieldConstants.FIELD_NAME, 'Test Field');
        obj.put(FEC_FieldConstants.FIELD_FEC_UNIQUE_ID, generateUniqueCode('AF'));
        obj.put(FEC_FieldConstants.FIELD_NAME_VN, 'Trường test');
        obj.put(FEC_FieldConstants.FIELD_FEC_TYPE, 'String');
        applyOverrides(obj, overrides);
        insert obj;
        return obj;
    }

    /**
     * Bulk: Tạo nhiều MDM Additional Field.
     */
    public static List<SObject> createMDMAdditionalFields(Integer count) {
        List<SObject> records = new List<SObject>();
        Schema.SObjectType sotype = Schema.getGlobalDescribe().get(FEC_ObjectConstants.OBJ_MDM_ADDITIONAL_FIELD);
        for (Integer i = 0; i < count; i++) {
            SObject obj = sotype.newSObject();
            obj.put(FEC_FieldConstants.FIELD_NAME, 'Bulk Field ' + i);
            obj.put(FEC_FieldConstants.FIELD_FEC_UNIQUE_ID, generateUniqueCode('AFB' + i));
            obj.put(FEC_FieldConstants.FIELD_NAME_VN, 'Trường bulk ' + i);
            obj.put(FEC_FieldConstants.FIELD_FEC_TYPE, 'String');
            records.add(obj);
        }
        insert records;
        return records;
    }

    /**
     * Tạo MDM Action Button.
     */
    public static SObject createMDMActionButton(Map<String, Object> overrides) {
        SObject obj = (SObject) Type.forName(FEC_ObjectConstants.OBJ_MDM_ACTION_BUTTON).newInstance();
        obj.put(FEC_FieldConstants.FIELD_NAME, 'Test Button');
        obj.put(FEC_FieldConstants.FIELD_CODE, generateUniqueCode('AB'));
        obj.put(FEC_FieldConstants.FIELD_FEC_TYPE, 'Apex');
        obj.put(FEC_FieldConstants.FIELD_ACTIVE, true);
        applyOverrides(obj, overrides);
        insert obj;
        return obj;
    }

    // ============================================================
    // Helpers
    // ============================================================

    /**
     * Apply overrides map vào SObject.
     * Mỗi entry: key = field API name, value = field value.
     */
    private static void applyOverrides(SObject record, Map<String, Object> overrides) {
        if (overrides == null || overrides.isEmpty()) {
            return;
        }
        for (String fieldName : overrides.keySet()) {
            record.put(fieldName, overrides.get(fieldName));
        }
    }

    /**
     * Generate unique code cho test data, dùng prefix + timestamp + random suffix.
     */
    private static String generateUniqueCode(String prefix) {
        return prefix + '_TEST_' + System.currentTimeMillis() + '_' + Math.round(Math.random() * 9999);
    }
}