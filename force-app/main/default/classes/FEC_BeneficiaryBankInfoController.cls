public without sharing class FEC_BeneficiaryBankInfoController {

    private static final String OBJ_BANK_BRANCH = 'FEC_Bank_Branch__c';
    private static final String FLD_BANK_BRANCH_NAME_NOACCENT = 'FEC_Bank_Branch_Name_Noaccent__c';
    private static final String FLD_BANK_NAME_NOACCENT = 'FEC_Bank_Name_Noaccent__c';
    private static final String OBJ_PROVINCE = 'FEC_Province__c';
    private static final String FLD_PROVINCE_NAME_VN = 'FEC_Name_VN__c';
    private static final String OBJ_BANK_NAME = 'FEC_Bank_Name__c';

    public class PicklistOptionDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class RefundFormDefaultsDTO {
        @AuraEnabled public String customerHistoryId;
        @AuraEnabled public String defaultBeneficiaryUpperNoAccent;
        @AuraEnabled public String beneficiaryName;
        @AuraEnabled public String beneficiaryAccount;
        @AuraEnabled public String bankPicklistValue;
        @AuraEnabled public String bankBranch;
        @AuraEnabled public String provinceCity;
    }

    public class SaveBeneficiaryResultDTO {
        @AuraEnabled
        public Boolean success;
        @AuraEnabled
        public String errorMessage;
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionDTO> getBankNamePicklistOptions() {
        List<PicklistOptionDTO> out = new List<PicklistOptionDTO>();
        Schema.SObjectType t = Schema.getGlobalDescribe().get(OBJ_BANK_NAME);
        if (t == null || !t.getDescribe().isAccessible()) {
            return out;
        }
        String soql = 'SELECT ' + FLD_BANK_NAME_NOACCENT + ' FROM ' + OBJ_BANK_NAME
            + ' WHERE ' + FLD_BANK_NAME_NOACCENT + ' != null ORDER BY ' + FLD_BANK_NAME_NOACCENT;
        List<SObject> rows = Security.stripInaccessible(AccessType.READABLE, Database.query(soql)).getRecords();
        Set<String> seen = new Set<String>();
        for (SObject r : rows) {
            String val = (String) r.get(FLD_BANK_NAME_NOACCENT);
            if (String.isBlank(val) || seen.contains(val)) {
                continue;
            }
            seen.add(val);
            PicklistOptionDTO row = new PicklistOptionDTO();
            row.label = val;
            row.value = val;
            out.add(row);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionDTO> getProvinceCityPicklistOptions() {
        List<PicklistOptionDTO> out = new List<PicklistOptionDTO>();
        Schema.SObjectType t = Schema.getGlobalDescribe().get(OBJ_PROVINCE);
        if (t == null || !t.getDescribe().isAccessible()) {
            return out;
        }
        String soql = 'SELECT ' + FLD_PROVINCE_NAME_VN + ' FROM ' + OBJ_PROVINCE
            + ' WHERE ' + FLD_PROVINCE_NAME_VN + ' != null ORDER BY ' + FLD_PROVINCE_NAME_VN;
        List<SObject> rows = Security.stripInaccessible(AccessType.READABLE, Database.query(soql)).getRecords();
        Set<String> seen = new Set<String>();
        for (SObject r : rows) {
            String val = (String) r.get(FLD_PROVINCE_NAME_VN);
            if (String.isBlank(val) || seen.contains(val)) {
                continue;
            }
            seen.add(val);
            PicklistOptionDTO row = new PicklistOptionDTO();
            row.label = val;
            row.value = val;
            out.add(row);
        }
        return out;
    }

    /**
     * Danh sách chi nhánh (giá trị FEC_Bank_Branch_Name_Noaccent__c) theo ngân hàng đã chọn
     * (FEC_Bank_Name__c.FEC_Bank_Name_Noaccent__c). Trả về rỗng nếu bankNameNoaccent blank.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionDTO> getBankBranchPicklistOptions(
        String bankNameNoaccent
    ) {
        List<PicklistOptionDTO> out = new List<PicklistOptionDTO>();
        if (String.isBlank(bankNameNoaccent)) {
            return out;
        }
        Schema.SObjectType t = Schema.getGlobalDescribe().get(OBJ_BANK_BRANCH);
        if (t == null || !t.getDescribe().isAccessible()) {
            return out;
        }
        String bn = bankNameNoaccent.trim();
        String soql =
            'SELECT ' +
            FLD_BANK_BRANCH_NAME_NOACCENT +
            ' FROM ' +
            OBJ_BANK_BRANCH +
            ' WHERE ' +
            FLD_BANK_BRANCH_NAME_NOACCENT +
            ' != null AND FEC_Bank_Name__r.' +
            FLD_BANK_NAME_NOACCENT +
            ' = :bn ORDER BY ' +
            FLD_BANK_BRANCH_NAME_NOACCENT;
        List<SObject> rows = Security.stripInaccessible(AccessType.READABLE, Database.query(soql)).getRecords();
        Set<String> seen = new Set<String>();
        for (SObject r : rows) {
            String val = (String) r.get(FLD_BANK_BRANCH_NAME_NOACCENT);
            if (String.isBlank(val) || seen.contains(val)) {
                continue;
            }
            seen.add(val);
            PicklistOptionDTO row = new PicklistOptionDTO();
            row.label = val;
            row.value = val;
            out.add(row);
        }
        return out;
    }

    @AuraEnabled
    public static RefundFormDefaultsDTO getBeneficiaryFormDefaults(Id caseId) {
        RefundFormDefaultsDTO dto = new RefundFormDefaultsDTO();
        if (caseId == null || !Schema.sObjectType.Case.isAccessible()) {
            return dto;
        }
        List<Case> caseRows = [
            SELECT Id,
                FEC_Account_or_Contract__c,
                FEC_Beneficiary_Name__c,
                FEC_Beneficiary_Account__c,
                FEC_Bank_Name_Noaccent__c,
                FEC_Bank_Branch_Name_Noaccent__c,
                FEC_Province_City__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        caseRows = (List<Case>) Security.stripInaccessible(AccessType.READABLE, caseRows).getRecords();
        if (caseRows.isEmpty()) {
            return dto;
        }
        Case c = caseRows[0];
        dto.customerHistoryId = c.FEC_Account_or_Contract__c;
        dto.beneficiaryAccount = c.FEC_Beneficiary_Account__c;
        dto.bankPicklistValue = c.FEC_Bank_Name_Noaccent__c;
        dto.bankBranch = c.FEC_Bank_Branch_Name_Noaccent__c;
        dto.provinceCity = c.FEC_Province_City__c;
        if (String.isNotBlank(c.FEC_Beneficiary_Name__c)) {
            dto.beneficiaryName = c.FEC_Beneficiary_Name__c;
            return dto;
        }
        if (c.FEC_Account_or_Contract__c == null || !Schema.sObjectType.FEC_Customer_History__c.isAccessible()) {
            return dto;
        }
        List<FEC_Customer_History__c> histories = [
            SELECT Id,
                FEC_Customer_Name__c,
                FEC_First_Name__c,
                FEC_Middle_Name__c,
                FEC_Last_Name__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        histories = (List<FEC_Customer_History__c>) Security.stripInaccessible(AccessType.READABLE, histories).getRecords();
        if (histories.isEmpty()) {
            return dto;
        }
        FEC_Customer_History__c h = histories[0];
        String rawName = h.FEC_Customer_Name__c;
        if (String.isBlank(rawName)) {
            List<String> parts = new List<String>();
            if (String.isNotBlank(h.FEC_First_Name__c)) {
                parts.add(h.FEC_First_Name__c.trim());
            }
            if (String.isNotBlank(h.FEC_Middle_Name__c)) {
                parts.add(h.FEC_Middle_Name__c.trim());
            }
            if (String.isNotBlank(h.FEC_Last_Name__c)) {
                parts.add(h.FEC_Last_Name__c.trim());
            }
            rawName = String.join(parts, ' ');
        }
        dto.defaultBeneficiaryUpperNoAccent = FEC_CommonUltils.toUpperNoVietnameseAccent(rawName);
        dto.beneficiaryName = dto.defaultBeneficiaryUpperNoAccent;
        return dto;
    }

    @AuraEnabled
    public static SaveBeneficiaryResultDTO saveBeneficiaryBankInfo(
        Id caseId,
        String beneficiaryName,
        String beneficiaryAccount,
        String bankPicklistValue,
        String bankBranch,
        String provinceCity
    ) {
        SaveBeneficiaryResultDTO res = new SaveBeneficiaryResultDTO();
        res.success = false;
        if (caseId == null) {
            res.errorMessage = String.format(
                System.Label.FEC_MSG_Param_Required,
                new List<String>{ 'Case Id' }
            );
            return res;
        }
        if (!Schema.sObjectType.Case.isUpdateable()) {
            res.errorMessage = System.Label.FEC_MSG_Insufficient_Access;
            return res;
        }
        if (
            String.isBlank(beneficiaryName) ||
            String.isBlank(beneficiaryAccount) ||
            String.isBlank(bankBranch) ||
            String.isBlank(provinceCity)
        ) {
            res.errorMessage = System.Label.FEC_MSG_Card_Block_Beneficiary_Required;
            return res;
        }
        if (String.isBlank(bankPicklistValue)) {
            res.errorMessage = String.format(
                System.Label.FEC_MSG_Param_Required,
                new List<String>{ System.Label.FEC_LBL_Bank_Name }
            );
            return res;
        }
        String bn = bankPicklistValue.trim();
        String br = bankBranch.trim();
        String pv = provinceCity.trim();
        if (!isValidProvinceNameVn(pv)) {
            res.errorMessage = String.format(
                System.Label.FEC_MSG_Not_Found,
                new List<String>{ System.Label.FEC_LBL_Province_City }
            );
            return res;
        }
        List<Case> caseRows = [
            SELECT Id
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        caseRows = (List<Case>) Security.stripInaccessible(AccessType.READABLE, caseRows).getRecords();
        if (caseRows.isEmpty()) {
            res.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Case' });
            return res;
        }
        Case c = caseRows[0];
        try {
            Case caseUpd = new Case(
                Id = c.Id,
                FEC_Beneficiary_Name__c = beneficiaryName.trim(),
                FEC_Beneficiary_Account__c = beneficiaryAccount.trim(),
                FEC_Bank_Name_Noaccent__c = bn,
                FEC_Bank_Branch_Name_Noaccent__c = br,
                FEC_Province_City__c = pv
            );
            SObjectAccessDecision caseDec = Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<SObject>{ caseUpd }
            );
            if (caseDec.getRecords().isEmpty()) {
                res.errorMessage = System.Label.FEC_MSG_Insufficient_Access;
                return res;
            }
            update caseDec.getRecords();
            res.success = true;
        } catch (DmlException e) {
            res.errorMessage = e.getDmlMessage(0);
        } catch (Exception e) {
            res.errorMessage = System.Label.FEC_Toast_Save_Error_Message;
        }
        return res;
    }

    /**
     * Lưu nháp thông tin người thụ hưởng lên Case (cho phép bỏ trống một phần trường).
     */
    @AuraEnabled
    public static void saveBeneficiaryBankInfoDraft(
        Id caseId,
        String beneficiaryName,
        String beneficiaryAccount,
        String bankPicklistValue,
        String bankBranch,
        String provinceCity
    ) {
        if (caseId == null) {
            throw new AuraHandledException(
                String.format(
                    System.Label.FEC_MSG_Param_Required,
                    new List<String>{ 'Case Id' }
                )
            );
        }
        if (!Schema.sObjectType.Case.isUpdateable()) {
            throw new AuraHandledException(System.Label.FEC_MSG_Insufficient_Access);
        }
        List<Case> caseRows = [
            SELECT Id
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        caseRows = (List<Case>) Security.stripInaccessible(AccessType.READABLE, caseRows).getRecords();
        if (caseRows.isEmpty()) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Case' })
            );
        }
        Case c = caseRows[0];
        try {
            String bn = String.isNotBlank(bankPicklistValue) ? bankPicklistValue.trim() : null;
            String br = String.isNotBlank(bankBranch) ? bankBranch.trim() : null;
            String pv = String.isNotBlank(provinceCity) ? provinceCity.trim() : null;
            if (String.isNotBlank(bn) && String.isNotBlank(br) && String.isNotBlank(pv)) {
                if (!isValidProvinceNameVn(pv)) {
                    throw new AuraHandledException(
                        String.format(
                            System.Label.FEC_MSG_Not_Found,
                            new List<String>{ System.Label.FEC_LBL_Province_City }
                        )
                    );
                }
            } else if (String.isNotBlank(pv)) {
                if (!isValidProvinceNameVn(pv)) {
                    throw new AuraHandledException(
                        String.format(
                            System.Label.FEC_MSG_Not_Found,
                            new List<String>{ System.Label.FEC_LBL_Province_City }
                        )
                    );
                }
            }
            Case caseUpd = new Case(
                Id = c.Id,
                FEC_Beneficiary_Name__c = String.isNotBlank(beneficiaryName) ? beneficiaryName.trim() : null,
                FEC_Beneficiary_Account__c = String.isNotBlank(beneficiaryAccount)
                    ? beneficiaryAccount.trim()
                    : null,
                FEC_Bank_Name_Noaccent__c = bn,
                FEC_Bank_Branch_Name_Noaccent__c = br,
                FEC_Province_City__c = pv
            );
            SObjectAccessDecision caseDec = Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<SObject>{ caseUpd }
            );
            if (caseDec.getRecords().isEmpty()) {
                throw new AuraHandledException(System.Label.FEC_MSG_Insufficient_Access);
            }
            update caseDec.getRecords();
        } catch (AuraHandledException e) {
            throw e;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Toast_Save_Error_Message);
        }
    }

    private static Boolean isValidProvinceNameVn(String nameVn) {
        if (String.isBlank(nameVn) || !Schema.sObjectType.FEC_Province__c.isAccessible()) {
            return false;
        }
        String pv = nameVn.trim();
        List<FEC_Province__c> rows = [
            SELECT Id
            FROM FEC_Province__c
            WHERE FEC_Name_VN__c = :pv
            LIMIT 1
        ];
        rows = (List<FEC_Province__c>) Security.stripInaccessible(AccessType.READABLE, rows).getRecords();
        return !rows.isEmpty();
    }
}