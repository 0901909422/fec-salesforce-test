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
    
    // ==========================================
    // MAIN METHOD FOR LWC - Luồng mới giống FEC_CardInfoController
    // ==========================================
    /**
     * Tải thông tin IPP - Method chính
     * Luồng: Query database trước, chỉ call API nếu không có dữ liệu (và chỉ 1 lần duy nhất)
     * Sau khi có dữ liệu trong database, sẽ không gọi API nữa
     * @param caseId - ID của Case record
     * @return Danh sách IPP records
     */
    @AuraEnabled(cacheable=false)
    public static List<FEC_IPP__c> loadIPPInfo(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('CaseId is required');
        }

        /* ===== TẢI CASE ===== */
        Case c = [
            SELECT Id, FEC_Account_or_Contract__c, FEC_Account_Number__c,
                   FEC_Account_or_Contract__r.FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        Id customerHistoryId = c.FEC_Account_or_Contract__c;
        String accountNumber = getAccountNumber(c);

        /* =====================================================
         * BƯỚC 1: QUERY DATABASE TRƯỚC
         * ===================================================== */
        List<FEC_IPP__c> ippRecords = new List<FEC_IPP__c>();
        
        try {
            ippRecords = [
                SELECT 
                    Id,
                    FEC_IPP_Plan__c,
                    FEC_IPP_Record_No__c,
                    FEC_IPP_Open_Date__c,
                    FEC_IPP_First_Due_Date__c,
                    FEC_IPP_Mature_Date__c,
                    FEC_IPP_Balance__c,
                    FEC_IPP_Current_Balance__c,
                    FEC_IPP_Interest_Rate__c,
                    FEC_IPP_Term__c,
                    FEC_IPP_Insurance__c,
                    FEC_IPP_Current_Term__c,
                    // Sales Info fields for tooltip
                    FEC_Application_ID__c,
                    FEC_CC_Code__c,
                    FEC_CC_Name__c,
                    FEC_DSA_Code__c,
                    FEC_DSA_Name__c,
                    FEC_TSA_Code__c,
                    FEC_TSA_Name__c,
                    FEC_Origination_Channel__c,
                    FEC_Disbursement_Channel__c,
                    // IPP Schedule totals (rollup summary fields)
                    FEC_Total_IPP_Payment_Amount__c,
                    FEC_Total_IPP_Monthly_Principal__c,
                    FEC_Total_IPP_Monthly_Interest__c,
                    CreatedDate,
                    LastModifiedDate
                FROM FEC_IPP__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                ORDER BY FEC_IPP_Open_Date__c DESC
            ];
        } catch (Exception e) {
            System.debug('### Load IPP Records FAILED: ' + e.getMessage());
        }

        /* =====================================================
         * BƯỚC 2: KIỂM TRA XEM CÓ DỮ LIỆU KHÔNG
         * Nếu đã có dữ liệu trong database → return luôn (không gọi API)
         * ===================================================== */
        Boolean hasIPPData = ippRecords != null && ippRecords.size() > 0;

        // Nếu đã có dữ liệu → return luôn (không gọi API nữa)
        if (hasIPPData) {
            System.debug('### Found IPP data in database, returning without API call');
            return ippRecords;
        }

        /* =====================================================
         * BƯỚC 3: KHÔNG CÓ DỮ LIỆU → GỌI API (CHỈ 1 LẦN DUY NHẤT)
         * ===================================================== */
        System.debug('### No IPP data found in database, calling API...');

        if (String.isBlank(accountNumber)) {
            System.debug('### Account Number is blank, cannot call API');
            return ippRecords;
        }

        /* ===== Gọi tất cả API đồng thời để lấy đầy đủ dữ liệu ===== */
        try {
            // Gọi tất cả API cùng lúc
            IPPApiResponse planInfoResponse = callGetCardPlanInfoAPI(accountNumber, caseId);
            FEC_GetCardSecInfo.ResponseWrapper secInfoResponse = null;
            Map<String, Decimal> interestRateMap = new Map<String, Decimal>();
            Map<String, String> ippTermMap = new Map<String, String>();  // String để hỗ trợ format "3 months"
            
            try {
                secInfoResponse = FEC_GetCardSecInfo.getCardSecInfo(accountNumber);
            } catch (Exception e) {
                System.debug('### GetCardSecInfo API FAILED: ' + e.getMessage());
            }
            
            // Gọi GetIPPDetails cho từng plan (nếu có dữ liệu từ GetCardPlanInfo)
            if (planInfoResponse != null && planInfoResponse.responseCode == '1' && !planInfoResponse.plans.isEmpty()) {
                Date today = Date.today();
                String effectiveDate = today.year() + '-' + 
                                      String.valueOf(today.month()).leftPad(2, '0') + '-' + 
                                      String.valueOf(today.day()).leftPad(2, '0');
                String postingDate = effectiveDate;
                
                for (IPPPlanDTO plan : planInfoResponse.plans) {
                    if (String.isNotBlank(plan.planNumber)) {
                        try {
                            FEC_GetIPPDetailsCallout.IPPRequest request = new FEC_GetIPPDetailsCallout.IPPRequest();
                            request.accountNumber = accountNumber;
                            request.effectiveDate = effectiveDate;
                            request.amount = plan.currentBalance != null ? plan.currentBalance : 0;
                            request.postingDate = postingDate;
                            request.planNumber = plan.planNumber;
                            
                            FEC_GetIPPDetailsCallout.IPPDetailsResponse response = FEC_GetIPPDetailsCallout.getIPPDetails(request);
                            if (response != null) {
                                if (response.interestRate != null) {
                                    interestRateMap.put(plan.planNumber, response.interestRate);
                                }
                                if (String.isNotBlank(response.ippTerm)) {
                                    ippTermMap.put(plan.planNumber, response.ippTerm);
                                    System.debug('### IPPTerm from API for plan ' + plan.planNumber + ': ' + response.ippTerm);
                                }
                            }
                        } catch (Exception e) {
                            System.debug('### GetIPPDetails API FAILED for plan ' + plan.planNumber + ': ' + e.getMessage());
                        }
                    }
                }
            }
            
            // Lưu vào database với đầy đủ dữ liệu từ tất cả API
            if (planInfoResponse != null && planInfoResponse.responseCode == '1' && !planInfoResponse.plans.isEmpty()) {
                saveIPPToDatabase(planInfoResponse.plans, secInfoResponse, interestRateMap, ippTermMap, accountNumber, customerHistoryId);
            }
        } catch (Exception e) {
            System.debug('### API calls FAILED: ' + e.getMessage());
        }

        /* =====================================================
         * QUERY LẠI DATABASE SAU KHI INSERT
         * ===================================================== */
        try {
            ippRecords = [
                SELECT 
                    Id,
                    FEC_IPP_Plan__c,
                    FEC_IPP_Record_No__c,
                    FEC_IPP_Open_Date__c,
                    FEC_IPP_First_Due_Date__c,
                    FEC_IPP_Mature_Date__c,
                    FEC_IPP_Balance__c,
                    FEC_IPP_Current_Balance__c,
                    FEC_IPP_Interest_Rate__c,
                    FEC_IPP_Term__c,
                    FEC_IPP_Insurance__c,
                    FEC_IPP_Current_Term__c,
                    // Sales Info fields for tooltip
                    FEC_Application_ID__c,
                    FEC_CC_Code__c,
                    FEC_CC_Name__c,
                    FEC_DSA_Code__c,
                    FEC_DSA_Name__c,
                    FEC_TSA_Code__c,
                    FEC_TSA_Name__c,
                    FEC_Origination_Channel__c,
                    FEC_Disbursement_Channel__c,
                    // IPP Schedule totals (rollup summary fields)
                    FEC_Total_IPP_Payment_Amount__c,
                    FEC_Total_IPP_Monthly_Principal__c,
                    FEC_Total_IPP_Monthly_Interest__c,
                    CreatedDate,
                    LastModifiedDate
                FROM FEC_IPP__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                ORDER BY FEC_IPP_Open_Date__c DESC
            ];
            
            /* =====================================================
             * BƯỚC 4: GỌI SALES INFO API CHO CÁC IPP MỚI TẠO
             * ===================================================== */
            if (!ippRecords.isEmpty()) {
                Set<Id> newIPPIds = new Set<Id>();
                for (FEC_IPP__c ipp : ippRecords) {
                    newIPPIds.add(ipp.Id);
                }
                
                System.debug('### Calling Sales Info API async for ' + newIPPIds.size() + ' new IPP records');
                
                // Gọi async để fetch Sales Info (không block main thread)
                FEC_SalesInfoController.fetchSalesInfoAsync(newIPPIds);
            }
            
        } catch (Exception e) {
            System.debug('### Reload IPP Records FAILED: ' + e.getMessage());
        }

        return ippRecords;
    }

    /**
     * Lấy Account Number từ Case
     * Ưu tiên: FEC_Customer_History__c.FEC_Account_Number__c (qua lookup)
     * Fallback: Case.FEC_Account_Number__c (trực tiếp trên Case)
     * @param c - Case record
     * @return Account Number hoặc null nếu không tìm thấy
     */
    private static String getAccountNumber(Case c) {
        if (c.FEC_Account_or_Contract__c != null) {
            FEC_Customer_History__c h = [
                SELECT FEC_Account_Number__c
                FROM FEC_Customer_History__c
                WHERE Id = :c.FEC_Account_or_Contract__c
                LIMIT 1
            ];
            if (String.isNotBlank(h.FEC_Account_Number__c)) {
                return h.FEC_Account_Number__c;
            }
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
                            ', Term=' + secIPP.Term);
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
                ipp.FEC_IPP_Current_Term__c = secIPP.Term != null ? secIPP.Term : null;
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
                ipp.FEC_IPP_Term__c = parseIPPTerm(ippTermStr);
                System.debug('### Parsed IPPTerm: ' + ippTermStr + ' → ' + ipp.FEC_IPP_Term__c);
            }

            recordsToInsert.add(ipp);
            System.debug('Creating new IPP record: Rec=' + dto.recordNumber + ', Plan=' + dto.planNumber);
        }
        
        System.debug('Total records to insert: ' + recordsToInsert.size());
        
        if (!recordsToInsert.isEmpty()) {
            try {
                insert recordsToInsert;
                System.debug('Đã insert thành công ' + recordsToInsert.size() + ' IPP records vào DB với đầy đủ dữ liệu từ tất cả API.');
            } catch (Exception e) {
                System.debug('Lỗi khi lưu DB: ' + e.getMessage());
                throw new AuraHandledException('Lỗi lưu dữ liệu: ' + e.getMessage());
            }
        } else {
            System.debug('Không có records mới để insert!');
        }
    }
    /**
     * Parse IPP Term string sang Decimal
     * Hỗ trợ các format: "3 months", "3", "12 months", etc.
     * @param ippTermStr - IPP Term string từ API
     * @return Decimal giá trị số (ví dụ: 3, 12)
     */
    private static Decimal parseIPPTerm(String ippTermStr) {
        if (String.isBlank(ippTermStr)) return null;
        
        try {
            // Thử parse trực tiếp nếu là số thuần túy
            return Decimal.valueOf(ippTermStr.trim());
        } catch (Exception e) {
            // Nếu không phải số thuần túy, extract số từ string
            // Ví dụ: "3 months" → 3
            String numbersOnly = ippTermStr.replaceAll('[^0-9.]', '');
            if (String.isNotBlank(numbersOnly)) {
                try {
                    return Decimal.valueOf(numbersOnly);
                } catch (Exception e2) {
                    System.debug('### Error parsing IPPTerm: ' + ippTermStr + ' - ' + e2.getMessage());
                    return null;
                }
            }
            return null;
        }
    }

    // ==========================================
    // EXISTING METHODS
    // ==========================================
    
    /**
     * Lấy danh sách IPP records liên quan đến Case
     * Method này wrapper của loadIPPInfo() để backward compatibility
     * @param caseId - ID của Case record
     * @return Danh sách IPP records
     */
    @AuraEnabled(cacheable=false)
    public static List<FEC_IPP__c> getIPPRecords(String caseId) {
        // Sử dụng loadIPPInfo() - method này tự động query database và gọi API nếu cần
        return loadIPPInfo(caseId);
    }
    
    /**
     * Lấy thông tin tooltip cho IPP Plan (Sales Info + IPP Schedule Totals)
     * @param ippRecordId - ID của IPP record
     * @return Map chứa Sales Info và IPP Schedule Totals
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getIPPTooltipData(String ippRecordId) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            // Query IPP record với Sales Info fields
            FEC_IPP__c ipp = [
                SELECT Id, FEC_IPP_Plan__c,
                       FEC_Application_ID__c,
                       FEC_CC_Code__c, FEC_CC_Name__c,
                       FEC_DSA_Code__c, FEC_DSA_Name__c,
                       FEC_TSA_Code__c, FEC_TSA_Name__c,
                       FEC_Origination_Channel__c,
                       FEC_Disbursement_Channel__c
                FROM FEC_IPP__c
                WHERE Id = :ippRecordId
                LIMIT 1
            ];
            
            // Sales Info
            Map<String, String> salesInfo = new Map<String, String>();
            salesInfo.put('applicationId', ipp.FEC_Application_ID__c);
            salesInfo.put('ccCode', ipp.FEC_CC_Code__c);
            salesInfo.put('ccName', ipp.FEC_CC_Name__c);
            salesInfo.put('dsaCode', ipp.FEC_DSA_Code__c);
            salesInfo.put('dsaName', ipp.FEC_DSA_Name__c);
            salesInfo.put('tsaCode', ipp.FEC_TSA_Code__c);
            salesInfo.put('tsaName', ipp.FEC_TSA_Name__c);
            salesInfo.put('originationChannel', ipp.FEC_Origination_Channel__c);
            salesInfo.put('disbursementChannel', ipp.FEC_Disbursement_Channel__c);
            result.put('salesInfo', salesInfo);
            
            // IPP Schedule Totals - Query từ FEC_IPP_Schedule__c
            List<FEC_IPP_Schedule__c> schedules = [
                SELECT FEC_IPP_Payment_Amount__c,
                       FEC_IPP_Monthly_Principal__c,
                       FEC_IPP_Monthly_Interest__c
                FROM FEC_IPP_Schedule__c
                WHERE FEC_IPP__c = :ippRecordId
            ];
            
            Decimal totalPaymentAmount = 0;
            Decimal totalMonthlyPrincipal = 0;
            Decimal totalMonthlyInterest = 0;
            
            for (FEC_IPP_Schedule__c schedule : schedules) {
                totalPaymentAmount += (schedule.FEC_IPP_Payment_Amount__c != null ? schedule.FEC_IPP_Payment_Amount__c : 0);
                totalMonthlyPrincipal += (schedule.FEC_IPP_Monthly_Principal__c != null ? schedule.FEC_IPP_Monthly_Principal__c : 0);
                totalMonthlyInterest += (schedule.FEC_IPP_Monthly_Interest__c != null ? schedule.FEC_IPP_Monthly_Interest__c : 0);
            }
            
            Map<String, Decimal> scheduleTotals = new Map<String, Decimal>();
            scheduleTotals.put('totalPaymentAmount', totalPaymentAmount);
            scheduleTotals.put('totalMonthlyPrincipal', totalMonthlyPrincipal);
            scheduleTotals.put('totalMonthlyInterest', totalMonthlyInterest);
            result.put('scheduleTotals', scheduleTotals);
            
            return result;
        } catch (Exception e) {
            System.debug('Error getting IPP tooltip data: ' + e.getMessage());
            return result;
        }
    }
    
    /**
     * Lấy tổng IPP Balance và IPP Current Balance từ Customer History (Rollup Summary fields)
     * @param caseId - ID của Case record
     * @return Map chứa totalIPPBalance và totalIPPCurrentBalance
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getIPPTotals(String caseId) {
        try {
            Case caseRecord = [
                SELECT 
                    FEC_Account_or_Contract__r.FEC_Total_IPP_Balance__c,
                    FEC_Account_or_Contract__r.FEC_Total_IPP_Current_Balance__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            
            Map<String, Decimal> totals = new Map<String, Decimal>();
            totals.put('totalIPPBalance', caseRecord.FEC_Account_or_Contract__r.FEC_Total_IPP_Balance__c != null ? 
                       caseRecord.FEC_Account_or_Contract__r.FEC_Total_IPP_Balance__c : 0);
            totals.put('totalIPPCurrentBalance', caseRecord.FEC_Account_or_Contract__r.FEC_Total_IPP_Current_Balance__c != null ? 
                       caseRecord.FEC_Account_or_Contract__r.FEC_Total_IPP_Current_Balance__c : 0);
            
            return totals;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching IPP totals: ' + e.getMessage());
        }
    }

}