/****************************************************************************************
 * File Name    : FEC_GetCSMasterDataService
 * Author       : Quangdv7
 * Date         : 2025-12-11
 * Description  : Get data for API service
 * REST (raw SOAP XML): FEC_GetCSMasterDataRestService → FEC_MyCaseSoapXml
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-12-11     Quangdv7             Create
 
****************************************************************************************/
global with sharing class FEC_GetCSMasterDataService {
    private static final Integer MAX_TRANSACTION_ID = 36;

    // Cache
    private static Map<String, List<AdditionalPropertyType>> cacheByApplyTo = new Map<String, List<AdditionalPropertyType>>();
    private static List<FEC_Master_Data_Setting__c> cachedSettings;
    private static Map<String, Schema.DescribeFieldResult> additionalFieldDescribeByApi;

    // ==========================================================
    // MAIN
    // ==========================================================
    webservice static GetCSMasterDataResponse GetCSMasterDataRequest(SysRequestType Sys) {
        return GetCSMasterDataRequest(Sys, true);
    }

    private static GetCSMasterDataResponse GetCSMasterDataRequest(
        SysRequestType Sys,
        Boolean includeAdditionalProperties
    ) {

        GetCSMasterDataResponse res = initResponse(Sys);
        if (Sys == null) {
            res.Sys.Code = '101';
            res.Sys.Description = System.Label.FEC_MSG_Sys_Null;
            return res;
        }

        if (String.isBlank(Sys.Channel) || !FEC_ConstantCommon.SUPPORTED_CHANNELS.contains(Sys.Channel)) {
            res.Sys.Code = '102';
            res.Sys.Description = System.Label.FEC_MSG_Channel_Validation + Sys.Channel + System.Label.FEC_MSG_Data_Request_Master_Data;
            return res;
        }

        if (String.isBlank(Sys.TransactionID) || Sys.TransactionID.length() > FEC_ConstantCommon.CANCEL_CS_TRANSACTION_ID_MAX_LEN) {
            res.Sys.Code = '103';
            res.Sys.Description = System.Label.FEC_MSG_TransactionId_Validation + FEC_ConstantCommon.CANCEL_CS_TRANSACTION_ID_MAX_LEN + System.Label.FEC_MSG_Limit_Character;
            return res;
        }

        // Settings only needed when AdditionalProperties DTOs are attached (SOAP webservice path).
        if (includeAdditionalProperties) {
            loadSettings(true);
        }

        List<FEC_Nature_of_Case__c> records = [
            SELECT
                FEC_Customer_Type__c,

                FEC_Product_Type__r.FEC_Code__c,
                FEC_Product_Type__r.Name,
                FEC_Product_Type__r.FEC_Name_VN__c,
                FEC_Product_Type__r.FEC_Order__c,

                FEC_Business_Process__r.FEC_Code__c,
                FEC_Business_Process__r.Name,
                FEC_Business_Process__r.FEC_Name_VN__c,
                FEC_Business_Process__r.FEC_Order__c,

                FEC_Category__r.FEC_Code__c,
                FEC_Category__r.Name,
                FEC_Category__r.FEC_Name_VN__c,
                FEC_Category__r.FEC_Order__c,

                FEC_Sub_Category__r.FEC_Code__c,
                FEC_Sub_Category__r.Name,
                FEC_Sub_Category__r.FEC_Name_VN__c,
                FEC_Sub_Category__r.FEC_Order__c,

                FEC_Sub_Code__r.FEC_Code__c,
                FEC_Sub_Code__r.Name,
                FEC_Sub_Code__r.FEC_Name_VN__c,
                FEC_Sub_Code__r.FEC_Order__c

            FROM FEC_Nature_of_Case__c
            ORDER BY
                FEC_Product_Type__r.FEC_Order__c,
                FEC_Business_Process__r.FEC_Order__c,
                FEC_Category__r.FEC_Order__c,
                FEC_Sub_Category__r.FEC_Order__c,
                FEC_Sub_Code__r.FEC_Order__c
        ];

        Map<String, MasterDataItemType> productMap = new Map<String, MasterDataItemType>();

        for (FEC_Nature_of_Case__c n : records) {

            if (n.FEC_Product_Type__r == null ||
                n.FEC_Business_Process__r == null ||
                n.FEC_Category__r == null ||
                n.FEC_Sub_Category__r == null ||
                n.FEC_Sub_Code__r == null) {
                continue;
            }

            String applyTo = n.FEC_Customer_Type__c;

            // ================= PRODUCT =================
            String pCode = n.FEC_Product_Type__r.FEC_Code__c;

            if (!productMap.containsKey(pCode)) {
                MasterDataItemType p = new MasterDataItemType();
                p.ID = pCode;
                p.Name = n.FEC_Product_Type__r.Name;
                p.NameVN = n.FEC_Product_Type__r.FEC_Name_VN__c;
                p.PosOrder = FEC_CommonUltils.toInt(n.FEC_Product_Type__r.FEC_Order__c);
                p.ApplyTo = applyTo;
                p.Type = FEC_ConstantCommon.KEY_PRODUCT_TYPE_PRODUCT;
                p.Children = new List<ChildItemType>();
                if (includeAdditionalProperties) {
                    p.AdditionalProperties = getAdditionalProperties(applyTo);
                }

                productMap.put(pCode, p);
            } else {
                MasterDataItemType p = productMap.get(pCode);
                p.ApplyTo = FEC_CommonUltils.mergeApplyTo(p.ApplyTo, applyTo);
            }

            MasterDataItemType product = productMap.get(pCode);

            // ================= CASE TYPE =================
            ChildItemType caseType = findOrCreateChild(
                product.Children,
                n.FEC_Business_Process__r.FEC_Code__c,
                n.FEC_Business_Process__r.Name,
                n.FEC_Business_Process__r.FEC_Name_VN__c,
                n.FEC_Business_Process__r.FEC_Order__c,
                applyTo,
                FEC_ConstantCommon.KEY_CASETYPE
            );
            // ================= CATEGORY =================
            ChildItemType category = findOrCreateChild(
                caseType.Children,
                n.FEC_Category__r.FEC_Code__c,
                n.FEC_Category__r.Name,
                n.FEC_Category__r.FEC_Name_VN__c,
                n.FEC_Category__r.FEC_Order__c,
                applyTo,
                FEC_ConstantCommon.KEY_CATEGORY
            );

            // ================= SUB CATEGORY =================
            ChildItemType subCategory = findOrCreateChild(
                category.Children,
                n.FEC_Sub_Category__r.FEC_Code__c,
                n.FEC_Sub_Category__r.Name,
                n.FEC_Sub_Category__r.FEC_Name_VN__c,
                n.FEC_Sub_Category__r.FEC_Order__c,
                applyTo,
                FEC_ConstantCommon.KEY_SUBCATEGORY
            );

            // ================= SUB CODE =================
            findOrCreateChild(
                subCategory.Children,
                n.FEC_Sub_Code__r.FEC_Code__c,
                n.FEC_Sub_Code__r.Name,
                n.FEC_Sub_Code__r.FEC_Name_VN__c,
                n.FEC_Sub_Code__r.FEC_Order__c,
                applyTo,
                FEC_ConstantCommon.KEY_SUBCODE
            );
        }

        res.MasterDataItems = productMap.values();
        res.Sys.Code = System.Label.FEC_Success_Title;
        res.Sys.Description = System.Label.FEC_MSG_Get_CS_Data_Success;

        return res;
    }

    public static String buildGetCSMasterDataSoapXml(SysRequestType sys) {
        GetCSMasterDataResponse res = GetCSMasterDataRequest(sys, false);
        loadSettings(false);
        Map<String, String> additionalPropsXmlCache =
            buildAdditionalPropertiesXmlCacheFromItems(res.MasterDataItems);
        return FEC_MyCaseSoapXml.buildGetCSMasterDataSoapResponse(
            res.Sys,
            res.MasterDataItems,
            additionalPropsXmlCache
        );
    }

    private static Map<String, String> buildAdditionalPropertiesXmlCacheFromItems(
        List<MasterDataItemType> items
    ) {
        Map<String, String> cache = new Map<String, String>();
        if (items == null || items.isEmpty()) {
            return cache;
        }

        Set<String> applyTos = new Set<String>();
        for (MasterDataItemType item : items) {
            if (item != null) {
                applyTos.add(item.ApplyTo);
            }
        }

        for (String applyTo : applyTos) {
            String cacheKey = applyTo == null ? '__NULL__' : applyTo;
            cache.put(cacheKey, buildAdditionalPropertiesXmlForApplyTo(applyTo));
        }
        return cache;
    }

    private static String buildAdditionalPropertiesXmlForApplyTo(String applyTo) {
        return buildAdditionalPropertiesXmlForApplyTo(applyTo, false);
    }

    private static String buildAdditionalPropertiesXmlForApplyTo(
        String applyTo,
        Boolean includePicklistValues
    ) {
        if (cachedSettings == null || cachedSettings.isEmpty()) {
            return '';
        }

        String result = '';
        Set<String> seenFieldApis = new Set<String>();
        for (FEC_Master_Data_Setting__c setting : cachedSettings) {
            String settingApplyTo = setting.FEC_Nature_Of_Case__r != null
                ? setting.FEC_Nature_Of_Case__r.FEC_Customer_Type__c
                : null;

            if (!matchApplyTo(applyTo, settingApplyTo)) {
                continue;
            }

            String fieldApi = setting.FEC_Field_API_Name__c;
            if (String.isBlank(fieldApi)) {
                continue;
            }

            String fieldApiKey = fieldApi.toLowerCase();
            if (seenFieldApis.contains(fieldApiKey)) {
                continue;
            }
            seenFieldApis.add(fieldApiKey);

            Schema.DescribeFieldResult fieldDescribe = getAdditionalFieldDescribe(fieldApi);

            String name = fieldDescribe != null ? fieldDescribe.getLabel() : fieldApi;
            String type = fieldDescribe != null
                ? mapFieldTypeFromDisplayType(fieldDescribe.getType())
                : 'string';
            Integer posOrder = setting.FEC_Field_Order_Display__c == null
                ? null
                : Integer.valueOf(setting.FEC_Field_Order_Display__c);
            List<Schema.PicklistEntry> picklistEntries = null;
            if (includePicklistValues == true
                && type == 'list'
                && fieldDescribe != null) {
                picklistEntries = fieldDescribe.getPicklistValues();
            }

            result = appendAdditionalPropertiesXmlBatch(
                result,
                new List<String>{
                    FEC_MyCaseSoapXml.buildMasterDataAdditionalPropertyXml(
                        fieldApi,
                        name,
                        name,
                        posOrder,
                        settingApplyTo,
                        setting.FEC_Field_Mandatory__c,
                        type,
                        picklistEntries,
                        includePicklistValues
                    )
                }
            );
        }

        return result;
    }

    private static String appendAdditionalPropertiesXmlBatch(
        String accumulated,
        List<String> batch
    ) {
        if (batch == null || batch.isEmpty()) {
            return accumulated;
        }
        return accumulated + String.join(batch, '');
    }

    // ==========================================================
    // CHILD FACTORY
    // ==========================================================
    private static ChildItemType findOrCreateChild(
        List<ChildItemType> children,
        String id,
        String name,
        String nameVN,
        Decimal order,
        String applyTo,
        String type
    ) {

        for (ChildItemType c : children) {
            if (c.ID == id) {
                c.ApplyTo = FEC_CommonUltils.mergeApplyTo(c.ApplyTo, applyTo);
                return c;
            }
        }

        ChildItemType c = new ChildItemType();
        c.ID = id;
        c.Name = name;
        c.NameVN = nameVN;
        c.PosOrder = order == null ? null : Integer.valueOf(order);
        c.ApplyTo = applyTo;
        c.Type = type;
        c.Children = new List<ChildItemType>();

        children.add(c);
        return c;
    }

    // ==========================================================
    // SETTINGS CACHE
    // ==========================================================
    private static void loadSettings() {
        loadSettings(true);
    }

    private static void loadSettings(Boolean warmPropertiesCache) {
        if (cachedSettings != null) {
            if (warmPropertiesCache) {
                warmAdditionalPropertiesCache();
            }
            return;
        }

        cachedSettings = [
            SELECT
                FEC_Field_API_Name__c,
                FEC_Field_Order_Display__c,
                FEC_Field_Mandatory__c,
                FEC_Nature_Of_Case__r.FEC_Customer_Type__c
            FROM FEC_Master_Data_Setting__c
            WHERE FEC_Field_Object_Name__c = :FEC_ConstantCommon.OBJ_ADDITIONAL_INFO
        ];

        if (warmPropertiesCache) {
            warmAdditionalPropertiesCache();
        }
    }

    private static Schema.DescribeFieldResult getAdditionalFieldDescribe(String fieldApi) {
        if (String.isBlank(fieldApi)) {
            return null;
        }

        if (additionalFieldDescribeByApi == null) {
            additionalFieldDescribeByApi = new Map<String, Schema.DescribeFieldResult>();
        }

        String key = fieldApi.toLowerCase();
        if (!additionalFieldDescribeByApi.containsKey(key)) {
            Map<String, Schema.SObjectField> fieldMap =
                FEC_Additional_Info__c.SObjectType.getDescribe().fields.getMap();
            Schema.SObjectField fieldToken = fieldMap.get(key);
            additionalFieldDescribeByApi.put(
                key,
                fieldToken != null ? fieldToken.getDescribe() : null
            );
        }

        return additionalFieldDescribeByApi.get(key);
    }

    private static void warmAdditionalPropertiesCache() {
        Set<String> applyTos = new Set<String>();
        applyTos.add(null);

        for (FEC_Master_Data_Setting__c setting : cachedSettings) {
            String settingApplyTo = setting.FEC_Nature_Of_Case__r != null
                ? setting.FEC_Nature_Of_Case__r.FEC_Customer_Type__c
                : null;
            applyTos.add(settingApplyTo);
        }

        for (String applyTo : applyTos) {
            if (!cacheByApplyTo.containsKey(applyTo)) {
                getAdditionalProperties(applyTo);
            }
        }
    }

    // ==========================================================
    // ADDITIONAL PROPERTIES
    // ==========================================================
    private static List<AdditionalPropertyType> getAdditionalProperties(String applyTo) {

        if (cacheByApplyTo.containsKey(applyTo)) {
            return cacheByApplyTo.get(applyTo);
        }

        List<AdditionalPropertyType> result = new List<AdditionalPropertyType>();

        for (FEC_Master_Data_Setting__c m : cachedSettings) {

            String settingApplyTo = m.FEC_Nature_Of_Case__r != null
                ? m.FEC_Nature_Of_Case__r.FEC_Customer_Type__c
                : null;

            if (!matchApplyTo(applyTo, settingApplyTo)) {
                continue;
            }

            AdditionalPropertyType p = new AdditionalPropertyType();
            p.ID = m.FEC_Field_API_Name__c;
            p.PosOrder = m.FEC_Field_Order_Display__c == null
                ? null
                : Integer.valueOf(m.FEC_Field_Order_Display__c);
            p.ApplyTo = settingApplyTo;
            p.Mandatory = m.FEC_Field_Mandatory__c;

            populateAdditionalPropertyMetadata(p);

            result.add(p);
        }

        cacheByApplyTo.put(applyTo, result);

        return result;
    }

    private static Boolean matchApplyTo(String req, String setting) {
        if (setting == null) return true;
        if (req == null) return true;
        if (setting == 'ALL') return true;
        return setting == req;
    }

    private static void populateAdditionalPropertyMetadata(AdditionalPropertyType p) {
        if (p == null || String.isBlank(p.ID)) {
            return;
        }

        Schema.DescribeFieldResult fieldDescribe = getAdditionalFieldDescribe(p.ID);

        if (fieldDescribe == null) {
            p.Name = p.ID;
            p.NameVN = p.ID;
            p.Type = 'string';
            return;
        }

        p.Name = fieldDescribe.getLabel();
        p.NameVN = p.Name;
        p.Type = mapFieldTypeFromDisplayType(fieldDescribe.getType());

        if (p.Type == 'list') {
            p.AvailableValues = mapPicklistEntries(fieldDescribe.getPicklistValues());
        }
    }

    private static String mapFieldType(String t) {
        if (t == FEC_ConstantCommon.KEY_PICKLIST) {
            return 'list';
        }
        if (t == FEC_ConstantCommon.KEY_CHECKBOX) {
            return 'boolean';
        }
        if (t == FEC_ConstantCommon.KEY_DATE) {
            return 'date';
        }
        if (t == FEC_ConstantCommon.KEY_DATETIME) {
            return 'datetime';
        }
        if (t == FEC_ConstantCommon.KEY_NUMBER) {
            return 'number';
        }
        return 'string';
    }

    private static String mapFieldTypeFromDisplayType(Schema.DisplayType fieldType) {
        return mapFieldType(displayTypeToFieldTypeKey(fieldType));
    }

    private static String displayTypeToFieldTypeKey(Schema.DisplayType fieldType) {
        switch on fieldType {
            when Picklist {
                return FEC_ConstantCommon.KEY_PICKLIST;
            }
            when Boolean {
                return FEC_ConstantCommon.KEY_CHECKBOX;
            }
            when Date {
                return FEC_ConstantCommon.KEY_DATE;
            }
            when DateTime {
                return FEC_ConstantCommon.KEY_DATETIME;
            }
            when Integer, Double, Currency, Percent {
                return FEC_ConstantCommon.KEY_NUMBER;
            }
            when else {
                return 'string';
            }
        }
    }

    private static List<AvailableValueType> mapPicklistEntries(
        List<Schema.PicklistEntry> picklistEntries
    ) {
        List<AvailableValueType> result = new List<AvailableValueType>();

        if (picklistEntries == null) {
            return result;
        }

        for (Schema.PicklistEntry entry : picklistEntries) {
            if (entry == null || !entry.isActive()) {
                continue;
            }
            AvailableValueType value = new AvailableValueType();
            value.ID = entry.getValue();
            value.Name = entry.getLabel();
            value.NameVN = entry.getLabel();
            result.add(value);
        }

        return result;
    }

    private static List<AvailableValueType> mapAvailableValues(
        List<FEC_CommonUltils.PicklistOption> options
    ) {
        List<AvailableValueType> result = new List<AvailableValueType>();

        if (options == null) {
            return result;
        }

        for (FEC_CommonUltils.PicklistOption opt : options) {
            AvailableValueType v = new AvailableValueType();
            v.ID = opt.value;
            v.Name = opt.label;
            v.NameVN = opt.label;
            result.add(v);
        }

        return result;
    }

    // ==========================================================
    // RESPONSE INIT
    // ==========================================================
    private static GetCSMasterDataResponse initResponse(SysRequestType Sys) {
        GetCSMasterDataResponse r = new GetCSMasterDataResponse();
        r.Sys = new SysResponseType();
        r.Sys.TransactionID = Sys != null ? Sys.TransactionID : null;
        r.Sys.DateTime_x = System.now();
        r.MasterDataItems = new List<MasterDataItemType>();
        return r;
    }

    // ==========================================================
    // DTO
    // ==========================================================
    global class SysRequestType {
        webservice String TransactionID;
        webservice String Channel;
        webservice Datetime DateTime_x;
    }

    global class GetCSMasterDataResponse {
        webservice SysResponseType Sys;
        webservice List<MasterDataItemType> MasterDataItems;
    }

    global class SysResponseType {
        webservice String TransactionID;
        webservice Datetime DateTime_x;
        webservice String Code;
        webservice String Description;
    }

    global class MasterDataItemType {
        webservice String ID;
        webservice String Name;
        webservice String NameVN;
        webservice Integer PosOrder;
        webservice String ApplyTo;
        webservice String Type;
        webservice List<ChildItemType> Children;
        webservice List<AdditionalPropertyType> AdditionalProperties;
    }

    global class ChildItemType {
        webservice String ID;
        webservice String Name;
        webservice String NameVN;
        webservice Integer PosOrder;
        webservice String ApplyTo;
        webservice String Type;
        webservice List<ChildItemType> Children;
        webservice List<AdditionalPropertyType> AdditionalProperties;
    }

    global class AdditionalPropertyType {
        webservice String ID;
        webservice String Name;
        webservice String NameVN;
        webservice Integer PosOrder;
        webservice String ApplyTo;
        webservice Boolean Mandatory;
        webservice String Type;
        webservice List<AvailableValueType> AvailableValues;
    }

    global class AvailableValueType {
        webservice String ID;
        webservice String Name;
        webservice String NameVN;
    }
}