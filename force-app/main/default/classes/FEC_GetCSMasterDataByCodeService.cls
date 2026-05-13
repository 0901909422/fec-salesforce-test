/****************************************************************************************
 * File Name    : FEC_GetCSMasterDataByCodeService
 * Author       : Quangdv7
 * Date         : 2025-12-11
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-12-11     Quangdv7             Create
 
****************************************************************************************/

global with sharing class FEC_GetCSMasterDataByCodeService {

    // =========================================================================
    // CONSTANTS
    // =========================================================================
    private static final Integer MAX_LENGTH_STANDARD = 255;
    private static final Set<String> VALID_CHANNELS = new Set<String>{
        FEC_ConstantCommon.KEY_VALID_CHANNELS_WED,
        FEC_ConstantCommon.KEY_VALID_CHANNELS_MOBILE,
        FEC_ConstantCommon.KEY_VALID_CHANNELS_API,
        FEC_ConstantCommon.KEY_VALID_CHANNELS_PORTAL
    };

    // =========================================================================
    // MAIN
    // =========================================================================
    webservice static GetCSMasterDataByCodeResponse GetCSMasterDataByCodeRequest(
        SysRequestType Sys,
        MasterDataCodeType MasterDataCode,
        CustomerTypeRequest CustomerType,
        AdditionalInfoRequest AdditionalInfo,
        String Remarks
    ) {
        GetCSMasterDataByCodeResponse res = initResponse(Sys);

        try {
            // ===== VALIDATION =====
            ValidationResult sysVal = validateSys(Sys);
            if (!sysVal.isValid) return errorResponse(res, sysVal.errorMessage);

            // ===== EXTRACT =====
            String productTypeCode = (MasterDataCode != null) ? MasterDataCode.ProductType : null;
            String caseTypeCode    = (MasterDataCode != null) ? MasterDataCode.CaseType : null;
            String categoryCode    = (MasterDataCode != null) ? MasterDataCode.Category : null;
            String subCategoryCode = (MasterDataCode != null) ? MasterDataCode.SubCategory : null;
            String subCode         = (MasterDataCode != null) ? MasterDataCode.SubCode : null;

            String language = (CustomerType != null && String.isNotBlank(CustomerType.Language))
                ? CustomerType.Language
                : FEC_ConstantCommon.LANGUAGE_EN;

            // ===== QUERY =====
            List<FEC_Nature_of_Case__c> records = queryNatureOfCase(
                productTypeCode,
                caseTypeCode,
                categoryCode,
                subCategoryCode,
                subCode
            );

            // ===== BUILD DATA =====
            res.DataItems = new List<DataItemType>();
            Set<String> uniqueSet = new Set<String>();

            for (FEC_Nature_of_Case__c noc : records) {

                if (noc.FEC_Sub_Category__r != null &&
                    String.isNotBlank(noc.FEC_Sub_Category__r.FEC_Code__c)) {

                    String code = noc.FEC_Sub_Category__r.FEC_Code__c;

                    String name = FEC_CommonUltils.pickNameByLanguage(
                        noc.FEC_Sub_Category__r.Name,
                        noc.FEC_Sub_Category__r.FEC_Name_VN__c,
                        language
                    );

                    String key = code + '|' + name;

                    if (!uniqueSet.contains(key)) {
                        uniqueSet.add(key);

                        DataItemType item = new DataItemType();

                        item.ID = code;
                        item.Name = name;
                        item.NameVN = FEC_CommonUltils.defaultToEmpty(
                            noc.FEC_Sub_Category__r.FEC_Name_VN__c
                        );
                        item.PosOrder = null;
                        item.ApplyTo = FEC_ConstantCommon.STR_EMPTY;

                        item.Type = resolveType(noc);

                        res.DataItems.add(item);
                    }
                }
            }

            // ===== REQUEST INFO =====
            res.RequestInfo = new RequestInfoType();
            res.RequestInfo.Category      = FEC_CommonUltils.defaultToEmpty(categoryCode);
            res.RequestInfo.SubCategory   = FEC_ConstantCommon.STR_EMPTY;
            res.RequestInfo.SubCode       = FEC_ConstantCommon.STR_EMPTY;
            res.RequestInfo.ProductLineId = FEC_CommonUltils.defaultToEmpty(productTypeCode);
            res.RequestInfo.CaseType      = FEC_CommonUltils.defaultToEmpty(caseTypeCode);
            res.RequestInfo.Remarks       = FEC_CommonUltils.defaultToEmpty(Remarks);

            // ===== CUSTOMER =====
            res.CustomerInfo = (CustomerType != null) ? CustomerType : new CustomerTypeRequest();
            res.CustomerInfo.UserType = FEC_CommonUltils.defaultToEmpty(res.CustomerInfo.UserType);
            res.CustomerInfo.Language = FEC_CommonUltils.defaultToEmpty(res.CustomerInfo.Language);

            // ===== ADDITIONAL =====
            res.AdditionalInfo = (AdditionalInfo != null) ? AdditionalInfo : new AdditionalInfoRequest();
            res.AdditionalInfo.ID    = FEC_CommonUltils.defaultToEmpty(res.AdditionalInfo.ID);
            res.AdditionalInfo.Value = FEC_CommonUltils.defaultToEmpty(res.AdditionalInfo.Value);

            // ===== SUCCESS =====
            res.Sys.Code = '1';
            res.Sys.Description = 'Success';

        } catch (Exception e) {
            res.Sys.Code = '0';
            res.Sys.Description = e.getMessage();
        }

        normalizeResponse(res);
        return res;
    }

    // =========================================================================
    // RESOLVE TYPE
    // =========================================================================
    private static String resolveType(FEC_Nature_of_Case__c noc) {

        if (noc.FEC_Sub_Code__r != null &&
            String.isNotBlank(noc.FEC_Sub_Code__r.FEC_Code__c)) {
            return FEC_ConstantCommon.KEY_SUBCODE;
        }

        if (noc.FEC_Sub_Category__r != null &&
            String.isNotBlank(noc.FEC_Sub_Category__r.FEC_Code__c)) {
            return FEC_ConstantCommon.KEY_SUBCATEGORY;
        }

        if (noc.FEC_Category__r != null &&
            String.isNotBlank(noc.FEC_Category__r.FEC_Code__c)) {
            return FEC_ConstantCommon.KEY_CATEGORY;
        }

        if (noc.FEC_Business_Process__r != null &&
            String.isNotBlank(noc.FEC_Business_Process__r.FEC_Code__c)) {
            return FEC_ConstantCommon.KEY_CASETYPE;
        }

        if (noc.FEC_Product_Type__r != null &&
            String.isNotBlank(noc.FEC_Product_Type__r.FEC_Code__c)) {
            return FEC_ConstantCommon.KEY_PRODUCT_TYPE_PRODUCT;
        }

        return FEC_ConstantCommon.STR_EMPTY;
    }

    // =========================================================================
    // QUERY
    // =========================================================================
    private static List<FEC_Nature_of_Case__c> queryNatureOfCase(
        String productTypeCode,
        String caseTypeCode,
        String categoryCode,
        String subCategoryCode,
        String subCode
    ) {
        return [
            SELECT 
                FEC_Product_Type__r.FEC_Code__c,
                FEC_Business_Process__r.FEC_Code__c,
                FEC_Category__r.FEC_Code__c,
                FEC_Sub_Category__r.FEC_Code__c,
                FEC_Sub_Category__r.Name,
                FEC_Sub_Category__r.FEC_Name_VN__c,
                FEC_Sub_Code__r.FEC_Code__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Sub_Category__r.FEC_Code__c != null
        ];
    }

    // =========================================================================
    // VALIDATION
    // =========================================================================
    private static ValidationResult validateSys(SysRequestType Sys) {
        ValidationResult result = new ValidationResult();

        if (Sys == null) {
            result.isValid = false;
            result.errorMessage = System.Label.FEC_MSG_Sys_Null;
            return result;
        }

        // Channel
       if (String.isBlank(Sys.Channel) ||
            !VALID_CHANNELS.contains(Sys.Channel.toUpperCase())) {

            result.isValid = false;
            result.errorMessage =
                System.Label.FEC_MSG_Channel_Validation +
                Sys.Channel +
                System.Label.FEC_MSG_Data_Request_Master_Data;
            return result;
        }

        // TransactionID
        if (String.isBlank(Sys.TransactionID) ||
            Sys.TransactionID.length() > FEC_ConstantCommon.CANCEL_CS_TRANSACTION_ID_MAX_LEN) {

            result.isValid = false;
            result.errorMessage =
                System.Label.FEC_MSG_TransactionId_Validation +
                FEC_ConstantCommon.CANCEL_CS_TRANSACTION_ID_MAX_LEN +
                System.Label.FEC_MSG_Limit_Character;
            return result;
        }

        // DateTime
        if (Sys.DateTime_x == null) {
            result.isValid = false;
            result.errorMessage = System.Label.FEC_MSG_Datetime_Null;
            return result;
        }

        result.isValid = true;
        return result;
    }

    private class ValidationResult {
        Boolean isValid;
        String errorMessage;
    }

    // =========================================================================
    // RESPONSE HELPERS
    // =========================================================================
    private static GetCSMasterDataByCodeResponse errorResponse(GetCSMasterDataByCodeResponse res, String message) {
        res.Sys.Code = '0';
        res.Sys.Description = message;
        return res;
    }

    private static void normalizeResponse(GetCSMasterDataByCodeResponse res) {
        if (res == null) return;

        if (res.Sys == null) res.Sys = new SysResponseType();
        if (res.Sys.DateTime_x == null) res.Sys.DateTime_x = System.now();

        if (res.DataItems == null) res.DataItems = new List<DataItemType>();

        for (DataItemType di : res.DataItems) {
            di.ID = FEC_CommonUltils.defaultToEmpty(di.ID);
            di.Name = FEC_CommonUltils.defaultToEmpty(di.Name);
            di.NameVN = FEC_CommonUltils.defaultToEmpty(di.NameVN);
            di.ApplyTo = FEC_CommonUltils.defaultToEmpty(di.ApplyTo);
            di.Type = FEC_CommonUltils.defaultToEmpty(di.Type);
        }
    }

    private static GetCSMasterDataByCodeResponse initResponse(SysRequestType Sys) {
        GetCSMasterDataByCodeResponse res = new GetCSMasterDataByCodeResponse();
        res.Sys = new SysResponseType();
        res.Sys.TransactionID = (Sys != null) ? Sys.TransactionID : null;
        res.Sys.DateTime_x = System.now();
        return res;
    }

    // =========================================================================
    // DTO
    // =========================================================================
    global class SysRequestType {
        webservice String Channel;
        webservice String TransactionID;
        webservice Datetime DateTime_x;
    }

    global class MasterDataCodeType {
        webservice String ProductType;
        webservice String CaseType;
        webservice String Category;
        webservice String SubCategory;
        webservice String SubCode;
    }

    global class CustomerTypeRequest {
        webservice String UserType;
        webservice String Language;
    }

    global class AdditionalInfoRequest {
        webservice String ID;
        webservice String Value;
    }

    global class GetCSMasterDataByCodeResponse {
        webservice SysResponseType Sys;
        webservice RequestInfoType RequestInfo;
        webservice CustomerTypeRequest CustomerInfo;
        webservice AdditionalInfoRequest AdditionalInfo;
        webservice List<DataItemType> DataItems;
    }

    global class SysResponseType {
        webservice String TransactionID;
        webservice Datetime DateTime_x;
        webservice String Code;
        webservice String Description;
    }

    global class RequestInfoType {
        webservice String Category;
        webservice String SubCategory;
        webservice String SubCode;
        webservice String ProductLineId;
        webservice String CaseType;
        webservice String Remarks;
    }

    global class DataItemType {
        webservice String ID;
        webservice String Name;
        webservice String NameVN;
        webservice Integer PosOrder;
        webservice String ApplyTo;
        webservice String Type;
    }
}