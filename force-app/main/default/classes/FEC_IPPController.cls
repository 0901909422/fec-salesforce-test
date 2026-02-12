/****************************************************************************************
 * File Name    : FEC_IPPController
 * Description  : Gọi 3 API (GetCardSecInfo, GetCardPlanInfo, GetIPPDetails) để lấy dữ
 *                liệu hiển thị bảng IPP Details. Merge response và trả về format cho LWC.
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
 * 1.0      2025-01-31     Toan              Create - getIPPRecords từ 3 API
 ****************************************************************************************/

public with sharing class FEC_IPPController {

    // ==========================================
    // DTO CLASSES - Data Transfer Objects
    // ==========================================
    public class IPPApiResponse {
        public String transId;
        public String sysDateTime;
        public String responseCode;
        public String responseDesc;
        public List<IPPPlanDTO> plans;
        
        public IPPApiResponse() {
            plans = new List<IPPPlanDTO>();
        }
    }
    
    public class IPPPlanDTO {
        public String recordNumber;
        public String planNumber;
        public String openDate;
        public String beginDate;
        public String matureDate;
        public Decimal currentBalance;
        public Decimal ippCurrentBalance;
        public Decimal baseRate;
        public Decimal deferredInterest;
        public Decimal accruedInterest;
        public Decimal perDiem;
        public Integer aggregateDays;
        public Decimal ippInterest;
        public String closeFeeIndicator;
        public Decimal closeFeeIndicatorAmt;
        public Decimal closeFeeAmount;
        public Decimal additionalAccruedInt;
        public Decimal totalPaymentAmount;
        public String refNumber;
    }

    // =========================================================================
    // DTO trả về cho LWC
    // =========================================================================
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

    /**
     * Luồng: ưu tiên query từ database (FEC_IPP__c).
     * Nếu database không có dữ liệu thì gọi 3 API (GetCardSecInfo, GetCardPlanInfo, GetIPPDetails),
     * lưu vào database rồi trả về. Lần sau chỉ cần query database.
     */
    @AuraEnabled(cacheable=false)
    public static List<IPPRecordDTO> getIPPRecords(String caseId) {
        if (String.isBlank(caseId)) {
            return new List<IPPRecordDTO>();
        }

        Id customerHistoryId = getCustomerHistoryIdFromCase(caseId);

        Map<String, Schema.SObjectField> fields = FEC_IPP__c.SObjectType.getDescribe().fields.getMap();

        // 1. Ưu tiên query từ database
        if (customerHistoryId != null) {
            List<FEC_IPP__c> fromDb = [
                SELECT Id, FEC_IPP_Record_No__c, FEC_IPP_Plan__c, FEC_IPP_Open_Date__c, FEC_IPP_First_Due_Date__c,
                       FEC_IPP_Mature_Date__c, FEC_IPP_Balance__c, FEC_IPP_Current_Balance__c, FEC_IPP_Interest_Rate__c,
                       FEC_IPP_Term__c, FEC_IPP_Current_Term__c, FEC_Total_IPP_Payment_Amount__c,
                       FEC_Total_IPP_Monthly_Principal__c, FEC_Total_IPP_Monthly_Interest__c,
                       FEC_CC_Code__c, FEC_CC_Name__c, FEC_DSA_Code__c, FEC_DSA_Name__c,
                       FEC_TSA_Code__c, FEC_TSA_Name__c, FEC_Application_ID__c,
                       FEC_Origination_Channel__c, FEC_Disbursement_Channel__c
                FROM FEC_IPP__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                ORDER BY FEC_IPP_Open_Date__c ASC NULLS LAST
            ];
            if (fromDb != null && !fromDb.isEmpty()) {
                List<IPPRecordDTO> result = new List<IPPRecordDTO>();
                Map<String, String> helpTextMap = FEC_CommonUltils.buildHelpTextMap(fields);
                for (FEC_IPP__c rec : fromDb) {
                    IPPRecordDTO dto = mapFECIPPToDTO(rec);
                    dto.helpTexts = helpTextMap;
                    result.add(dto);
                }
                return result;
            }
        }

        // 2. Database không có dữ liệu → gọi API, lưu DB, trả về
        String accountNumber = getAccountNumberFromCase(caseId);
        if (String.isBlank(accountNumber)) {
            return new List<IPPRecordDTO>();
        }

        List<IPPRecordDTO> result = fetchIPPRecordsFromAPI(caseId, accountNumber);
        sortByOpenDate(result);
        saveIPPRecordsToDatabase(caseId, result);
        
        // Gán help texts cho tất cả records
        Map<String, String> helpTextMap = FEC_CommonUltils.buildHelpTextMap(fields);
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
        dto.ippBalance = rec.FEC_IPP_Balance__c != null ? rec.FEC_IPP_Balance__c : 0;
        dto.currentBalance = rec.FEC_IPP_Current_Balance__c != null ? rec.FEC_IPP_Current_Balance__c : 0;
        dto.interestRate = rec.FEC_IPP_Interest_Rate__c;
        dto.ippTerm = rec.FEC_IPP_Term__c;
        dto.currentTerm = rec.FEC_IPP_Current_Term__c;
        dto.totalIPPPaymentAmount = rec.FEC_Total_IPP_Payment_Amount__c != null ? rec.FEC_Total_IPP_Payment_Amount__c : 0;
        dto.totalIPPMonthlyPrincipal = rec.FEC_Total_IPP_Monthly_Principal__c != null ? rec.FEC_Total_IPP_Monthly_Principal__c : 0;
        dto.totalIPPMonthlyInterest = rec.FEC_Total_IPP_Monthly_Interest__c != null ? rec.FEC_Total_IPP_Monthly_Interest__c : 0;
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

    /**
     * Lấy danh sách IPP records: gọi 3 API (GetCardSecInfo, GetCardPlanInfo, GetIPPDetails),
     * merge theo key = CardPlan.PlanNumber (IPP Plan).
     */
    private static List<IPPRecordDTO> fetchIPPRecordsFromAPI(String caseId, String accountNumber) {
        // Step 1: Get card security info and build lookup maps
        FEC_GetCardSecInfo.ResponseWrapper secWrapper = callGetCardSecInfo(accountNumber);
        Map<String, FEC_GetCardSecInfo.IPP> planNumberToIpp = new Map<String, FEC_GetCardSecInfo.IPP>();
        Map<String, FEC_GetCardSecInfo.IPP> recordNoToIpp = new Map<String, FEC_GetCardSecInfo.IPP>();
        buildIPPLookupMaps(secWrapper, planNumberToIpp, recordNoToIpp);
        
        // Step 2: Get card plan info
        List<FEC_GetCardPlanInfo.CardPlan> cardPlans = callGetCardPlanInfo(accountNumber);
        if (cardPlans.isEmpty()) {
            return new List<IPPRecordDTO>();
        }
        
        // Step 3: Build IPP records by merging data from 3 APIs
        return buildIPPRecordsFromAPIs(accountNumber, cardPlans, planNumberToIpp, recordNoToIpp);
    }
    
    /**
     * Gọi GetCardSecInfo API
     */
    private static FEC_GetCardSecInfo.ResponseWrapper callGetCardSecInfo(String accountNumber) {
        try {
            return FEC_GetCardSecInfo.getCardSecInfo(accountNumber);
        } catch (Exception e) {
            System.debug('FEC_IPPController.callGetCardSecInfo error: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Xây dựng các lookup maps cho dữ liệu IPP từ GetCardSecInfo
     * Chỉ lấy 1 IPP record duy nhất cho mỗi Plan/RecordNo (bỏ qua schedule items duplicate)
     */
    private static void buildIPPLookupMaps(
        FEC_GetCardSecInfo.ResponseWrapper secWrapper,
        Map<String, FEC_GetCardSecInfo.IPP> planNumberToIpp,
        Map<String, FEC_GetCardSecInfo.IPP> recordNoToIpp
    ) {
        if (secWrapper?.CardSecInfo?.IPPs == null) return;
        
        // Group by Plan/RecordNo to avoid duplicates from schedule items
        Map<String, FEC_GetCardSecInfo.IPP> uniqueIPPs = new Map<String, FEC_GetCardSecInfo.IPP>();
        
        for (FEC_GetCardSecInfo.IPP ipp : secWrapper.CardSecInfo.IPPs) {
            String key = (ipp.IPPRecordNo != null ? ipp.IPPRecordNo.trim() : '') + '_' + 
                        (ipp.IPPPlan != null ? ipp.IPPPlan.trim() : '');
            
            // Chỉ lấy IPP đầu tiên cho mỗi Plan/RecordNo combination
            if (!uniqueIPPs.containsKey(key)) {
                uniqueIPPs.put(key, ipp);
            }
        }
        
        // Build lookup maps from unique IPPs
        for (FEC_GetCardSecInfo.IPP ipp : uniqueIPPs.values()) {
            // Map by plan number
            if (ipp.IPPPlan != null && String.isNotBlank(ipp.IPPPlan.trim())) {
                if (!planNumberToIpp.containsKey(ipp.IPPPlan.trim())) {
                    planNumberToIpp.put(ipp.IPPPlan.trim(), ipp);
                }
            }
            
            // Map by record number
            if (ipp.IPPRecordNo != null && String.isNotBlank(ipp.IPPRecordNo.trim())) {
                String rn = ipp.IPPRecordNo.trim();
                recordNoToIpp.put(rn, ipp);
                recordNoToIpp.put('REC' + rn, ipp);
            }
        }
    }
    
    /**
     * Gọi GetCardPlanInfo API
     */
    private static List<FEC_GetCardPlanInfo.CardPlan> callGetCardPlanInfo(String accountNumber) {
        try {
            FEC_GetCardPlanInfo.CardPlanResult planResult = FEC_GetCardPlanInfo.getCardPlanInfo(accountNumber);
            if (planResult?.plans != null && !planResult.plans.isEmpty()) {
                return planResult.plans;
            }
        } catch (Exception e) {
            System.debug('FEC_IPPController.callGetCardPlanInfo error: ' + e.getMessage());
        }
        return new List<FEC_GetCardPlanInfo.CardPlan>();
    }
    
    /**
     * Xây dựng IPP records bằng cách merge dữ liệu từ cả 3 APIs
     */
    private static List<IPPRecordDTO> buildIPPRecordsFromAPIs(
        String accountNumber,
        List<FEC_GetCardPlanInfo.CardPlan> cardPlans,
        Map<String, FEC_GetCardSecInfo.IPP> planNumberToIpp,
        Map<String, FEC_GetCardSecInfo.IPP> recordNoToIpp
    ) {
        List<IPPRecordDTO> result = new List<IPPRecordDTO>();
        String todayStr = Datetime.now().formatGmt('yyyy-MM-dd');
        Integer calloutCount = 0;
        
        for (FEC_GetCardPlanInfo.CardPlan cardPlan : cardPlans) {
            if (calloutCount >= 50) { 
                break;
            }
            if (String.isBlank(cardPlan.planNumber)) {
                continue;
            }
            
            String planNumberKey = cardPlan.planNumber.trim();
            FEC_GetCardSecInfo.IPP ipp = findMatchingIPP(cardPlan, planNumberKey, planNumberToIpp, recordNoToIpp);
            
            // Build DTO from CardPlan and IPP
            IPPRecordDTO dto = buildIPPRecordFromCardPlanAndIPP(cardPlan, ipp, planNumberKey);
            
            // Enrich with GetIPPDetails data
            enrichIPPRecordWithDetails(dto, accountNumber, todayStr);
            calloutCount++;
            
            result.add(dto);
        }
        
        return result;
    }
    
    /**
     * Tìm IPP khớp từ GetCardSecInfo theo plan number hoặc record number
     */
    private static FEC_GetCardSecInfo.IPP findMatchingIPP(
        FEC_GetCardPlanInfo.CardPlan cardPlan,
        String planNumberKey,
        Map<String, FEC_GetCardSecInfo.IPP> planNumberToIpp,
        Map<String, FEC_GetCardSecInfo.IPP> recordNoToIpp
    ) {
        FEC_GetCardSecInfo.IPP ipp = planNumberToIpp.get(planNumberKey);
        
        if (ipp == null && String.isNotBlank(cardPlan.recordNumber)) {
            String rn = cardPlan.recordNumber.trim();
            ipp = recordNoToIpp.get(rn);
            if (ipp == null && rn.length() > 3 && rn.startsWith('REC')) {
                ipp = recordNoToIpp.get(rn.substring(3));
            }
        }
        
        return ipp;
    }
    
    /**
     * Xây dựng IPP record DTO từ dữ liệu CardPlan và IPP
     */
    private static IPPRecordDTO buildIPPRecordFromCardPlanAndIPP(
        FEC_GetCardPlanInfo.CardPlan cardPlan,
        FEC_GetCardSecInfo.IPP ipp,
        String planNumberKey
    ) {
        IPPRecordDTO dto = new IPPRecordDTO();
        
        // Dữ liệu chính từ CardPlan
        dto.planNumber = planNumberKey;
        dto.Id = 'api-' + dto.planNumber + '-' + (ipp != null && ipp.IPPRecordNo != null ? ipp.IPPRecordNo : '');
        dto.openDate = FEC_CommonUltils.parseDate(cardPlan.openDate);
        dto.ippBalance = (cardPlan.currentBalance != null) ? cardPlan.currentBalance : 0;
        
        // Dữ liệu từ GetCardSecInfo IPP (nếu match)
        if (ipp != null) {
            dto.recordNo = (ipp.IPPRecordNo != null) ? ipp.IPPRecordNo.trim() : '';
            dto.firstDueDate = FEC_CommonUltils.parseDate(ipp.IPPStartDate);
            dto.matureDate = FEC_CommonUltils.parseDate(ipp.IPPMatureDate);
            dto.currentBalance = (ipp.IPPCurrentBalance != null) ? ipp.IPPCurrentBalance : 0;
            dto.currentTerm = ipp.CurrentTerm;
        } else {
            dto.recordNo = '';
            dto.currentBalance = 0;
        }
        
        // Khởi tạo các fields sẽ được điền bởi GetIPPDetails
        dto.interestRate = null;
        dto.ippTerm = null;
        dto.totalIPPPaymentAmount = 0;
        dto.totalIPPMonthlyPrincipal = 0;
        dto.totalIPPMonthlyInterest = 0;
        
        // Giá trị mặc định cho các fields sales info
        dto.ccCode = '-';
        dto.ccName = '-';
        dto.dsaCode = '-';
        dto.dsaName = '-';
        dto.tsaCode = '-';
        dto.tsaName = '-';
        dto.applicationId = '-';
        dto.originationChannel = '-';
        dto.disbursementChannel = '-';
        
        return dto;
    }
    
    /**
     * IPP record với dữ liệu từ GetIPPDetails API
     */
    private static void enrichIPPRecordWithDetails(IPPRecordDTO dto, String accountNumber, String todayStr) {
        try {
            FEC_GetIPPDetailsCallout.IPPRequest req = new FEC_GetIPPDetailsCallout.IPPRequest();
            req.accountNumber = accountNumber;
            req.effectiveDate = todayStr;
            req.amount = 0;
            req.postingDate = todayStr;
            req.planNumber = dto.planNumber;
            
            FEC_GetIPPDetailsCallout.IPPDetailsResponse detailResp = FEC_GetIPPDetailsCallout.getIPPDetails(req);
            
            Boolean isSuccess = detailResp != null && (
                detailResp.status == 'SUCCESS' ||
                detailResp.status == '0' ||
                (detailResp.sysMessage != null && detailResp.sysMessage.equalsIgnoreCase('Success'))
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

    /**
     * Lưu danh sách IPP (từ API) vào FEC_IPP__c. Chỉ insert (không upsert).
     * Sau khi lưu, cập nhật dto.Id = Id bản ghi đã lưu để LWC dùng cho tooltip/navigation.
     */
    private static void saveIPPRecordsToDatabase(String caseId, List<IPPRecordDTO> dtos) {
        if (dtos == null || dtos.isEmpty()) {
            return;
        }
        Id customerHistoryId = getCustomerHistoryIdFromCase(caseId);
        if (customerHistoryId == null) {
            System.debug('FEC_IPPController.saveIPPRecordsToDatabase: no Customer History for Case ' + caseId);
            return;
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
            SELECT Id, FEC_Account_or_Contract__c, FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return null;
        }
        Case c = cases[0];
        if (c.FEC_Account_or_Contract__c != null) {
            return c.FEC_Account_or_Contract__c;
        }
        if (String.isNotBlank(c.FEC_Account_Number__c)) {
            List<FEC_Customer_History__c> histories = [
                SELECT Id FROM FEC_Customer_History__c
                WHERE FEC_Account_Number__c = :c.FEC_Account_Number__c
                LIMIT 1
            ];
            if (!histories.isEmpty()) {
                return histories[0].Id;
            }
        }
        // Fallback: tìm Customer History qua FEC_Case__c (cho Interaction record type)
        List<FEC_Customer_History__c> historiesByCase = [
            SELECT Id FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :caseId
            LIMIT 1
        ];
        return (historiesByCase.isEmpty()) ? null : historiesByCase[0].Id;
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
                } else if (da != null && db != null && da > db) {
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

        if (String.isBlank(ippRecordId) || ippRecordId.startsWith('api-')) {
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
        salesInfo.put('ccCode', ipp.FEC_CC_Code__c != null ? ipp.FEC_CC_Code__c : '-');
        salesInfo.put('ccName', ipp.FEC_CC_Name__c != null ? ipp.FEC_CC_Name__c : '-');
        salesInfo.put('dsaCode', ipp.FEC_DSA_Code__c != null ? ipp.FEC_DSA_Code__c : '-');
        salesInfo.put('dsaName', ipp.FEC_DSA_Name__c != null ? ipp.FEC_DSA_Name__c : '-');
        salesInfo.put('tsaCode', ipp.FEC_TSA_Code__c != null ? ipp.FEC_TSA_Code__c : '-');
        salesInfo.put('tsaName', ipp.FEC_TSA_Name__c != null ? ipp.FEC_TSA_Name__c : '-');
        salesInfo.put('applicationId', ipp.FEC_Application_ID__c != null ? ipp.FEC_Application_ID__c : '-');
        salesInfo.put('originationChannel', ipp.FEC_Origination_Channel__c != null ? ipp.FEC_Origination_Channel__c : '-');
        salesInfo.put('disbursementChannel', ipp.FEC_Disbursement_Channel__c != null ? ipp.FEC_Disbursement_Channel__c : '-');
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
            SELECT Id, FEC_Account_Number__c, FEC_Account_or_Contract__c,
                   FEC_Account_or_Contract__r.FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return null;
        }
        Case c = cases[0];
        if (c.FEC_Account_or_Contract__c != null && String.isNotBlank(c.FEC_Account_or_Contract__r?.FEC_Account_Number__c)) {
            return c.FEC_Account_or_Contract__r.FEC_Account_Number__c;
        }
        return c.FEC_Account_Number__c;
    }

    
    /**
     * Gọi API GetCardPlanInfo thông qua FEC_GetCardPlanInfo class
     * @param accountNumber - Account Number
     * @param caseId - Case ID (optional, có thể null)
     * @return IPPApiResponse
     */
    private static IPPApiResponse callGetCardPlanInfoAPI(String accountNumber, String caseId) {
        // Gọi method từ FEC_GetCardPlanInfo
        FEC_GetCardPlanInfo.CardPlanResult apiResult = FEC_GetCardPlanInfo.getCardPlanInfo(accountNumber);
        
        // Convert sang DTO của IPPController
        IPPApiResponse response = new IPPApiResponse();
        response.transId = apiResult.transId;
        response.sysDateTime = apiResult.sysDateTime;
        response.responseCode = apiResult.responseCode;
        response.responseDesc = apiResult.responseDesc;
        
        // Map plans
        for (FEC_GetCardPlanInfo.CardPlan apiPlan : apiResult.plans) {
            IPPPlanDTO dto = new IPPPlanDTO();
            dto.recordNumber = apiPlan.recordNumber;
            dto.planNumber = apiPlan.planNumber;
            dto.openDate = apiPlan.openDate;
            dto.beginDate = apiPlan.beginDate;
            dto.matureDate = null; 
            dto.currentBalance = apiPlan.currentBalance;
            dto.ippCurrentBalance = null; 
            dto.baseRate = apiPlan.baseRate;
            dto.deferredInterest = apiPlan.deferredInterest;
            dto.accruedInterest = apiPlan.accruedInterest;
            dto.perDiem = apiPlan.perDiem;
            dto.aggregateDays = apiPlan.aggregateDays;
            dto.ippInterest = apiPlan.ippInterest;
            dto.closeFeeIndicator = apiPlan.closeFeeIndicator;
            dto.closeFeeIndicatorAmt = apiPlan.closeFeeIndicatorAmt;
            dto.closeFeeAmount = apiPlan.closeFeeAmount;
            dto.additionalAccruedInt = apiPlan.additionalAccruedInt;
            dto.totalPaymentAmount = apiPlan.totalPaymentAmount;
            dto.refNumber = apiPlan.refNumber;
            response.plans.add(dto);
        }
        
        return response;
    }
    
    // ==========================================
    // SAVE TO DATABASE METHOD
    // ==========================================
    /**
     * Lưu dữ liệu IPP từ API vào FEC_IPP__c (chỉ INSERT, không UPDATE)
     * Method này chỉ được gọi 1 lần duy nhất khi chưa có dữ liệu trong database
     * Gọi tất cả API đồng thời, merge dữ liệu, rồi insert 1 lần duy nhất
     * @param dtoPlans - List IPPPlanDTO từ GetCardPlanInfo API
     * @param secInfoResponse - Response từ GetCardSecInfo API (có thể null)
     * @param interestRateMap - Map PlanNumber -> InterestRate từ GetIPPDetails API
     * @param ippTermMap - Map PlanNumber -> IPPTerm từ GetIPPDetails API
     * @param accountNumber - Account Number
     * @param customerHistoryId - Customer History ID từ Case (ưu tiên dùng ID này)
     */
    private static void saveIPPToDatabase(List<IPPPlanDTO> dtoPlans, FEC_GetCardSecInfo.ResponseWrapper secInfoResponse, Map<String, Decimal> interestRateMap, Map<String, String> ippTermMap, String accountNumber, Id customerHistoryId) {
        // Ưu tiên dùng Customer History ID từ Case
        // Nếu không có, mới tìm từ Account Number
        if (customerHistoryId == null) {
            System.debug('Customer History ID từ Case là null, tìm từ Account Number...');
            List<FEC_Customer_History__c> histories = [
                SELECT Id FROM FEC_Customer_History__c 
                WHERE FEC_Account_Number__c = :accountNumber 
                LIMIT 1
            ];
            if (!histories.isEmpty()) {
                customerHistoryId = histories[0].Id;
                System.debug('Found Customer History ID từ Account Number: ' + customerHistoryId);
            }
        } else {
            System.debug('Sử dụng Customer History ID từ Case: ' + customerHistoryId);
        }
        
        if (customerHistoryId == null) {
            System.debug('Không tìm thấy Customer History với Account Number: ' + accountNumber);
            return;
        }
        
        // Tạo List từ GetCardSecInfo để match theo thứ tự (vì plan number có thể khác nhau giữa 2 API)
        List<FEC_GetCardSecInfo.IPP> secInfoList = new List<FEC_GetCardSecInfo.IPP>();
        if (secInfoResponse != null && secInfoResponse.CardSecInfo != null && secInfoResponse.CardSecInfo.IPPs != null) {
            System.debug('### GetCardSecInfo returned ' + secInfoResponse.CardSecInfo.IPPs.size() + ' IPP records');
            for (FEC_GetCardSecInfo.IPP secIPP : secInfoResponse.CardSecInfo.IPPs) {
                secInfoList.add(secIPP);
                System.debug('### GetCardSecInfo IPP: Plan=' + secIPP.IPPPlan + 
                            ', StartDate=' + secIPP.IPPStartDate + 
                            ', MatureDate=' + secIPP.IPPMatureDate + 
                            ', CurrentBalance=' + secIPP.IPPCurrentBalance + 
                            ', Term=' + secIPP.currentTerm);
            }
        } else {
            System.debug('### GetCardSecInfo returned null or empty IPPs list');
        }
        
        // Query records cũ để kiểm tra (chỉ INSERT nếu chưa có)
        List<FEC_IPP__c> existingRecords = [
            SELECT Id, FEC_IPP_Record_No__c, FEC_IPP_Plan__c, FEC_Customer_History__c
            FROM FEC_IPP__c 
            WHERE FEC_Customer_History__c = :customerHistoryId
        ];
        
        // Tạo Set để kiểm tra nhanh key (Record_No + Plan) đã tồn tại chưa
        Set<String> existingKeys = new Set<String>();
        for (FEC_IPP__c existing : existingRecords) {
            String key = (existing.FEC_IPP_Record_No__c != null ? existing.FEC_IPP_Record_No__c : '') + '_' + 
                        (existing.FEC_IPP_Plan__c != null ? existing.FEC_IPP_Plan__c : '');
            existingKeys.add(key);
        }
        
        System.debug('Found ' + existingRecords.size() + ' existing records in DB');
        
        List<FEC_IPP__c> recordsToInsert = new List<FEC_IPP__c>();
        
        // Match theo thứ tự: plan đầu tiên từ GetCardPlanInfo match với plan đầu tiên từ GetCardSecInfo
        Integer planIndex = 0;
        for (IPPPlanDTO dto : dtoPlans) {
            // Validate: Phải có Plan Number
            if (String.isBlank(dto.planNumber)) {
                System.debug('Skipping IPP với planNumber rỗng');
                continue;
            }
            
            // Tạo key để kiểm tra: Record_No + Plan
            String key = (dto.recordNumber != null ? dto.recordNumber : '') + '_' + 
                        (dto.planNumber != null ? dto.planNumber : '');
            
            // Nếu key đã tồn tại → bỏ qua (không insert, không update)
            if (existingKeys.contains(key)) {
                System.debug('### IPP record already exists: Rec=' + dto.recordNumber + ', Plan=' + dto.planNumber + ', skipping insert');
                continue;
            }
            
            // Chỉ INSERT record mới (key chưa tồn tại)
            FEC_IPP__c ipp = new FEC_IPP__c();
            ipp.FEC_Customer_History__c = customerHistoryId;
            
            // Mapping fields từ GetCardPlanInfo
            ipp.FEC_IPP_Plan__c = dto.planNumber;           // PlanNumber → IPP Plan
            ipp.FEC_IPP_Open_Date__c = FEC_CommonUltils.parseDate(dto.openDate); // PlanOpenDate → IPP Open Date
            ipp.FEC_IPP_Balance__c = dto.currentBalance;    // PlanCurrentBalance → IPP Balance
            
            // Merge dữ liệu từ GetCardSecInfo - Match theo thứ tự (index) vì plan number có thể khác nhau
            FEC_GetCardSecInfo.IPP secIPP = null;
            if (planIndex < secInfoList.size()) {
                secIPP = secInfoList[planIndex];
                System.debug('### Matching by index ' + planIndex + ': GetCardPlanInfo Plan=' + dto.planNumber + 
                            ' with GetCardSecInfo Plan=' + secIPP.IPPPlan + 
                            ', IPPStartDate=' + secIPP.IPPStartDate + 
                            ', IPPMatureDate=' + secIPP.IPPMatureDate + 
                            ', IPPCurrentBalance=' + secIPP.IPPCurrentBalance);
            }
            
            if (secIPP != null) {
                // CHỈ dùng IPPStartDate, IPPMatureDate, IPPCurrentBalance, Term từ GetCardSecInfo
                ipp.FEC_IPP_First_Due_Date__c = String.isNotBlank(secIPP.IPPStartDate) ? FEC_CommonUltils.parseDate(secIPP.IPPStartDate) : null;
                ipp.FEC_IPP_Mature_Date__c = String.isNotBlank(secIPP.IPPMatureDate) ? FEC_CommonUltils.parseDate(secIPP.IPPMatureDate) : null;
                ipp.FEC_IPP_Current_Balance__c = secIPP.IPPCurrentBalance != null ? secIPP.IPPCurrentBalance : null;
                ipp.FEC_IPP_Current_Term__c = secIPP.currentTerm != null ? secIPP.currentTerm : null;
                // IPP Record No lấy từ GetCardSecInfo (1-36, dựa trên thứ tự OPENING_BALANCE_1, _2, ..., _36)
                ipp.FEC_IPP_Record_No__c = secIPP.IPPRecordNo;
                
                System.debug('### Parsed dates for Plan ' + dto.planNumber + 
                            ', First_Due_Date=' + ipp.FEC_IPP_First_Due_Date__c + 
                            ', Mature_Date=' + ipp.FEC_IPP_Mature_Date__c + 
                            ', Current_Balance=' + ipp.FEC_IPP_Current_Balance__c + 
                            ', Current_Term=' + ipp.FEC_IPP_Current_Term__c +
                            ', Record_No=' + ipp.FEC_IPP_Record_No__c);
            } else {
                System.debug('### WARNING: No matching GetCardSecInfo at index ' + planIndex + 
                            ' for Plan ' + dto.planNumber + 
                            ' (GetCardSecInfo has ' + secInfoList.size() + ' records)' +
                            '. First Due Date will be NULL (NOT using BeginDate=' + dto.beginDate + ' from GetCardPlanInfo)');
                // KHÔNG dùng BeginDate từ GetCardPlanInfo - chỉ để null nếu không có GetCardSecInfo
                ipp.FEC_IPP_First_Due_Date__c = null;
                ipp.FEC_IPP_Mature_Date__c = null;
                ipp.FEC_IPP_Current_Balance__c = null;
                ipp.FEC_IPP_Current_Term__c = null;
                // Không có GetCardSecInfo → FEC_IPP_Record_No__c để null (không fallback)
                ipp.FEC_IPP_Record_No__c = null;
            }
            
            planIndex++; // Tăng index cho plan tiếp theo
            
            // Merge InterestRate và IPPTerm từ GetIPPDetails
            if (interestRateMap.containsKey(dto.planNumber)) {
                ipp.FEC_IPP_Interest_Rate__c = interestRateMap.get(dto.planNumber);
            } else if (dto.baseRate != null) {
                ipp.FEC_IPP_Interest_Rate__c = dto.baseRate;
            }
            
            // Merge IPPTerm từ GetIPPDetails
            // IPPTerm từ API có thể là "3 months" hoặc "3" → parse số
            if (ippTermMap.containsKey(dto.planNumber)) {
                String ippTermStr = ippTermMap.get(dto.planNumber);
                // ipp.FEC_IPP_Term__c = parseIPPTerm(ippTermStr);
                ipp.FEC_IPP_Term__c = Decimal.valueOf(ippTermStr);
                System.debug('### Parsed IPPTerm: ' + ippTermStr + ' → ' + ipp.FEC_IPP_Term__c);
            }
        }
    }

}
