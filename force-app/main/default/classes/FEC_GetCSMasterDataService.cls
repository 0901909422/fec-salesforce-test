/****************************************************************************************
 * File Name    : FEC_GetCSMasterDataService
 * Author       : Quangdv7
 * Date         : 2025-12-11
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-12-11     Quangdv7             Create
 
****************************************************************************************/

global with sharing class FEC_GetCSMasterDataService {

    private static List<AdditionalPropertyType> cachedAdditionalProperties;
    
    // ==========================================================
    // MAIN
    // ==========================================================
    webservice static GetCSMasterDataResponse GetCSMasterDataRequest(
        SysRequestType Sys
    ) {
        GetCSMasterDataResponse res = initResponse(Sys);

        if (Sys == null) {
            throw new CalloutException(
                String.format(
                    System.Label.FEC_MSG_Param_Required,
                    new List<String>{'Sys'}
                )
            );
        }

        // QUERY FEC_Nature_of_Case__c
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
        ];

        // MAP PRODUCT
        Map<String, MasterDataItemType> productMap = new Map<String, MasterDataItemType>();

        for (FEC_Nature_of_Case__c n : records) {

            String pCode = n.FEC_Product_Type__r.FEC_Code__c;
            if (!productMap.containsKey(pCode)) {
                MasterDataItemType p = new MasterDataItemType();
                p.ID = pCode;
                p.Name = n.FEC_Product_Type__r.Name;
                p.NameVN = n.FEC_Product_Type__r.FEC_Name_VN__c;
                p.PosOrder = toInt(n.FEC_Product_Type__r.FEC_Order__c);
                p.ApplyTo = n.FEC_Customer_Type__c;
                p.Type = FEC_ConstantCommon.KEY_PRODUCT_TYPE_PRODUCT;
                p.Children = new List<ChildItemType>();
                productMap.put(pCode, p);
            }

            MasterDataItemType product = productMap.get(pCode);

            // CASE TYPE
            ChildItemType caseType =
                findOrCreateChild(
                    product.Children,
                    n.FEC_Business_Process__r.FEC_Code__c,
                    n.FEC_Business_Process__r.Name,
                    n.FEC_Business_Process__r.FEC_Name_VN__c,
                    n.FEC_Business_Process__r.FEC_Order__c,
                    n.FEC_Customer_Type__c,
                    FEC_ConstantCommon.KEY_CASE_TYPE
                );

            // CATEGORY
            ChildItemType category =
                findOrCreateChild(
                    caseType.Children,
                    n.FEC_Category__r.FEC_Code__c,
                    n.FEC_Category__r.Name,
                    n.FEC_Category__r.FEC_Name_VN__c,
                    n.FEC_Category__r.FEC_Order__c,
                    n.FEC_Customer_Type__c,
                    FEC_ConstantCommon.KEY_CATEGORY
                );

            // SUB CATEGORY
            ChildItemType subCategory =
                findOrCreateChild(
                    category.Children,
                    n.FEC_Sub_Category__r.FEC_Code__c,
                    n.FEC_Sub_Category__r.Name,
                    n.FEC_Sub_Category__r.FEC_Name_VN__c,
                    n.FEC_Sub_Category__r.FEC_Order__c,
                    n.FEC_Customer_Type__c,
                    FEC_ConstantCommon.KEY_SUB_CATEGORY
                );

            // SUB CODE
            ChildItemType subCode =
                findOrCreateChild(
                    subCategory.Children,
                    n.FEC_Sub_Code__r.FEC_Code__c,
                    n.FEC_Sub_Code__r.Name,
                    n.FEC_Sub_Code__r.FEC_Name_VN__c,
                    n.FEC_Sub_Code__r.FEC_Order__c,
                    n.FEC_Customer_Type__c,
                    FEC_ConstantCommon.KEY_SUB_CODE
                );

            if (subCode.AdditionalProperties == null) {
                subCode.AdditionalProperties = getAdditionalProperties();
            }
        }

        res.MasterDataItems = productMap.values();
        res.Sys.Code = System.Label.FEC_Success_Title;
        res.Sys.Description =  System.Label.FEC_MSG_Get_CS_Data_Success;
        return res;
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
        if (children == null) {
            children = new List<ChildItemType>();
        }

        for (ChildItemType c : children) {
            if (c.ID == id) {
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
    // ADDITIONAL PROPERTIES
    // ==========================================================
    private static List<AdditionalPropertyType> getAdditionalProperties() {
        if (cachedAdditionalProperties != null) {
            return cachedAdditionalProperties;
        }

        cachedAdditionalProperties = new List<AdditionalPropertyType>();

        List<FEC_Master_Data_Setting__c> settings = [
            SELECT
                FEC_Field_API_Name__c,
                FEC_Field_Order_Display__c,
                FEC_Field_Mandatory__c,
                FEC_Nature_Of_Case__r.FEC_Customer_Type__c
            FROM FEC_Master_Data_Setting__c
            WHERE FEC_Field_Object_Name__c = 'FEC_Additional_Field__c'
        ];

        for (FEC_Master_Data_Setting__c m : settings) {
            AdditionalPropertyType p = new AdditionalPropertyType();
            p.ID = m.FEC_Field_API_Name__c;
            p.PosOrder = m.FEC_Field_Order_Display__c == null
                ? null
                : Integer.valueOf(m.FEC_Field_Order_Display__c);
            p.ApplyTo = m.FEC_Nature_Of_Case__r != null
                ? m.FEC_Nature_Of_Case__r.FEC_Customer_Type__c
                : null;
            p.Mandatory = m.FEC_Field_Mandatory__c;

            p.Name = getFieldLabel('FEC_Additional_Field__c', p.ID);
            p.NameVN = p.Name;
            p.Type = getFieldType('FEC_Additional_Field__c', p.ID);

            if (p.Type == FEC_ConstantCommon.KEY_PICKLIST) {
                p.AvailableValues =
                    getPicklistValues('FEC_Additional_Field__c', p.ID);
            }

            cachedAdditionalProperties.add(p);
        }

        return cachedAdditionalProperties;
    }


    // ==========================================================
    // UTILS
    // ==========================================================
    private static Integer toInt(Decimal d) {
        return d == null ? null : Integer.valueOf(d);
    }

    private static String getFieldLabel(String obj, String field) {
        return Schema.getGlobalDescribe()
            .get(obj).getDescribe()
            .fields.getMap().get(field)
            .getDescribe().getLabel();
    }

    private static String getFieldType(String obj, String field) {
        Schema.DisplayType t =
            Schema.getGlobalDescribe()
                .get(obj).getDescribe()
                .fields.getMap().get(field)
                .getDescribe().getType();
        if (t == Schema.DisplayType.Picklist) return FEC_ConstantCommon.KEY_PICKLIST;
        if (t == Schema.DisplayType.Boolean) return FEC_ConstantCommon.KEY_CHECKBOX;
        if (t == Schema.DisplayType.Date) return FEC_ConstantCommon.KEY_DATE;
        if (t == Schema.DisplayType.DateTime) return FEC_ConstantCommon.KEY_DATETIME;
        if (t == Schema.DisplayType.Integer || t == Schema.DisplayType.Double) return FEC_ConstantCommon.KEY_NUMBER;
        return FEC_ConstantCommon.KEY_TEXT;
    }

    private static List<AvailableValueType> getPicklistValues(
        String obj, String field
    ) {
        List<AvailableValueType> result = new List<AvailableValueType>();
        for (Schema.PicklistEntry pe :
            Schema.getGlobalDescribe()
                .get(obj).getDescribe()
                .fields.getMap().get(field)
                .getDescribe().getPicklistValues()
        ) {
            AvailableValueType v = new AvailableValueType();
            v.ID = pe.getValue();
            v.Name = pe.getLabel();
            v.NameVN = pe.getLabel();
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

    private static GetCSMasterDataResponse error(
        GetCSMasterDataResponse r, String code, String msg
    ) {
        r.Sys.Code = code;
        r.Sys.Description = msg;
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