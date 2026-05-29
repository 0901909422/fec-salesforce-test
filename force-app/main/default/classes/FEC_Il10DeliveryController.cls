/**
 * IL10.03 Delivery — init data; query địa chỉ riêng (chỉ FEC_Case__c = null trên bảng).
 * Save/validate vẫn dùng FEC_ContractClosureController.
 */
public without sharing class FEC_Il10DeliveryController {

    public class InitDataDTO {
        @AuraEnabled public FEC_ContractClosureController.InitDataDTO initData;
        @AuraEnabled public FEC_ContractClosureController.AddressRowDTO caseTemporaryAddressRow;
    }

    @AuraEnabled(cacheable=true)
    public static InitDataDTO getInitData(Id caseId) {
        InitDataDTO out = new InitDataDTO();
        out.initData = FEC_ContractClosureController.getInitData(caseId);
        if (out.initData == null || out.initData.success != true || caseId == null) {
            return out;
        }

        Id histId = resolveCustomerHistoryId(caseId);
        if (histId == null) {
            return out;
        }

        out.initData.addresses = queryUnassignedCaseAddresses(histId);
        FEC_Address_Info__c caseTemp = queryCaseTemporaryAddress(caseId, histId);
        if (caseTemp != null) {
            out.caseTemporaryAddressRow = mapAddressInfoToRow(caseTemp);
        }
        return out;
    }

    private static Id resolveCustomerHistoryId(Id caseId) {
        List<Case> rows = [
            SELECT FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].FEC_Account_or_Contract__c;
    }

    private static List<FEC_ContractClosureController.AddressRowDTO> queryUnassignedCaseAddresses(
        Id histId
    ) {
        List<FEC_ContractClosureController.AddressRowDTO> rows = new List<FEC_ContractClosureController.AddressRowDTO>();
        if (
            histId == null ||
            !Schema.sObjectType.FEC_Address_Info__c.isAccessible() ||
            !Schema.SObjectType.FEC_Address_Info__c.fields.FEC_Address_Type__c.isAccessible() ||
            !Schema.SObjectType.FEC_Address_Info__c.fields.FEC_Full_Address__c.isAccessible() ||
            !Schema.SObjectType.FEC_Address_Info__c.fields.FEC_Mailing_Address__c.isAccessible()
        ) {
            return rows;
        }
        for (FEC_Address_Info__c a : [
            SELECT Id, FEC_Address_Type__c, FEC_Full_Address__c, FEC_Mailing_Address__c, FEC_Case__c,
                FEC_Building__c, FEC_Number__c, FEC_Street__c,
                FEC_Ward__c, FEC_Ward__r.FEC_Name_VN__c, FEC_Ward_Text__c,
                FEC_Province__c, FEC_Province__r.FEC_Name_VN__c, FEC_Province_Text__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :histId AND FEC_Case__c = NULL
            ORDER BY FEC_Address_Type__c
        ]) {
            rows.add(mapAddressInfoToRow(a));
        }
        return rows;
    }

    private static FEC_Address_Info__c queryCaseTemporaryAddress(Id caseId, Id histId) {
        List<FEC_Address_Info__c> rows = [
            SELECT Id, FEC_Address_Type__c, FEC_Full_Address__c, FEC_Mailing_Address__c, FEC_Case__c,
                FEC_Building__c, FEC_Number__c, FEC_Street__c,
                FEC_Ward__c, FEC_Ward__r.FEC_Name_VN__c, FEC_Ward_Text__c,
                FEC_Province__c, FEC_Province__r.FEC_Name_VN__c, FEC_Province_Text__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :histId
                AND FEC_Case__c = :caseId
                AND FEC_Address_Type__c = :FEC_ConstantCommon.CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static FEC_ContractClosureController.AddressRowDTO mapAddressInfoToRow(
        FEC_Address_Info__c a
    ) {
        FEC_ContractClosureController.AddressRowDTO row = new FEC_ContractClosureController.AddressRowDTO();
        row.id = a.Id;
        row.addressType = a.FEC_Address_Type__c;
        String wardLabel = String.isNotBlank(a.FEC_Ward_Text__c)
            ? a.FEC_Ward_Text__c
            : (a.FEC_Ward__r == null ? null : a.FEC_Ward__r.FEC_Name_VN__c);
        String provinceLabel = String.isNotBlank(a.FEC_Province_Text__c)
            ? a.FEC_Province_Text__c
            : (a.FEC_Province__r == null ? null : a.FEC_Province__r.FEC_Name_VN__c);
        row.address = a.FEC_Full_Address__c;
        row.mailingAddressLabel = a.FEC_Mailing_Address__c == null
            ? FEC_ConstantCommon.STR_EMPTY
            : String.valueOf(a.FEC_Mailing_Address__c);
        row.building = a.FEC_Building__c;
        row.streetNumber = a.FEC_Number__c;
        row.street = a.FEC_Street__c;
        row.wardRecordId = a.FEC_Ward__c == null ? null : String.valueOf(a.FEC_Ward__c);
        row.provinceRecordId = a.FEC_Province__c == null ? null : String.valueOf(a.FEC_Province__c);
        row.wardLabel = wardLabel;
        row.provinceLabel = provinceLabel;
        return row;
    }
}
