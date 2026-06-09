// FEC_IPPController: IPP Details chỉ từ GetCardSecInfo, trả LWC. Ver 1.1 2026-06-04.

public with sharing class FEC_IPPController {

    private static final String API_PREFIX = 'api-';
    private static final String HYPHEN = '-';

    // DTO trả về cho LWC
    public class IPPRecordDTO {
        @AuraEnabled public String Id { get; set; }
        @AuraEnabled public Map<String, String> helpTexts { get; set; }
        @AuraEnabled public String recordNo { get; set; }
        @AuraEnabled public String planNumber { get; set; }
        @AuraEnabled public Date openDate { get; set; }
        @AuraEnabled public Date firstDueDate { get; set; }
        @AuraEnabled public Date matureDate { get; set; }
        @AuraEnabled public Decimal ippBalance { get; set; }
        @AuraEnabled public Decimal currentBalance { get; set; }
        @AuraEnabled public Decimal interestRate { get; set; }
        @AuraEnabled public Decimal ippTerm { get; set; }
        @AuraEnabled public Decimal currentTerm { get; set; }
        @AuraEnabled public Decimal totalIPPPaymentAmount { get; set; }
        @AuraEnabled public Decimal totalIPPMonthlyPrincipal { get; set; }
        @AuraEnabled public Decimal totalIPPMonthlyInterest { get; set; }
        @AuraEnabled public String ccCode { get; set; }
        @AuraEnabled public String ccName { get; set; }
        @AuraEnabled public String dsaCode { get; set; }
        @AuraEnabled public String dsaName { get; set; }
        @AuraEnabled public String tsaCode { get; set; }
        @AuraEnabled public String tsaName { get; set; }
        @AuraEnabled public String applicationId { get; set; }
        @AuraEnabled public String originationChannel { get; set; }
        @AuraEnabled public String disbursementChannel { get; set; }
    }

    // Mỗi lần load trang đều gọi API, cập nhật DB rồi trả về.
    @AuraEnabled(cacheable=false)
    public static List<IPPRecordDTO> getIPPRecords(String caseId) {
        if (String.isBlank(caseId)) {
            return new List<IPPRecordDTO>();
        }

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        Boolean isMockMode = apiSetting == null || apiSetting.FEC_Call_Mock__c != false;

        if (isMockMode) {
            List<IPPRecordDTO> result = FEC_MockData.getHardcodedIPPRecordsForUI();
            sortByOpenDate(result);
            Map<String, String> helpTextMap = getIPPHelpTextMap();
            for (IPPRecordDTO dto : result) {
                dto.helpTexts = helpTextMap;
            }
            return result;
        }

        String accountNumber = getAccountNumberFromCase(caseId);
        if (String.isBlank(accountNumber)) {
            return new List<IPPRecordDTO>();
        }

        List<IPPRecordDTO> result = fetchIPPRecordsFromAPI(caseId, accountNumber);
        sortByOpenDate(result);
        saveIPPRecordsToDatabase(caseId, result);

        Map<String, String> helpTextMapLive = getIPPHelpTextMap();
        for (IPPRecordDTO dto : result) {
            dto.helpTexts = helpTextMapLive;
        }

        return result;
    }

    private static IPPRecordDTO mapFECIPPToDTO(FEC_IPP__c rec) {
        IPPRecordDTO dto = new IPPRecordDTO();
        dto.Id = rec.Id;
        dto.recordNo = rec.FEC_IPP_Record_No__c;
        dto.planNumber = rec.FEC_IPP_Plan__c;
        dto.openDate = rec.FEC_IPP_Open_Date__c;
        dto.firstDueDate = rec.FEC_IPP_First_Due_Date__c;
        dto.matureDate = rec.FEC_IPP_Mature_Date__c;
        dto.ippBalance = rec.FEC_IPP_Balance__c;
         dto.currentBalance = rec.FEC_IPP_Current_Balance__c;
        dto.interestRate = rec.FEC_IPP_Interest_Rate__c;
        dto.ippTerm = rec.FEC_IPP_Term__c;
        dto.currentTerm = rec.FEC_IPP_Current_Term__c;
        dto.totalIPPPaymentAmount = rec.FEC_Total_IPP_Payment_Amount__c;
        dto.totalIPPMonthlyPrincipal = rec.FEC_Total_IPP_Monthly_Principal__c;
        dto.totalIPPMonthlyInterest = rec.FEC_Total_IPP_Monthly_Interest__c;
        dto.ccCode = rec.FEC_CC_Code__c;
        dto.ccName = rec.FEC_CC_Name__c;
        dto.dsaCode = rec.FEC_DSA_Code__c;
        dto.dsaName = rec.FEC_DSA_Name__c;
        dto.tsaCode = rec.FEC_TSA_Code__c;
        dto.tsaName = rec.FEC_TSA_Name__c;
        dto.applicationId = rec.FEC_Application_ID__c;
        dto.originationChannel = rec.FEC_Origination_Channel__c;
        dto.disbursementChannel = rec.FEC_Disbursement_Channel__c;
        return dto;
    }

    // Lấy IPP chỉ từ GetCardSecInfo (dedup theo RecordNo_Plan).
    private static List<IPPRecordDTO> fetchIPPRecordsFromAPI(String caseId, String accountNumber) {
        FEC_GetCardSecInfo.ResponseWrapper secWrapper = callGetCardSecInfo(accountNumber);
        List<FEC_GetCardSecInfo.IPP> orderedIPPList = buildOrderedIPPList(secWrapper);
        if (orderedIPPList == null || orderedIPPList.isEmpty()) {
            return new List<IPPRecordDTO>();
        }

        List<IPPRecordDTO> result = new List<IPPRecordDTO>();
        for (FEC_GetCardSecInfo.IPP ipp : orderedIPPList) {
            IPPRecordDTO dto = buildIPPRecordFromSecInfo(ipp);
            if (dto != null) {
                result.add(dto);
            }
        }
        return result;
    }
    
    // Gọi GetCardSecInfo API
    private static FEC_GetCardSecInfo.ResponseWrapper callGetCardSecInfo(String accountNumber) {
        return FEC_GetCardSecInfo.getCardSecInfo(accountNumber);
    }
    
    /**
     * Xây dựng danh sách IPP từ GetCardSecInfo giữ nguyên thứ tự trả về từ API.
     * Chỉ lấy 1 IPP duy nhất cho mỗi cặp Plan/RecordNo (bỏ qua schedule items trùng).
     */
    private static List<FEC_GetCardSecInfo.IPP> buildOrderedIPPList(FEC_GetCardSecInfo.ResponseWrapper secWrapper) {
        List<FEC_GetCardSecInfo.IPP> orderedList = new List<FEC_GetCardSecInfo.IPP>();
        if (secWrapper?.CardSecInfo?.IPPs == null) return orderedList;
        Set<String> seen = new Set<String>();
        for (FEC_GetCardSecInfo.IPP ipp : secWrapper.CardSecInfo.IPPs) {
            String key = (ipp.IPPRecordNo != null ? ipp.IPPRecordNo.trim() : '') + '_' +
                        (ipp.IPPPlan != null ? ipp.IPPPlan.trim() : '');
            if (!seen.contains(key)) {
                seen.add(key);
                orderedList.add(ipp);
            }
        }
        return orderedList;
    }
    
    // Build DTO từ GetCardSecInfo IPP
    private static IPPRecordDTO buildIPPRecordFromSecInfo(FEC_GetCardSecInfo.IPP ipp) {
        if (ipp == null) return null;
        String planNumberKey = String.isNotBlank(ipp.IPPPlan) ? ipp.IPPPlan.trim() : '';
        String recordNo = (ipp.IPPRecordNo != null) ? ipp.IPPRecordNo.trim() : '';
        if (String.isBlank(planNumberKey)) planNumberKey = HYPHEN;

        IPPRecordDTO dto = new IPPRecordDTO();
        dto.Id = API_PREFIX + planNumberKey + HYPHEN + recordNo;
        dto.planNumber = planNumberKey;
        dto.recordNo = recordNo;
        dto.openDate = resolveIppOpenDate(ipp);
        dto.ippBalance = ipp.IPPBalance;
        dto.firstDueDate = FEC_CommonUltils.parseDate(ipp.IPPStartDate);
        dto.matureDate = FEC_CommonUltils.parseDate(ipp.IPPMatureDate);
        dto.currentBalance = ipp.IPPCurrentBalance;
        dto.currentTerm = ipp.currentTerm;
        dto.interestRate = ipp.InterestRate;
        dto.ippTerm = ipp.term;
        dto.totalIPPPaymentAmount = null;
        dto.totalIPPMonthlyPrincipal = null;
        dto.totalIPPMonthlyInterest = null;
        dto.ccCode = HYPHEN;
        dto.ccName = HYPHEN;
        dto.dsaCode = HYPHEN;
        dto.dsaName = HYPHEN;
        dto.tsaCode = HYPHEN;
        dto.tsaName = HYPHEN;
        dto.applicationId = HYPHEN;
        dto.originationChannel = HYPHEN;
        dto.disbursementChannel = HYPHEN;
        return dto;
    }

    private static Date resolveIppOpenDate(FEC_GetCardSecInfo.IPP ipp) {
        if (ipp == null) {
            return null;
        }
        Date fromOpen = FEC_CommonUltils.parseDate(ipp.IPPOpenDate);
        if (fromOpen != null) {
            return fromOpen;
        }
        return FEC_CommonUltils.parseDate(ipp.IPPStartDate);
    }

    // Xóa IPP cũ của customer rồi insert mới từ API, cập nhật dto.Id cho LWC.
    private static void saveIPPRecordsToDatabase(String caseId, List<IPPRecordDTO> dtos) {
        if (dtos == null || dtos.isEmpty()) {
            return;
        }
        Id customerHistoryId = getCustomerHistoryIdFromCase(caseId);
        if (customerHistoryId == null) {
            System.debug('FEC_IPPController.saveIPPRecordsToDatabase: no Customer History for Case ' + caseId);
            return;
        }

        try {
            List<FEC_IPP__c> existing = [
                SELECT Id FROM FEC_IPP__c
                WHERE FEC_Customer_History__c = :customerHistoryId
            ];
            if (!existing.isEmpty()) {
                delete existing;
            }
        } catch (Exception e) {
            System.debug('FEC_IPPController.saveIPPRecordsToDatabase delete error: ' + e.getMessage());
        }

        List<FEC_IPP__c> toInsertList = new List<FEC_IPP__c>();
        for (IPPRecordDTO dto : dtos) {
            FEC_IPP__c rec = new FEC_IPP__c();
            rec.FEC_Customer_History__c = customerHistoryId;
            rec.FEC_IPP_Record_No__c = dto.recordNo;
            rec.FEC_IPP_Plan__c = dto.planNumber;
            rec.FEC_IPP_Open_Date__c = dto.openDate;
            rec.FEC_IPP_First_Due_Date__c = dto.firstDueDate;
            rec.FEC_IPP_Mature_Date__c = dto.matureDate;
            rec.FEC_IPP_Balance__c = dto.ippBalance;
            rec.FEC_IPP_Current_Balance__c = dto.currentBalance;
            rec.FEC_IPP_Interest_Rate__c = dto.interestRate;
            rec.FEC_IPP_Term__c = dto.ippTerm;
            rec.FEC_IPP_Current_Term__c = dto.currentTerm;
            // FEC_Total_IPP_Payment_Amount__c, FEC_Total_IPP_Monthly_Principal__c, FEC_Total_IPP_Monthly_Interest__c
            // là Formula hoặc Roll-Up Summary → không gán khi insert
            toInsertList.add(rec);
        }

        try {
            insert toInsertList;
            for (Integer i = 0; i < dtos.size(); i++) {
                if (i < toInsertList.size() && toInsertList[i].Id != null) {
                    dtos[i].Id = toInsertList[i].Id;
                }
            }
        } catch (Exception e) {
            System.debug('FEC_IPPController.saveIPPRecordsToDatabase error: ' + e.getMessage());
            System.debug(e.getStackTraceString());
        }
    }

    private static Id getCustomerHistoryIdFromCase(String caseId) {
        if (String.isBlank(caseId)) {
            return null;
        }
        List<Case> cases = [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return null;
        }
        return cases[0].FEC_Account_or_Contract__c;
    }

    /** Khi FEC_Call_Mock__c = true hoặc apiSetting null: load IPP từ DB theo case (customer history). */
    private static List<IPPRecordDTO> loadIPPRecordsFromDatabase(String caseId) {
        Id customerHistoryId = getCustomerHistoryIdFromCase(caseId);
        if (customerHistoryId == null) {
            return new List<IPPRecordDTO>();
        }
        List<FEC_IPP__c> ipps = [
            SELECT Id, FEC_IPP_Record_No__c, FEC_IPP_Plan__c, FEC_IPP_Open_Date__c, FEC_IPP_First_Due_Date__c,
                   FEC_IPP_Mature_Date__c, FEC_IPP_Balance__c, FEC_IPP_Current_Balance__c, FEC_IPP_Interest_Rate__c,
                   FEC_IPP_Term__c, FEC_IPP_Current_Term__c, FEC_Total_IPP_Payment_Amount__c,
                   FEC_Total_IPP_Monthly_Principal__c, FEC_Total_IPP_Monthly_Interest__c,
                   FEC_CC_Code__c, FEC_CC_Name__c, FEC_DSA_Code__c, FEC_DSA_Name__c,
                   FEC_TSA_Code__c, FEC_TSA_Name__c, FEC_Application_ID__c,
                   FEC_Origination_Channel__c, FEC_Disbursement_Channel__c
            FROM FEC_IPP__c
            WHERE FEC_Customer_History__c = :customerHistoryId
        ];
        List<IPPRecordDTO> dtos = new List<IPPRecordDTO>();
        for (FEC_IPP__c rec : ipps) {
            dtos.add(mapFECIPPToDTO(rec));
        }
        return dtos;
    }

    private static void sortByOpenDate(List<IPPRecordDTO> listToSort) {
        if (listToSort == null || listToSort.size() <= 1) {
            return;
        }
        for (Integer i = 0; i < listToSort.size(); i++) {
            for (Integer j = i + 1; j < listToSort.size(); j++) {
                IPPRecordDTO a = listToSort[i];
                IPPRecordDTO b = listToSort[j];
                Date da = a.openDate;
                Date db = b.openDate;
                if (da == null && db != null) {
                    listToSort[i] = b;
                    listToSort[j] = a;
                } else if (da != null && db != null && da < db) {
                    listToSort[i] = b;
                    listToSort[j] = a;
                }
            }
        }
    }

    /**
     * Tooltip data cho IPP (Sales Info + Schedule totals). Dùng khi có bản ghi FEC_IPP__c từ DB.
     * Nếu recordId bắt đầu bằng 'api-' thì trả về empty (dữ liệu chỉ từ API).
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getIPPTooltipData(String ippRecordId) {
        Map<String, Object> out = new Map<String, Object>();
        out.put('salesInfo', new Map<String, String>());
        out.put('scheduleTotals', new Map<String, Decimal>());

        if (String.isBlank(ippRecordId) || ippRecordId.startsWith(API_PREFIX)) {
            return out;
        }

        List<FEC_IPP__c> ipps = [
            SELECT Id, FEC_IPP_Plan__c,
                   FEC_CC_Code__c, FEC_CC_Name__c, FEC_DSA_Code__c, FEC_DSA_Name__c,
                   FEC_TSA_Code__c, FEC_TSA_Name__c, FEC_Application_ID__c,
                   FEC_Origination_Channel__c, FEC_Disbursement_Channel__c,
                   FEC_Total_IPP_Payment_Amount__c, FEC_Total_IPP_Monthly_Principal__c, FEC_Total_IPP_Monthly_Interest__c
            FROM FEC_IPP__c
            WHERE Id = :ippRecordId
            LIMIT 1
        ];
        if (ipps.isEmpty()) {
            return out;
        }

        FEC_IPP__c ipp = ipps[0];
        Map<String, String> salesInfo = new Map<String, String>();
        salesInfo.put('ccCode', ipp.FEC_CC_Code__c != null ? ipp.FEC_CC_Code__c : HYPHEN);
        salesInfo.put('ccName', ipp.FEC_CC_Name__c != null ? ipp.FEC_CC_Name__c : HYPHEN);
        salesInfo.put('dsaCode', ipp.FEC_DSA_Code__c != null ? ipp.FEC_DSA_Code__c : HYPHEN);
        salesInfo.put('dsaName', ipp.FEC_DSA_Name__c != null ? ipp.FEC_DSA_Name__c : HYPHEN);
        salesInfo.put('tsaCode', ipp.FEC_TSA_Code__c != null ? ipp.FEC_TSA_Code__c : HYPHEN);
        salesInfo.put('tsaName', ipp.FEC_TSA_Name__c != null ? ipp.FEC_TSA_Name__c : HYPHEN);
        salesInfo.put('applicationId', ipp.FEC_Application_ID__c != null ? ipp.FEC_Application_ID__c : HYPHEN);
        salesInfo.put('originationChannel', ipp.FEC_Origination_Channel__c != null ? ipp.FEC_Origination_Channel__c : HYPHEN);
        salesInfo.put('disbursementChannel', ipp.FEC_Disbursement_Channel__c != null ? ipp.FEC_Disbursement_Channel__c : HYPHEN);
        out.put('salesInfo', salesInfo);

        Map<String, Decimal> scheduleTotals = new Map<String, Decimal>();
        scheduleTotals.put('totalPaymentAmount', ipp.FEC_Total_IPP_Payment_Amount__c != null ? ipp.FEC_Total_IPP_Payment_Amount__c : 0);
        scheduleTotals.put('totalMonthlyPrincipal', ipp.FEC_Total_IPP_Monthly_Principal__c != null ? ipp.FEC_Total_IPP_Monthly_Principal__c : 0);
        scheduleTotals.put('totalMonthlyInterest', ipp.FEC_Total_IPP_Monthly_Interest__c != null ? ipp.FEC_Total_IPP_Monthly_Interest__c : 0);
        out.put('scheduleTotals', scheduleTotals);

        return out;
    }

    private static String getAccountNumberFromCase(String caseId) {
        List<Case> cases = [
            SELECT Id, FEC_Account_or_Contract__c, FEC_Account_or_Contract__r.FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return null;
        }
        return getAccountNumberFromCaseRecord(cases[0]);
    }

    /** Giống FEC_CardInfoController: __r → SOQL History → Case.FEC_Account_Number__c */
    private static String getAccountNumberFromCaseRecord(Case c) {
        if (c.FEC_Account_or_Contract__r != null
            && String.isNotBlank(c.FEC_Account_or_Contract__r.FEC_Account_Number__c)) {
            return c.FEC_Account_or_Contract__r.FEC_Account_Number__c;
        }
        if (c.FEC_Account_or_Contract__c != null) {
            List<FEC_Customer_History__c> rows = [
                SELECT FEC_Account_Number__c
                FROM FEC_Customer_History__c
                WHERE Id = :c.FEC_Account_or_Contract__c
                LIMIT 1
            ];
            if (!rows.isEmpty() && String.isNotBlank(rows[0].FEC_Account_Number__c)) {
                return rows[0].FEC_Account_Number__c;
            }
        }
        return c.FEC_Account_Number__c;
    }


    // Help text map từ FEC_IPP__c field metadata cho LWC
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getIPPHelpTextMap() {
        Map<String, String> helpTextMap = FEC_CommonUltils.buildHelpTextMap(FEC_IPP__c.SObjectType);
        return helpTextMap;
    }
}