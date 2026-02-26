public with sharing class FEC_CardPaymentController {
    
    /* =====================================================
     * DTO
     * ===================================================== */
    public class CardPaymentTotalsDTO {
        @AuraEnabled public Map<String, String> helpTexts;
        @AuraEnabled public Decimal fullPaymentAmount;
        @AuraEnabled public Decimal loanBalance;
        @AuraEnabled public Decimal fullPaymentWithoutIPP;
        @AuraEnabled public Decimal fullIPPPaymentAmount;
    }
    
    /**
     * Tải thông tin Card Payment - Method chính
     * Luồng: Query database trước, chỉ call API nếu không có dữ liệu (và chỉ 1 lần duy nhất)
     * Sau khi có dữ liệu trong database, sẽ không gọi API nữa
     * @param caseId - ID của Case record
     * @return Danh sách Card Payment records
     */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> loadCardPaymentInfo(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
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
        List<Map<String, Object>> records = new List<Map<String, Object>>();
        
        try {
            List<FEC_Card_Payment__c> payments = [
                SELECT 
                    Id,
                    Name,
                    FEC_Rec__c,
                    FEC_Plan__c,
                    FEC_REF_Number__c,
                    FEC_Current_Balance__c,
                    FEC_Open_Date__c,
                    FEC_Base_Rate__c,
                    FEC_Begin_Date__c,
                    FEC_Accrued_Interest__c,
                    FEC_Per_Diem__c,
                    FEC_Deferred_Interest__c,
                    FEC_IPP_Interest__c,
                    FEC_IPP_Accrued_Interest__c,
                    FEC_Close_Fee__c,
                    FEC_Close_Fee_Amount__c,
                    FEC_Plan_Payment_Amount__c
                FROM FEC_Card_Payment__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                ORDER BY FEC_Open_Date__c DESC NULLS LAST
            ];
            
            // Convert to Map list for LWC
            for (FEC_Card_Payment__c p : payments) {
                Map<String, Object> record = new Map<String, Object>();
                record.put('FEC_Rec__c', p.FEC_Rec__c);
                record.put('FEC_REF_Number__c', p.FEC_REF_Number__c);
                record.put('FEC_Current_Balance__c', p.FEC_Current_Balance__c);
                record.put('FEC_Open_Date__c', p.FEC_Open_Date__c);
                record.put('FEC_Plan__c', p.FEC_Plan__c);
                record.put('FEC_Base_Rate__c', p.FEC_Base_Rate__c);
                record.put('FEC_Begin_Date__c', p.FEC_Begin_Date__c);
                record.put('FEC_Accrued_Interest__c', p.FEC_Accrued_Interest__c);
                record.put('FEC_Per_Diem__c', p.FEC_Per_Diem__c);
                record.put('FEC_Deferred_Interest__c', p.FEC_Deferred_Interest__c);
                record.put('FEC_IPP_Interest__c', p.FEC_IPP_Interest__c);
                record.put('FEC_IPP_Accrued_Interest__c', p.FEC_IPP_Accrued_Interest__c);
                record.put('FEC_Close_Fee__c', p.FEC_Close_Fee__c);
                record.put('FEC_Close_Fee_Amount__c', p.FEC_Close_Fee_Amount__c);
                record.put('FEC_Plan_Payment_Amount__c', p.FEC_Plan_Payment_Amount__c);
                records.add(record);
            }
        } catch (Exception e) {
            // Ignore query exception
        }

        /* =====================================================
         * BƯỚC 2: KIỂM TRA XEM CÓ DỮ LIỆU KHÔNG
         * Nếu đã có dữ liệu trong database → return luôn (không gọi API)
         * ===================================================== */
        Boolean hasCardPaymentData = records != null && records.size() > 0;

        // Nếu đã có dữ liệu → return luôn (không gọi API nữa)
        if (hasCardPaymentData) {
            return records;
        }

        /* =====================================================
         * BƯỚC 3: KHÔNG CÓ DỮ LIỆU → GỌI API (CHỈ 1 LẦN DUY NHẤT)
         * ===================================================== */
        if (String.isBlank(accountNumber)) {
            return records;
        }

        /* ===== Gọi API GetCardPlanInfo ===== */
        try {
            FEC_GetCardPlanInfo.CardPlanResult apiResult = FEC_GetCardPlanInfo.getCardPlanInfo(accountNumber);
            if (apiResult != null && apiResult.responseCode == '1' && !apiResult.plans.isEmpty()) {
                saveCardPlanToDatabase(apiResult.plans, accountNumber, customerHistoryId);
            }
        } catch (Exception e) {
            System.debug('### GetCardPlanInfo API FAILED: ' + e.getMessage());
        }

        /* =====================================================
         * BƯỚC 4: QUERY LẠI DATABASE SAU KHI CALL API
         * ===================================================== */
        try {
            List<FEC_Card_Payment__c> payments = [
                SELECT 
                    Id,
                    Name,
                    FEC_Rec__c,
                    FEC_Plan__c,
                    FEC_REF_Number__c,
                    FEC_Current_Balance__c,
                    FEC_Open_Date__c,
                    FEC_Base_Rate__c,
                    FEC_Begin_Date__c,
                    FEC_Accrued_Interest__c,
                    FEC_Per_Diem__c,
                    FEC_Deferred_Interest__c,
                    FEC_IPP_Interest__c,
                    FEC_IPP_Accrued_Interest__c,
                    FEC_Close_Fee__c,
                    FEC_Close_Fee_Amount__c,
                    FEC_Plan_Payment_Amount__c
                FROM FEC_Card_Payment__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                ORDER BY FEC_Open_Date__c DESC NULLS LAST
            ];
            
            // Convert to Map list for LWC
            records = new List<Map<String, Object>>();
            for (FEC_Card_Payment__c p : payments) {
                Map<String, Object> record = new Map<String, Object>();
                record.put('FEC_Rec__c', p.FEC_Rec__c);
                record.put('FEC_REF_Number__c', p.FEC_REF_Number__c);
                record.put('FEC_Current_Balance__c', p.FEC_Current_Balance__c);
                record.put('FEC_Open_Date__c', p.FEC_Open_Date__c);
                record.put('FEC_Plan__c', p.FEC_Plan__c);
                record.put('FEC_Base_Rate__c', p.FEC_Base_Rate__c);
                record.put('FEC_Begin_Date__c', p.FEC_Begin_Date__c);
                record.put('FEC_Accrued_Interest__c', p.FEC_Accrued_Interest__c);
                record.put('FEC_Per_Diem__c', p.FEC_Per_Diem__c);
                record.put('FEC_Deferred_Interest__c', p.FEC_Deferred_Interest__c);
                record.put('FEC_IPP_Interest__c', p.FEC_IPP_Interest__c);
                record.put('FEC_IPP_Accrued_Interest__c', p.FEC_IPP_Accrued_Interest__c);
                record.put('FEC_Close_Fee__c', p.FEC_Close_Fee__c);
                record.put('FEC_Close_Fee_Amount__c', p.FEC_Close_Fee_Amount__c);
                record.put('FEC_Plan_Payment_Amount__c', p.FEC_Plan_Payment_Amount__c);
                records.add(record);
            }
        } catch (Exception e) {
            // Ignore query exception
        }

        return records;
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
     * Get Card Payment records related to a Case
     * Method này wrapper của loadCardPaymentInfo() để backward compatibility
     * @param caseId - The Case record ID
     * @return List of Card Payment data as generic objects
     */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getCardPaymentRecords(String caseId) {
        // Sử dụng loadCardPaymentInfo() - method này tự động query database và gọi API nếu cần
        return loadCardPaymentInfo(caseId);
    }
    
    /**
     * Tải Card Payment Totals - Method chính
     * Luồng: Query database trước, chỉ call API nếu không có dữ liệu (và chỉ 1 lần duy nhất)
     * Sau khi có dữ liệu trong database, sẽ không gọi API nữa
     * @param caseId - ID của Case record
     * @return CardPaymentTotalsDTO chứa payment totals và help texts
     */
    @AuraEnabled(cacheable=false)
    public static CardPaymentTotalsDTO loadCardPaymentTotals(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
        }

        CardPaymentTotalsDTO dto = new CardPaymentTotalsDTO();
        dto.fullPaymentAmount = 0;
        dto.loanBalance = 0;
        dto.fullPaymentWithoutIPP = 0;
        dto.fullIPPPaymentAmount = 0;

        dto.helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Card_Payment__c.SObjectType);

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

        if (customerHistoryId == null) {
            return dto;
        }

        /* =====================================================
         * BƯỚC 1: QUERY DATABASE TRƯỚC
         * ===================================================== */
        try {
            // Query từ FEC_Card_Payment__c để lấy totals
            List<FEC_Card_Payment__c> cardPayments = [
                SELECT FEC_Full_Payment_Amount__c, FEC_Loan_Balance__c, FEC_Full_Payment_Without_IPP__c, FEC_Full_IPP_Payment_Amount__c
                FROM FEC_Card_Payment__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                  AND (FEC_Full_Payment_Amount__c != null OR FEC_Loan_Balance__c != null OR FEC_Full_Payment_Without_IPP__c != null OR FEC_Full_IPP_Payment_Amount__c != null)
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];

            if (!cardPayments.isEmpty()) {
                // Có dữ liệu → return luôn (không gọi API)
                FEC_Card_Payment__c payment = cardPayments[0];
                dto.fullPaymentAmount = payment.FEC_Full_Payment_Amount__c != null ? payment.FEC_Full_Payment_Amount__c : 0;
                dto.loanBalance = payment.FEC_Loan_Balance__c != null ? payment.FEC_Loan_Balance__c : 0;
                dto.fullPaymentWithoutIPP = payment.FEC_Full_Payment_Without_IPP__c != null ? payment.FEC_Full_Payment_Without_IPP__c : 0;
                dto.fullIPPPaymentAmount = payment.FEC_Full_IPP_Payment_Amount__c != null ? payment.FEC_Full_IPP_Payment_Amount__c : 0;
                return dto;
            }
        } catch (Exception e) {
            // Ignore query exception
        }

        /* =====================================================
         * BƯỚC 2: KHÔNG CÓ DỮ LIỆU → GỌI API (CHỈ 1 LẦN DUY NHẤT)
         * Lưu ý: Tất cả các API chỉ được gọi 1 lần duy nhất ở đây
         * ===================================================== */
        if (String.isBlank(accountNumber)) {
            return dto;
        }

        Decimal fullPaymentAmount = 0;
        Decimal loanBalance = 0;
        Decimal fullPaymentWithoutIPP = 0;

        /* ===== 1. Gọi API GetCardPaymentInfo để lấy Full Payment Amount ===== */
        try {
            FEC_GetCardPaymentInfo.CardPaymentResult paymentResult = 
                FEC_GetCardPaymentInfo.getCardPaymentInfo(accountNumber, Date.today());
            
            if (paymentResult != null && paymentResult.fullPaymentAmount != null) {
                fullPaymentAmount = paymentResult.fullPaymentAmount;
            }
        } catch (Exception e) {
            System.debug('GetCardPaymentInfo API error: ' + e.getMessage());
        }

        /* ===== 2. Gọi API GetCardBasicInfo để lấy Loan Balance ===== */
        try {
            String transId = UUID.randomUUID().toString();
            String requestorId = FEC_ConstantCommon.REQUESTOR_CRM;
            String dateTimeStr = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
            
            FEC_GetCardBasicInfo.ResponseWrapper basicInfoResult = 
                FEC_GetCardBasicInfo.callGetCardBasicInfo(transId, requestorId, dateTimeStr, accountNumber);
            
            if (basicInfoResult != null && 
                basicInfoResult.CardBasicInfo != null && 
                basicInfoResult.CardBasicInfo.MainCard != null &&
                basicInfoResult.CardBasicInfo.MainCard.LoanBalance != null) {
                loanBalance = basicInfoResult.CardBasicInfo.MainCard.LoanBalance;
            }
        } catch (Exception e) {
            System.debug('GetCardBasicInfo API error: ' + e.getMessage());
        }

        /* ===== 3. Tính Full Payment Without IPP từ 3 API ===== */
        try {
            // 3.1. Gọi API M_CMS_EMEA_ACCOUNT_INQ để lấy OnlineTotalBalance
            Decimal onlineTotalBalance = 0;
            try {
                FEC_EmeaAccountInqService.EmeaInput emeaInput = new FEC_EmeaAccountInqService.EmeaInput();
                emeaInput.context = 'ACCOUNT';
                emeaInput.name = 'ACCOUNT_INQ';
                emeaInput.org = 'FEC';
                emeaInput.account = accountNumber;
                
                FEC_EmeaAccountInqService.EmeaResult emeaResult = 
                    FEC_EmeaAccountInqService.callAccountInquiry(emeaInput);
                
                if (emeaResult != null && emeaResult.responseCode == '1') {
                    // OnlineTotalBalance = CURR_BAL + AMT_MEMO_DB - AMT_MEMO_CR
                    Decimal currBal = emeaResult.currBal != null ? emeaResult.currBal : 0;
                    Decimal amtMemoDb = emeaResult.amtMemoDb != null ? emeaResult.amtMemoDb : 0;
                    Decimal amtMemoCr = emeaResult.amtMemoCr != null ? emeaResult.amtMemoCr : 0;
                    onlineTotalBalance = currBal + amtMemoDb - amtMemoCr;
                }
            } catch (Exception e) {
                System.debug('M_CMS_EMEA_ACCOUNT_INQ API error: ' + e.getMessage());
            }

            // 3.2. Gọi API GetCardPlanInfo để lấy TotalDeferredInterestPlan, TotalAccuredInterestPlan, TotalPerDiemPlan
            Decimal totalDeferredInterestPlan = 0;
            Decimal totalAccuredInterestPlan = 0;
            Decimal totalPerDiemPlan = 0;
            
            try {
                FEC_GetCardPlanInfo.CardPlanResult planResult = 
                    FEC_GetCardPlanInfo.getCardPlanInfo(accountNumber);
                
                if (planResult != null && planResult.responseCode == '1' && planResult.plans != null) {
                    for (FEC_GetCardPlanInfo.CardPlan plan : planResult.plans) {
                        // Chỉ lấy khi PlanNumber không bắt đầu bằng '9'
                        if (String.isNotBlank(plan.planNumber) && !plan.planNumber.startsWith('9')) {
                            // TotalDeferredInterestPlan = Sum(DeferredInterest)
                            if (plan.deferredInterest != null) {
                                totalDeferredInterestPlan += plan.deferredInterest;
                            }
                            
                            // TotalAccuredInterestPlan = Sum(AccruedInterest/100)
                            if (plan.accruedInterest != null) {
                                totalAccuredInterestPlan += plan.accruedInterest / 100;
                            }
                            
                            // TotalPerDiemPlan = Sum(PerDiem/100)
                            if (plan.perDiem != null) {
                                totalPerDiemPlan += plan.perDiem / 100;
                            }
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('GetCardPlanInfo API error: ' + e.getMessage());
            }

            // 3.3. Tính Full Payment Without IPP
            // = OnlineTotalBalance + TotalDeferredInterestPlan + TotalAccuredInterestPlan + TotalPerDiemPlan - LoanBalance
            fullPaymentWithoutIPP = onlineTotalBalance + totalDeferredInterestPlan + totalAccuredInterestPlan + totalPerDiemPlan - loanBalance;
        } catch (Exception e) {
            System.debug('Calculate Full Payment Without IPP error: ' + e.getMessage());
        }

        /* ===== 4. Tính Full IPP Payment Amount ===== */
        Decimal fullIPPPaymentAmount = 0;
        if (fullPaymentAmount != 0 && fullPaymentWithoutIPP != 0) {
            // Full IPP Payment Amount = Full Payment Amount - Full Payment Without IPP
            fullIPPPaymentAmount = fullPaymentAmount - fullPaymentWithoutIPP;
        }

        /* =====================================================
         * BƯỚC 3: LƯU DỮ LIỆU VÀO DATABASE (CHỈ 1 LẦN DUY NHẤT)
         * Lưu ý: Method này chỉ được gọi 1 lần sau khi gọi API
         * ===================================================== */
        if (fullPaymentAmount != 0 || loanBalance != 0 || fullPaymentWithoutIPP != 0 || fullIPPPaymentAmount != 0) {
            saveCardPaymentTotalsToDatabase(customerHistoryId, fullPaymentAmount, loanBalance, fullPaymentWithoutIPP, fullIPPPaymentAmount);
        }

        /* =====================================================
         * BƯỚC 4: QUERY LẠI DATABASE SAU KHI LƯU (KHÔNG GỌI API NỮA)
         * Lưu ý: Chỉ query lại database, KHÔNG gọi API thêm lần nào nữa
         * Nếu không có dữ liệu trong database (do lưu thất bại) → trả về lỗi
         * ===================================================== */
        try {
            List<FEC_Card_Payment__c> cardPayments = [
                SELECT FEC_Full_Payment_Amount__c, FEC_Loan_Balance__c, FEC_Full_Payment_Without_IPP__c, FEC_Full_IPP_Payment_Amount__c
                FROM FEC_Card_Payment__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                  AND (FEC_Full_Payment_Amount__c != null OR FEC_Loan_Balance__c != null OR FEC_Full_Payment_Without_IPP__c != null OR FEC_Full_IPP_Payment_Amount__c != null)
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];

            if (!cardPayments.isEmpty()) {
                FEC_Card_Payment__c payment = cardPayments[0];
                dto.fullPaymentAmount = payment.FEC_Full_Payment_Amount__c != null ? payment.FEC_Full_Payment_Amount__c : 0;
                dto.loanBalance = payment.FEC_Loan_Balance__c != null ? payment.FEC_Loan_Balance__c : 0;
                dto.fullPaymentWithoutIPP = payment.FEC_Full_Payment_Without_IPP__c != null ? payment.FEC_Full_Payment_Without_IPP__c : 0;
                dto.fullIPPPaymentAmount = payment.FEC_Full_IPP_Payment_Amount__c != null ? payment.FEC_Full_IPP_Payment_Amount__c : 0;
            } else {
                // Nếu không có trong database (do lưu thất bại) → trả về lỗi
                throw new AuraHandledException(System.Label.FEC_MSG_Error_API_Label);
            }
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_MSG_Error_API_Label);
        }

        return dto;
    }

    /**
     * Get Card Payment totals
     * Method này wrapper của loadCardPaymentTotals() để backward compatibility
     * @param caseId - The Case record ID
     * @return CardPaymentTotalsDTO containing payment totals and help texts
     */
    @AuraEnabled(cacheable=false)
    public static CardPaymentTotalsDTO getCardPaymentTotals(String caseId) {
        // Sử dụng loadCardPaymentTotals() - method này tự động query database và gọi API nếu cần
        return loadCardPaymentTotals(caseId);
    }

    /**
     * Lưu Card Payment Totals vào database (chỉ UPDATE khi field là null, không update nếu đã có dữ liệu)
     * Method này chỉ được gọi 1 lần duy nhất khi chưa có dữ liệu trong database
     * @param customerHistoryId - Customer History ID
     * @param fullPaymentAmount - Full Payment Amount từ API
     * @param loanBalance - Loan Balance từ API
     * @param fullPaymentWithoutIPP - Full Payment Without IPP từ tính toán
     * @param fullIPPPaymentAmount - Full IPP Payment Amount từ tính toán (Full Payment Amount - Full Payment Without IPP)
     */
    private static void saveCardPaymentTotalsToDatabase(Id customerHistoryId, Decimal fullPaymentAmount, Decimal loanBalance, Decimal fullPaymentWithoutIPP, Decimal fullIPPPaymentAmount) {
        if (customerHistoryId == null) {
            return;
        }

        try {
            // Tìm record đầu tiên trong FEC_Card_Payment__c để lưu totals
            // Nếu không có record nào, sẽ tạo record mới
            List<FEC_Card_Payment__c> existingPayments = [
                SELECT Id, FEC_Full_Payment_Amount__c, FEC_Loan_Balance__c, FEC_Full_Payment_Without_IPP__c, FEC_Full_IPP_Payment_Amount__c
                FROM FEC_Card_Payment__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];

            FEC_Card_Payment__c paymentToUpdate;

            if (!existingPayments.isEmpty()) {
                // Có record → sử dụng record đầu tiên
                paymentToUpdate = existingPayments[0];
                
                // Kiểm tra xem đã có dữ liệu chưa (nếu có → không update)
                if (paymentToUpdate.FEC_Full_Payment_Amount__c != null || paymentToUpdate.FEC_Loan_Balance__c != null || paymentToUpdate.FEC_Full_Payment_Without_IPP__c != null || paymentToUpdate.FEC_Full_IPP_Payment_Amount__c != null) {
                    return;
                }
            } else {
                // Không có record → tạo record mới
                paymentToUpdate = new FEC_Card_Payment__c();
                paymentToUpdate.FEC_Customer_History__c = customerHistoryId;
            }

            // Chỉ update nếu field hiện tại là null (chưa có dữ liệu)
            Boolean needsUpdate = false;

            if (paymentToUpdate.FEC_Full_Payment_Amount__c == null && fullPaymentAmount != 0) {
                paymentToUpdate.FEC_Full_Payment_Amount__c = fullPaymentAmount;
                needsUpdate = true;
            }

            if (paymentToUpdate.FEC_Loan_Balance__c == null && loanBalance != 0) {
                paymentToUpdate.FEC_Loan_Balance__c = loanBalance;
                needsUpdate = true;
            }

            if (paymentToUpdate.FEC_Full_Payment_Without_IPP__c == null && fullPaymentWithoutIPP != 0) {
                paymentToUpdate.FEC_Full_Payment_Without_IPP__c = fullPaymentWithoutIPP;
                needsUpdate = true;
            }

            if (paymentToUpdate.FEC_Full_IPP_Payment_Amount__c == null && fullIPPPaymentAmount != 0) {
                paymentToUpdate.FEC_Full_IPP_Payment_Amount__c = fullIPPPaymentAmount;
                needsUpdate = true;
            }

            if (needsUpdate) {
                if (paymentToUpdate.Id != null) {
                    update paymentToUpdate;
                } else {
                    insert paymentToUpdate;
                }
            }
        } catch (Exception e) {
            System.debug('Save Card Payment Totals error: ' + e.getMessage());
            // Không throw exception để không làm gián đoạn flow chính
        }
    }
    
    /**
     * Lưu dữ liệu Card Plan từ API vào FEC_Card_Payment__c (chỉ INSERT, không UPDATE)
     * Method này chỉ được gọi 1 lần duy nhất khi chưa có dữ liệu trong database
     * @param planList - Danh sách CardPlan từ API
     * @param accountNumber - Account Number
     * @param customerHistoryId - Customer History ID từ Case (ưu tiên dùng ID này)
     */
    private static void saveCardPlanToDatabase(List<FEC_GetCardPlanInfo.CardPlan> planList, String accountNumber, Id customerHistoryId) {
        // Ưu tiên dùng Customer History ID từ Case
        // Nếu không có, mới tìm từ Account Number
        if (customerHistoryId == null) {
            List<FEC_Customer_History__c> histories = [
                SELECT Id FROM FEC_Customer_History__c 
                WHERE FEC_Account_Number__c = :accountNumber 
                LIMIT 1
            ];
            if (!histories.isEmpty()) {
                customerHistoryId = histories[0].Id;
            }
        }
        
        if (customerHistoryId == null) {
            return;
        }
        
        // Query records cũ để kiểm tra (chỉ INSERT nếu chưa có)
        List<FEC_Card_Payment__c> existingRecords = [
            SELECT Id, FEC_Rec__c, FEC_Plan__c, FEC_Customer_History__c
            FROM FEC_Card_Payment__c 
            WHERE FEC_Customer_History__c = :customerHistoryId
        ];
        
        // Tạo Set để kiểm tra nhanh key (Rec__c + Plan__c) đã tồn tại chưa
        Set<String> existingKeys = new Set<String>();
        for (FEC_Card_Payment__c existing : existingRecords) {
            String key = (existing.FEC_Rec__c != null ? existing.FEC_Rec__c : '') + '_' + 
                        (existing.FEC_Plan__c != null ? existing.FEC_Plan__c : '');
            existingKeys.add(key);
        }
        
        List<FEC_Card_Payment__c> recordsToInsert = new List<FEC_Card_Payment__c>();

        for (FEC_GetCardPlanInfo.CardPlan p : planList) {
            // Tạo key để kiểm tra: Rec__c + Plan__c
            String key = (p.recordNumber != null ? p.recordNumber : '') + '_' + 
                        (p.planNumber != null ? p.planNumber : '');
            
            // Nếu key đã tồn tại → bỏ qua (không insert, không update)
            if (existingKeys.contains(key)) {
                continue;
            }
            
            // Chỉ INSERT record mới (key chưa tồn tại)
            FEC_Card_Payment__c record = new FEC_Card_Payment__c();
            record.FEC_Customer_History__c = customerHistoryId;
            
            // --- MAP FIELDS THEO YÊU CẦU ---
            record.FEC_Rec__c = p.recordNumber;                   // RecordNumber
            record.FEC_Plan__c = p.planNumber;                    // PlanNumber
            record.FEC_REF_Number__c = p.refNumber;               // REFNumber
            
            // Map Date (Cần convert String -> Date)
            record.FEC_Open_Date__c = FEC_CommonUltils.parseDate(p.openDate);    // PlanOpenDate
            record.FEC_Begin_Date__c = FEC_CommonUltils.parseDate(p.beginDate);  // BeginDate
            
            // Map Decimal
            Decimal currentBalance = p.currentBalance != null ? p.currentBalance : 0;
            Decimal accruedInterest = p.accruedInterest != null ? p.accruedInterest : 0;
            Decimal perDiem = p.perDiem != null ? p.perDiem : 0;
            Decimal deferredInterest = p.deferredInterest != null ? p.deferredInterest : 0;
            Decimal ippAccruedInterest = p.additionalAccruedInt != null ? p.additionalAccruedInt : 0;
            
            record.FEC_Current_Balance__c = currentBalance;       // PlanCurrentBalance
            record.FEC_Base_Rate__c = p.baseRate;                 // BaseRate
            record.FEC_Deferred_Interest__c = deferredInterest;   // DeferredInterest
            record.FEC_Accrued_Interest__c = accruedInterest;     // AccruedInterest
            record.FEC_Per_Diem__c = perDiem;                     // PerDiem
            record.FEC_IPP_Interest__c = p.ippInterest;           // IPPInterest
            record.FEC_IPP_Accrued_Interest__c = ippAccruedInterest; // AccruedInt (IPP)
            
            // Close Fee % = (Close Fee Amount / Current Balance) * 100
            // FEC_Close_Fee__c là Decimal/Percent field
            Decimal closeFeePercent = 0;
            if (p.closeFeeIndicator == 'Y' && currentBalance > 0 && p.closeFeeIndicatorAmt != null) {
                closeFeePercent = (p.closeFeeIndicatorAmt / currentBalance) * 100;
                closeFeePercent = closeFeePercent.setScale(2, RoundingMode.HALF_UP);
            }
            record.FEC_Close_Fee__c = closeFeePercent;
            
            // Close Fee Amount = Close Fee Indicator Amount từ API
            Decimal closeFeeAmount = p.closeFeeIndicatorAmt != null ? p.closeFeeIndicatorAmt : 0;
            record.FEC_Close_Fee_Amount__c = closeFeeAmount;
            
            // Plan Payment Amount = Lấy trực tiếp từ API (PlanPaymentAmount)
            // KHÔNG tính toán lại để đảm bảo giá trị chính xác từ API
            Decimal planPaymentAmount = p.totalPaymentAmount != null ? p.totalPaymentAmount : 0;
            record.FEC_Plan_Payment_Amount__c = planPaymentAmount;

            recordsToInsert.add(record);
        }

        if (!recordsToInsert.isEmpty()) {
            try {
                insert recordsToInsert;
            } catch (Exception e) {
                throw new AuraHandledException(e.getMessage());
            }
        }
    }
    
    
}