public with sharing class FEC_CardPaymentController {
    
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
            System.debug('### Load Card Payment Records FAILED: ' + e.getMessage());
        }

        /* =====================================================
         * BƯỚC 2: KIỂM TRA XEM CÓ DỮ LIỆU KHÔNG
         * Nếu đã có dữ liệu trong database → return luôn (không gọi API)
         * ===================================================== */
        Boolean hasCardPaymentData = records != null && records.size() > 0;

        // Nếu đã có dữ liệu → return luôn (không gọi API nữa)
        if (hasCardPaymentData) {
            System.debug('### Found Card Payment data in database, returning without API call');
            return records;
        }

        /* =====================================================
         * BƯỚC 3: KHÔNG CÓ DỮ LIỆU → GỌI API (CHỈ 1 LẦN DUY NHẤT)
         * ===================================================== */
        System.debug('### No Card Payment data found in database, calling API...');

        if (String.isBlank(accountNumber)) {
            System.debug('### Account Number is blank, cannot call API');
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
            System.debug('### Reload Card Payment Records FAILED: ' + e.getMessage());
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
     * @return Map chứa payment totals
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Decimal> loadCardPaymentTotals(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('CaseId is required');
        }

        Map<String, Decimal> totals = new Map<String, Decimal>();
        totals.put('fullPaymentAmount', 0);
        totals.put('loanBalance', 0);
        totals.put('fullPaymentWithoutIPP', 0);
        totals.put('fullIPPPaymentAmount', 0);

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
            System.debug('### Customer History not found for Case: ' + caseId);
            return totals;
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
                totals.put('fullPaymentAmount', payment.FEC_Full_Payment_Amount__c != null ? payment.FEC_Full_Payment_Amount__c : 0);
                totals.put('loanBalance', payment.FEC_Loan_Balance__c != null ? payment.FEC_Loan_Balance__c : 0);
                totals.put('fullPaymentWithoutIPP', payment.FEC_Full_Payment_Without_IPP__c != null ? payment.FEC_Full_Payment_Without_IPP__c : 0);
                totals.put('fullIPPPaymentAmount', payment.FEC_Full_IPP_Payment_Amount__c != null ? payment.FEC_Full_IPP_Payment_Amount__c : 0);
                System.debug('### Found Card Payment Totals in database, returning without API call');
                return totals;
            }
        } catch (Exception e) {
            System.debug('### Load Card Payment Totals from DB FAILED: ' + e.getMessage());
        }

        /* =====================================================
         * BƯỚC 2: KHÔNG CÓ DỮ LIỆU → GỌI API (CHỈ 1 LẦN DUY NHẤT)
         * Lưu ý: Tất cả các API chỉ được gọi 1 lần duy nhất ở đây
         * ===================================================== */
        System.debug('### No Card Payment Totals found in database, calling API (ONLY ONCE)...');

        if (String.isBlank(accountNumber)) {
            System.debug('### Account Number is blank, cannot call API');
            return totals;
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
            System.debug('Full Payment Amount from API: ' + fullPaymentAmount);
        } catch (Exception e) {
            System.debug('### GetCardPaymentInfo API FAILED: ' + e.getMessage());
        }

        /* ===== 2. Gọi API GetCardBasicInfo để lấy Loan Balance ===== */
        try {
            String transId = UUID.randomUUID().toString();
            String requestorId = 'CRM';
            String dateTimeStr = Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss');
            
            FEC_GetCardBasicInfo.ResponseWrapper basicInfoResult = 
                FEC_GetCardBasicInfo.callGetCardBasicInfo(transId, requestorId, dateTimeStr, accountNumber);
            
            if (basicInfoResult != null && 
                basicInfoResult.CardBasicInfo != null && 
                basicInfoResult.CardBasicInfo.MainCard != null &&
                basicInfoResult.CardBasicInfo.MainCard.LoanBalance != null) {
                loanBalance = basicInfoResult.CardBasicInfo.MainCard.LoanBalance;
            }
            System.debug('Loan Balance from API: ' + loanBalance);
        } catch (Exception e) {
            System.debug('### GetCardBasicInfo API FAILED: ' + e.getMessage());
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
                    System.debug('OnlineTotalBalance from M_CMS_EMEA_ACCOUNT_INQ: ' + onlineTotalBalance + 
                                ' (CURR_BAL=' + currBal + ', AMT_MEMO_DB=' + amtMemoDb + ', AMT_MEMO_CR=' + amtMemoCr + ')');
                }
            } catch (Exception e) {
                System.debug('### M_CMS_EMEA_ACCOUNT_INQ API FAILED: ' + e.getMessage());
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
                    System.debug('TotalDeferredInterestPlan: ' + totalDeferredInterestPlan);
                    System.debug('TotalAccuredInterestPlan: ' + totalAccuredInterestPlan);
                    System.debug('TotalPerDiemPlan: ' + totalPerDiemPlan);
                }
            } catch (Exception e) {
                System.debug('### GetCardPlanInfo API FAILED for Full Payment Without IPP: ' + e.getMessage());
            }

            // 3.3. Tính Full Payment Without IPP
            // = OnlineTotalBalance + TotalDeferredInterestPlan + TotalAccuredInterestPlan + TotalPerDiemPlan - LoanBalance
            fullPaymentWithoutIPP = onlineTotalBalance + totalDeferredInterestPlan + totalAccuredInterestPlan + totalPerDiemPlan - loanBalance;
            System.debug('Full Payment Without IPP calculated: ' + fullPaymentWithoutIPP + 
                        ' = ' + onlineTotalBalance + ' + ' + totalDeferredInterestPlan + ' + ' + 
                        totalAccuredInterestPlan + ' + ' + totalPerDiemPlan + ' - ' + loanBalance);
        } catch (Exception e) {
            System.debug('### Calculate Full Payment Without IPP FAILED: ' + e.getMessage());
        }

        /* ===== 4. Tính Full IPP Payment Amount ===== */
        Decimal fullIPPPaymentAmount = 0;
        if (fullPaymentAmount != 0 && fullPaymentWithoutIPP != 0) {
            // Full IPP Payment Amount = Full Payment Amount - Full Payment Without IPP
            fullIPPPaymentAmount = fullPaymentAmount - fullPaymentWithoutIPP;
            System.debug('Full IPP Payment Amount calculated: ' + fullIPPPaymentAmount + 
                        ' = ' + fullPaymentAmount + ' - ' + fullPaymentWithoutIPP);
        }

        /* =====================================================
         * BƯỚC 3: LƯU DỮ LIỆU VÀO DATABASE (CHỈ 1 LẦN DUY NHẤT)
         * Lưu ý: Method này chỉ được gọi 1 lần sau khi gọi API
         * ===================================================== */
        if (fullPaymentAmount != 0 || loanBalance != 0 || fullPaymentWithoutIPP != 0 || fullIPPPaymentAmount != 0) {
            System.debug('### Saving Card Payment Totals to database (ONLY ONCE)...');
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
                totals.put('fullPaymentAmount', payment.FEC_Full_Payment_Amount__c != null ? payment.FEC_Full_Payment_Amount__c : 0);
                totals.put('loanBalance', payment.FEC_Loan_Balance__c != null ? payment.FEC_Loan_Balance__c : 0);
                totals.put('fullPaymentWithoutIPP', payment.FEC_Full_Payment_Without_IPP__c != null ? payment.FEC_Full_Payment_Without_IPP__c : 0);
                totals.put('fullIPPPaymentAmount', payment.FEC_Full_IPP_Payment_Amount__c != null ? payment.FEC_Full_IPP_Payment_Amount__c : 0);
                System.debug('### Reloaded Card Payment Totals from database after API call');
            } else {
                // Nếu không có trong database (do lưu thất bại) → trả về lỗi
                System.debug('### ERROR: No data in database after save, throwing exception');
                throw new AuraHandledException('Tải dữ liệu không thành công');
            }
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException để LWC có thể hiển thị lỗi
            System.debug('### Reload Card Payment Totals from DB FAILED: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            // Nếu có exception khác → cũng trả về lỗi
            System.debug('### Reload Card Payment Totals from DB FAILED: ' + e.getMessage());
            throw new AuraHandledException('Tải dữ liệu không thành công');
        }

        return totals;
    }

    /**
     * Get Card Payment totals
     * Method này wrapper của loadCardPaymentTotals() để backward compatibility
     * @param caseId - The Case record ID
     * @return Map containing payment totals
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Decimal> getCardPaymentTotals(String caseId) {
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
            System.debug('Customer History ID is null, cannot save totals');
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
                    System.debug('### Card Payment Totals đã tồn tại trong database, không update');
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
                System.debug('Setting Full Payment Amount: ' + fullPaymentAmount);
            }

            if (paymentToUpdate.FEC_Loan_Balance__c == null && loanBalance != 0) {
                paymentToUpdate.FEC_Loan_Balance__c = loanBalance;
                needsUpdate = true;
                System.debug('Setting Loan Balance: ' + loanBalance);
            }

            if (paymentToUpdate.FEC_Full_Payment_Without_IPP__c == null && fullPaymentWithoutIPP != 0) {
                paymentToUpdate.FEC_Full_Payment_Without_IPP__c = fullPaymentWithoutIPP;
                needsUpdate = true;
                System.debug('Setting Full Payment Without IPP: ' + fullPaymentWithoutIPP);
            }

            if (paymentToUpdate.FEC_Full_IPP_Payment_Amount__c == null && fullIPPPaymentAmount != 0) {
                paymentToUpdate.FEC_Full_IPP_Payment_Amount__c = fullIPPPaymentAmount;
                needsUpdate = true;
                System.debug('Setting Full IPP Payment Amount: ' + fullIPPPaymentAmount);
            }

            if (needsUpdate) {
                if (paymentToUpdate.Id != null) {
                    update paymentToUpdate;
                } else {
                    insert paymentToUpdate;
                }
                System.debug('Đã lưu Card Payment Totals vào database');
            }
        } catch (Exception e) {
            System.debug('Lỗi khi lưu Card Payment Totals: ' + e.getMessage());
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
        
        System.debug('🔍 Found ' + existingRecords.size() + ' existing records in DB');
        
        List<FEC_Card_Payment__c> recordsToInsert = new List<FEC_Card_Payment__c>();

        for (FEC_GetCardPlanInfo.CardPlan p : planList) {
            // Tạo key để kiểm tra: Rec__c + Plan__c
            String key = (p.recordNumber != null ? p.recordNumber : '') + '_' + 
                        (p.planNumber != null ? p.planNumber : '');
            
            // Nếu key đã tồn tại → bỏ qua (không insert, không update)
            if (existingKeys.contains(key)) {
                System.debug('### Card Payment record already exists: Rec=' + p.recordNumber + ', Plan=' + p.planNumber + ', skipping insert');
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
            record.FEC_Open_Date__c = convertDateSafe(p.openDate);    // PlanOpenDate
            record.FEC_Begin_Date__c = convertDateSafe(p.beginDate);  // BeginDate
            
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
            System.debug('Creating new Card Payment record: Rec=' + p.recordNumber + ', Plan=' + p.planNumber);
        }

        System.debug('Total records to insert: ' + recordsToInsert.size());

        if (!recordsToInsert.isEmpty()) {
            try {
                insert recordsToInsert;
                System.debug('Đã insert thành công ' + recordsToInsert.size() + ' Card Payment records vào DB.');
            } catch (Exception e) {
                System.debug('Lỗi khi lưu DB: ' + e.getMessage());
                throw new AuraHandledException('Lỗi lưu dữ liệu: ' + e.getMessage());
            }
        } else {
            System.debug('Không có records mới để insert!');
        }
    }
    
    /**
     * Hàm phụ trợ convert ngày tháng
     * @param dateStr - Date string format yyyy-MM-dd
     * @return Date object
     */
    private static Date convertDateSafe(String dateStr) {
        if (String.isBlank(dateStr)) return null;
        try {
            return Date.valueOf(dateStr); // Format yêu cầu: YYYY-MM-DD
        } catch (Exception e) {
            return null;
        }
    }
}