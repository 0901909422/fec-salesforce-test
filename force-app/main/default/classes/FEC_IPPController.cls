// FEC_IPPController: IPP Details từ 3 API (GetCardSecInfo, GetCardPlanInfo, GetIPPDetails), merge và trả LWC. Ver 1.0 2025-01-31 Toan.

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

        String accountNumber = getAccountNumberFromCase(caseId);
        if (String.isBlank(accountNumber)) {
            return new List<IPPRecordDTO>();
        }

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting != null && apiSetting.FEC_Call_Mock__c == false) {
            List<IPPRecordDTO> result = fetchIPPRecordsFromAPI(caseId, accountNumber);
            sortByOpenDate(result);
            saveIPPRecordsToDatabase(caseId, result);

            Map<String, String> helpTextMap = getIPPHelpTextMap();
            for (IPPRecordDTO dto : result) {
                dto.helpTexts = helpTextMap;
            }

            return result;
        }

        // Mock mode hoặc apiSetting null: trả về dữ liệu IPP từ DB (nếu có)
        List<IPPRecordDTO> result = loadIPPRecordsFromDatabase(caseId);
        sortByOpenDate(result);
        Map<String, String> helpTextMap = getIPPHelpTextMap();
        for (IPPRecordDTO dto : result) {
            dto.helpTexts = helpTextMap;
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

    // Lấy IPP từ 3 API, merge theo thứ tự: phần tử i của GetCardSecInfo với i của GetCardPlanInfo.
    private static List<IPPRecordDTO> fetchIPPRecordsFromAPI(String caseId, String accountNumber) {
        // Step 1: Get card security info và danh sách IPP giữ nguyên thứ tự (dedup theo RecordNo_Plan)
        FEC_GetCardSecInfo.ResponseWrapper secWrapper = callGetCardSecInfo(accountNumber);
        List<FEC_GetCardSecInfo.IPP> orderedIPPList = buildOrderedIPPList(secWrapper);
        
        // GetCardPlanInfo
        List<FEC_GetCardPlanInfo.CardPlan> cardPlans = callGetCardPlanInfo(accountNumber);
        Boolean hasPlans = cardPlans != null && !cardPlans.isEmpty();
        Boolean hasIPPs = orderedIPPList != null && !orderedIPPList.isEmpty();
        if (!hasPlans && !hasIPPs) {
            return new List<IPPRecordDTO>();
        }

        // Step 3: Build IPP records — đủ cả hai nguồn: theo index, thừa Plan thì chỉ Plan, thừa IPP thì chỉ IPP
        return buildIPPRecordsFromAPIs(accountNumber, cardPlans, orderedIPPList);
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
    
    // Gọi GetCardPlanInfo API
    private static List<FEC_GetCardPlanInfo.CardPlan> callGetCardPlanInfo(String accountNumber) {
        FEC_GetCardPlanInfo.CardPlanResult planResult = FEC_GetCardPlanInfo.getCardPlanInfo(accountNumber);
        if (planResult?.plans != null && !planResult.plans.isEmpty()) {
            return planResult.plans;
        }
        return new List<FEC_GetCardPlanInfo.CardPlan>();
    }
    
    /**
     * Xây dựng IPP records: số bản ghi = max(cardPlans.size(), orderedIPPList.size()).
     * - Cùng index có cả Plan và IPP: merge cardPlans[i] với orderedIPPList[i].
     * - Chỉ có Plan (nhiều Plan hơn IPP): dùng cardPlan, ipp = null.
     * - Chỉ có IPP (nhiều IPP hơn Plan): dùng chỉ GetCardSecInfo IPP, không có CardPlan.
     */
    private static List<IPPRecordDTO> buildIPPRecordsFromAPIs(
        String accountNumber,
        List<FEC_GetCardPlanInfo.CardPlan> cardPlans,
        List<FEC_GetCardSecInfo.IPP> orderedIPPList
    ) {
        List<IPPRecordDTO> result = new List<IPPRecordDTO>();
        Integer planCount = (cardPlans != null) ? cardPlans.size() : 0;
        Integer ippCount = (orderedIPPList != null) ? orderedIPPList.size() : 0;
        Integer maxSize = Math.max(planCount, ippCount);
        if (maxSize == 0) return result;

        String todayStr = Datetime.now().formatGmt(FEC_ConstantCommon.DATE_FORMAT);
        Integer calloutCount = 0;

        for (Integer i = 0; i < maxSize; i++) {
            if (calloutCount >= 50) break;

            FEC_GetCardPlanInfo.CardPlan cardPlan = (i < planCount) ? cardPlans[i] : null;
            FEC_GetCardSecInfo.IPP ipp = (i < ippCount) ? orderedIPPList[i] : null;

            IPPRecordDTO dto;
            if (cardPlan != null) {
                String planNumberKey = String.isNotBlank(cardPlan.planNumber) ? cardPlan.planNumber.trim() : '';
                if (String.isBlank(planNumberKey)) continue;
                dto = buildIPPRecordFromCardPlanAndIPP(cardPlan, ipp, planNumberKey);
            } else {
                // Chỉ có IPP (GetCardSecInfo nhiều hơn GetCardPlanInfo)
                if (ipp == null) continue;
                dto = buildIPPRecordFromIPPOnly(ipp);
            }
            enrichIPPRecordWithDetails(dto, accountNumber, todayStr);
            calloutCount++;
            result.add(dto);
        }
        return result;
    }
    
    // Build DTO chỉ từ GetCardSecInfo IPP (khi không có CardPlan tương ứng)
    private static IPPRecordDTO buildIPPRecordFromIPPOnly(FEC_GetCardSecInfo.IPP ipp) {
        if (ipp == null) return null;
        String planNumberKey = String.isNotBlank(ipp.IPPPlan) ? ipp.IPPPlan.trim() : '';
        String recordNo = (ipp.IPPRecordNo != null) ? ipp.IPPRecordNo.trim() : '';
        if (String.isBlank(planNumberKey)) planNumberKey = HYPHEN;

        IPPRecordDTO dto = new IPPRecordDTO();
        dto.Id = API_PREFIX + planNumberKey + HYPHEN + recordNo;
        dto.planNumber = planNumberKey;
        dto.recordNo = recordNo;
        dto.openDate = null;
        dto.ippBalance = ipp.IPPBalance;
        dto.firstDueDate = FEC_CommonUltils.parseDate(ipp.IPPStartDate);
        dto.matureDate = FEC_CommonUltils.parseDate(ipp.IPPMatureDate);
        dto.currentBalance = ipp.IPPCurrentBalance;
        dto.currentTerm = ipp.currentTerm;
        dto.interestRate = ipp.InterestRate;
        dto.ippTerm = null;
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

    // Build DTO từ CardPlan và IPP
    private static IPPRecordDTO buildIPPRecordFromCardPlanAndIPP(
        FEC_GetCardPlanInfo.CardPlan cardPlan,
        FEC_GetCardSecInfo.IPP ipp,
        String planNumberKey
    ) {
        IPPRecordDTO dto = new IPPRecordDTO();
        
        // Dữ liệu chính từ CardPlan
        dto.planNumber = planNumberKey;
        dto.Id = API_PREFIX + dto.planNumber + HYPHEN + (ipp != null && ipp.IPPRecordNo != null ? ipp.IPPRecordNo : '');
        dto.openDate = FEC_CommonUltils.parseDate(cardPlan.openDate);
        dto.ippBalance = cardPlan.currentBalance;
        
        // Dữ liệu từ GetCardSecInfo IPP
        if (ipp != null) {
            dto.recordNo = (ipp.IPPRecordNo != null) ? ipp.IPPRecordNo.trim() : '';
            dto.firstDueDate = FEC_CommonUltils.parseDate(ipp.IPPStartDate);
            dto.matureDate = FEC_CommonUltils.parseDate(ipp.IPPMatureDate);
            dto.currentBalance = ipp.IPPCurrentBalance;
            dto.currentTerm = ipp.CurrentTerm;
        } else {
            dto.recordNo = '';
            dto.currentBalance = null;
        }
        
        // Fields điền bởi GetIPPDetails
        dto.interestRate = null;
        dto.ippTerm = null;
        dto.totalIPPPaymentAmount = null;
        dto.totalIPPMonthlyPrincipal = null;
        dto.totalIPPMonthlyInterest = null;
        
        // Mặc định cho sales info
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
    
    /**
     * Bổ sung interestRate, ippTerm từ GetIPPDetails API.
     * Bỏ qua khi planNumber rỗng hoặc placeholder (bản ghi chỉ từ GetCardSecInfo).
     */
    private static void enrichIPPRecordWithDetails(IPPRecordDTO dto, String accountNumber, String todayStr) {
        if (dto == null || String.isBlank(dto.planNumber) || HYPHEN.equals(dto.planNumber)) {
            return;
        }
        try {
            FEC_GetIPPDetailsCallout.IPPRequest req = new FEC_GetIPPDetailsCallout.IPPRequest();
            req.accountNumber = accountNumber;
            req.effectiveDate = todayStr;
            req.amount = 1;  // amount > 0 khi lấy InterestRate/IPPTerm
            req.postingDate = todayStr;
            req.planNumber = dto.planNumber;

            FEC_GetIPPDetailsCallout.IPPDetailsResponse detailResp = FEC_GetIPPDetailsCallout.getIPPDetails(req);

            Boolean isSuccess = detailResp != null && (
                detailResp.status == FEC_ConstantCommon.SUCCESS_MESSAGE ||
                detailResp.status == FEC_ConstantCommon.SUCCESS_STATUS_CODE ||
                (detailResp.sysMessage != null && detailResp.sysMessage.equalsIgnoreCase(FEC_ConstantCommon.SUCCESS_MESSAGE))
            );

            if (isSuccess) {
                if (detailResp.interestRate != null) {
                    dto.interestRate = detailResp.interestRate;
                }
                if (String.isNotBlank(detailResp.ippTerm)) {
                    try {
                        dto.ippTerm = Decimal.valueOf(detailResp.ippTerm.trim());
                    } catch (Exception ex) {
                        System.debug('Error parsing ippTerm: ' + ex.getMessage());
                    }
                }
            }
        } catch (Exception e) {
            System.debug('FEC_IPPController.enrichIPPRecordWithDetails for plan ' + dto.planNumber + ': ' + e.getMessage());
        }
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
        Case c = cases[0];
        return (c.FEC_Account_or_Contract__c != null && c.FEC_Account_or_Contract__r != null && String.isNotBlank(c.FEC_Account_or_Contract__r.FEC_Account_Number__c))
            ? c.FEC_Account_or_Contract__r.FEC_Account_Number__c
            : null;
    }


    // Help text map từ FEC_IPP__c field metadata cho LWC
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getIPPHelpTextMap() {
        Map<String, String> helpTextMap = FEC_CommonUltils.buildHelpTextMap(FEC_IPP__c.SObjectType);
        return helpTextMap;
    }
}