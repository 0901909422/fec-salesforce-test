/**
 * Luồng giống FEC_StatementsAccountController: sync (gọi API, lưu DB) và load (chỉ đọc DB).
 * Account chỉ lấy từ FEC_Customer_History__c (qua IPP.FEC_Customer_History__c), không fallback.
 */
public with sharing class FEC_IPPScheduleController {

    /* =====================================================
       SYNC FROM API (giống syncStatementFromAPI)
       ===================================================== */
    /**
     * Sync IPP Schedule từ API: gọi GetCardSecInfo, lưu schedule vào DB; nếu thiếu Sales Info thì populate.
     * Chỉ chạy khi IPP có FEC_Customer_History__c và Customer History có FEC_Account_Number__c.
     */
    @AuraEnabled
    public static void syncIPPScheduleFromAPI(Id ippId) {
        if (ippId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Ipp Id'}));
        }

        FEC_IPP__c ippRecord = [
            SELECT Id, FEC_Customer_History__c, FEC_IPP_Record_No__c, FEC_IPP_Plan__c,
                   FEC_Application_ID__c, FEC_CC_Code__c, FEC_CC_Name__c, FEC_DSA_Code__c, FEC_DSA_Name__c,
                   FEC_TSA_Code__c, FEC_TSA_Name__c, FEC_Origination_Channel__c, FEC_Disbursement_Channel__c,
                   FEC_Sales_Mode__c, FEC_ESign_Source__c,
                   FEC_Total_IPP_Payment_Amount__c, FEC_Total_IPP_Monthly_Principal__c, FEC_Total_IPP_Monthly_Interest__c
            FROM FEC_IPP__c
            WHERE Id = :ippId
            LIMIT 1
        ];

        String accountNumber = getAccountNumberFromIpp(ippRecord);
        if (String.isBlank(accountNumber)) {
            return;
        }

        if (!hasSalesInfo(ippRecord)) {
            try {
                populateSalesInfoFromAPI(ippRecord);
                ippRecord = [SELECT Id, FEC_Customer_History__c, FEC_IPP_Record_No__c, FEC_IPP_Plan__c FROM FEC_IPP__c WHERE Id = :ippId LIMIT 1];
            } catch (Exception e) {
                System.debug('### populateSalesInfoFromAPI: ' + e.getMessage());
            }
        }

        // Mock mode: không gọi API thật
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting != null && apiSetting.FEC_Call_Mock__c == false) {
            System.debug('### Mock mode enabled, skipping GetCardSecInfo API');
            return;
        }

        // Gọi API trước; chỉ xóa + insert khi có dữ liệu trả về (tránh xóa xong API lỗi → mất hết 36 bản ghi)
        try {
            FEC_GetCardSecInfo.ResponseWrapper secResponse = FEC_GetCardSecInfo.getCardSecInfo(accountNumber);
            if (secResponse?.CardSecInfo?.IPPs != null && !secResponse.CardSecInfo.IPPs.isEmpty()) {
                List<FEC_GetCardSecInfo.IPP> ippList = secResponse.CardSecInfo.IPPs;
                List<FEC_GetCardSecInfo.IPP> filtered = filterIPPByRecordNoOrPlan(ippList, null, ippRecord.FEC_IPP_Plan__c);
                if (filtered.isEmpty() && String.isNotBlank(ippRecord.FEC_IPP_Record_No__c)) {
                    filtered = filterIPPByRecordNoOrPlan(ippList, ippRecord.FEC_IPP_Record_No__c, ippRecord.FEC_IPP_Plan__c);
                }
                if (filtered.isEmpty()) {
                    if (String.isBlank(ippRecord.FEC_IPP_Plan__c)) filtered = ippList;
                    else if (ippList.size() == 1) filtered = ippList;
                }
                if (!filtered.isEmpty()) {
                    deleteExistingScheduleData(ippId);
                    saveSchedulesToDatabase(filtered, ippRecord);
                }
            }
        } catch (Exception e) {
            System.debug('### GetCardSecInfo API FAILED: ' + e.getMessage());
        }
    }

    /**
     * Tải IPP Schedule + Sales Info từ database (chủ yếu query DB, không gọi GetCardSecInfo).
     * Nếu thiếu Sales Info thì gọi populate Sales Info từ API một lần rồi re-query IPP.
     * Để có schedule mới từ API: gọi syncIPPScheduleFromAPI trước (vd. nút Refresh), rồi getIPPScheduleData.
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getIPPScheduleData(String ippId) {
        if (ippId == null || String.isBlank(ippId)) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Ipp Id'}));
        }

        FEC_IPP__c ippRecord;
        List<FEC_IPP_Schedule__c> scheduleList = new List<FEC_IPP_Schedule__c>();

        try {
            ippRecord = [
                SELECT Id, FEC_Application_ID__c, FEC_Customer_History__c,
                       FEC_CC_Code__c, FEC_CC_Name__c, FEC_DSA_Code__c, FEC_DSA_Name__c,
                       FEC_TSA_Code__c, FEC_TSA_Name__c,
                       FEC_Origination_Channel__c, FEC_Disbursement_Channel__c,
                       FEC_Sales_Mode__c, FEC_ESign_Source__c,
                       FEC_Total_IPP_Payment_Amount__c, FEC_Total_IPP_Monthly_Principal__c, FEC_Total_IPP_Monthly_Interest__c,
                       FEC_IPP_Record_No__c, FEC_IPP_Plan__c
                FROM FEC_IPP__c
                WHERE Id = :ippId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        // Thiếu Sales Info thì populate một lần (mở trang lần đầu vẫn thấy Sales Info)
        if (!hasSalesInfo(ippRecord)) {
            try {
                populateSalesInfoFromAPI(ippRecord);
                ippRecord = [
                    SELECT Id, FEC_Application_ID__c, FEC_Customer_History__c,
                           FEC_CC_Code__c, FEC_CC_Name__c, FEC_DSA_Code__c, FEC_DSA_Name__c,
                           FEC_TSA_Code__c, FEC_TSA_Name__c,
                           FEC_Origination_Channel__c, FEC_Disbursement_Channel__c,
                           FEC_Sales_Mode__c, FEC_ESign_Source__c,
                           FEC_Total_IPP_Payment_Amount__c, FEC_Total_IPP_Monthly_Principal__c, FEC_Total_IPP_Monthly_Interest__c,
                           FEC_IPP_Record_No__c, FEC_IPP_Plan__c
                    FROM FEC_IPP__c
                    WHERE Id = :ippId
                    LIMIT 1
                ];
            } catch (Exception e) {
                System.debug('### populateSalesInfoFromAPI on load: ' + e.getMessage());
            }
        }

        try {
            scheduleList = [
                SELECT Id, Name, FEC_IPP_Payment_No__c, FEC_IPP_Opening_Balance__c, FEC_IPP_Payment_Amount__c,
                       FEC_IPP_Monthly_Principal__c, FEC_IPP_Monthly_Interest__c, CreatedDate
                FROM FEC_IPP_Schedule__c
                WHERE FEC_IPP__c = :ippId
                ORDER BY FEC_IPP_Payment_No__c ASC
            ];
        } catch (Exception e) {
            scheduleList = new List<FEC_IPP_Schedule__c>();
        }

        return buildResult(scheduleList != null ? scheduleList : new List<FEC_IPP_Schedule__c>(), ippRecord);
    }

    /**
     * Sync từ API rồi load từ DB (cho nút Refresh).
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> refreshIPPScheduleData(Id ippId) {
        syncIPPScheduleFromAPI(ippId);
        return getIPPScheduleData(ippId);
    }

    /**
     * Query chỉ lấy danh sách IPP Schedule (không gọi API).
     * @param ippId – ID của IPP record (Master-Detail)
     * @return List FEC_IPP_Schedule__c
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_IPP_Schedule__c> getIPPSchedules(String ippId) {
        try {
            return [
                SELECT Id, FEC_IPP_Payment_No__c, FEC_IPP_Opening_Balance__c, FEC_IPP_Payment_Amount__c,
                       FEC_IPP_Monthly_Principal__c, FEC_IPP_Monthly_Interest__c
                FROM FEC_IPP_Schedule__c
                WHERE FEC_IPP__c = :ippId
                ORDER BY FEC_IPP_Payment_No__c ASC
            ];
        } catch (Exception e) {
            System.debug('### IPPScheduleController.getIPPSchedules ERROR: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ------------------------- helpers -------------------------

    /**
     * Kiểm tra xem IPP record đã có Sales Info chưa
     * Sales Info được coi là có nếu có ít nhất một trong các trường: CC_Code, DSA_Code, TSA_Code, Application_ID
     */
    private static Boolean hasSalesInfo(FEC_IPP__c ipp) {
        if (ipp == null) {
            return false;
        }
        return String.isNotBlank(ipp.FEC_CC_Code__c) 
            || String.isNotBlank(ipp.FEC_DSA_Code__c) 
            || String.isNotBlank(ipp.FEC_TSA_Code__c)
            || String.isNotBlank(ipp.FEC_Application_ID__c);
    }

    /**
     * Gọi FEC_SalesInfoController để lấy Sales Info từ API và update vào IPP record hiện tại
     */
    private static void populateSalesInfoFromAPI(FEC_IPP__c ippRecord) {
        if (ippRecord == null || ippRecord.Id == null) {
            System.debug('### ERROR: IPP Record null or no Id, cannot populate Sales Info');
            return;
        }

        try {
            FEC_SalesInfoController.SalesInfoResult salesInfo = 
                FEC_SalesInfoController.getSalesInfoByIPPRecord(ippRecord.Id);
            
            if (salesInfo != null && salesInfo.isSuccess) {
                // Update Sales Info vào IPP record hiện tại
                FEC_IPP__c toUpdate = new FEC_IPP__c(Id = ippRecord.Id);
                Boolean hasUpdate = false;

                if (String.isNotBlank(salesInfo.applicationId)) {
                    toUpdate.FEC_Application_ID__c = salesInfo.applicationId;
                    hasUpdate = true;
                }
                if (String.isNotBlank(salesInfo.originationChannel)) {
                    toUpdate.FEC_Origination_Channel__c = salesInfo.originationChannel;
                    hasUpdate = true;
                }
                if (String.isNotBlank(salesInfo.disbursementChannel)) {
                    toUpdate.FEC_Disbursement_Channel__c = salesInfo.disbursementChannel;
                    hasUpdate = true;
                }
                if (String.isNotBlank(salesInfo.ccCode)) {
                    toUpdate.FEC_CC_Code__c = salesInfo.ccCode;
                    hasUpdate = true;
                }
                if (String.isNotBlank(salesInfo.ccName)) {
                    toUpdate.FEC_CC_Name__c = salesInfo.ccName;
                    hasUpdate = true;
                }
                if (String.isNotBlank(salesInfo.dsaCode)) {
                    toUpdate.FEC_DSA_Code__c = salesInfo.dsaCode;
                    hasUpdate = true;
                }
                if (String.isNotBlank(salesInfo.dsaName)) {
                    toUpdate.FEC_DSA_Name__c = salesInfo.dsaName;
                    hasUpdate = true;
                }
                if (String.isNotBlank(salesInfo.tsaCode)) {
                    toUpdate.FEC_TSA_Code__c = salesInfo.tsaCode;
                    hasUpdate = true;
                }
                if (String.isNotBlank(salesInfo.tsaName)) {
                    toUpdate.FEC_TSA_Name__c = salesInfo.tsaName;
                    hasUpdate = true;
                }

                if (hasUpdate) {
                    update toUpdate;
                    System.debug('### Successfully updated Sales Info for IPP ' + ippRecord.Id);
                } else {
                    System.debug('### No Sales Info fields to update');
                }
            } else {
                System.debug('### SalesInfo API returned failure: ' + 
                    (salesInfo != null ? salesInfo.errorMessage : 'null result'));
            }
        } catch (Exception e) {
            System.debug('### ERROR updating Sales Info: ' + e.getMessage());
            System.debug('### Stack Trace: ' + e.getStackTraceString());
            // Không throw exception để không làm gián đoạn luồng chính
        }
    }

    private static String getAccountNumberFromIpp(FEC_IPP__c ipp) {
        if (ipp == null || ipp.FEC_Customer_History__c == null) {
            return null;
        }
        List<FEC_Customer_History__c> ch = [
            SELECT FEC_Account_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :ipp.FEC_Customer_History__c
            LIMIT 1
        ];
        return (ch.isEmpty() || String.isBlank(ch[0].FEC_Account_Number__c)) ? null : ch[0].FEC_Account_Number__c;
    }

    private static List<FEC_GetCardSecInfo.IPP> filterIPPByRecordNoOrPlan(List<FEC_GetCardSecInfo.IPP> ippList, String ippRecordNo, String ippPlan) {
        if (ippList == null || ippList.isEmpty()) {
            return new List<FEC_GetCardSecInfo.IPP>();
        }
        List<FEC_GetCardSecInfo.IPP> filtered = new List<FEC_GetCardSecInfo.IPP>();

        if (String.isNotBlank(ippRecordNo)) {
            String norm = ippRecordNo.trim();
            for (FEC_GetCardSecInfo.IPP ipp : ippList) {
                if (ipp.IPPRecordNo != null && ipp.IPPRecordNo.trim().equalsIgnoreCase(norm)) {
                    filtered.add(ipp);
                }
            }
            if (!filtered.isEmpty()) {
                System.debug('### Filtered by Record No: ' + filtered.size() + ' matching ' + ippRecordNo);
                return filtered;
            }
        }

        if (String.isNotBlank(ippPlan)) {
            String norm = ippPlan.trim();
            for (FEC_GetCardSecInfo.IPP ipp : ippList) {
                if (ipp.IPPPlan != null && ipp.IPPPlan.trim().equalsIgnoreCase(norm)) {
                    filtered.add(ipp);
                }
            }
            if (!filtered.isEmpty()) {
                System.debug('### Filtered by Plan: ' + filtered.size() + ' matching ' + ippPlan);
                return filtered;
            }
        }

        System.debug('### No IPP schedule matched by Record No or Plan');
        return filtered;
    }

    /**
     * Xóa toàn bộ FEC_IPP_Schedule__c của IPP để sync lại từ API.
     */
    private static void deleteExistingScheduleData(Id ippId) {
        if (ippId == null) return;
        try {
            List<FEC_IPP_Schedule__c> existing = [SELECT Id FROM FEC_IPP_Schedule__c WHERE FEC_IPP__c = :ippId];
            if (!existing.isEmpty()) delete existing;
        } catch (Exception e) {
            System.debug('### deleteExistingScheduleData: ' + e.getMessage());
        }
    }

    /**
     * Lưu IPP Schedule từ API vào DB (chỉ INSERT). Sync đã gọi deleteExistingScheduleData trước.
     */
    private static void saveSchedulesToDatabase(List<FEC_GetCardSecInfo.IPP> ippList, FEC_IPP__c ippRecord) {
        if (ippRecord == null || ippRecord.Id == null) return;
        if (ippList == null || ippList.isEmpty()) {
            System.debug('### IPP List empty, nothing to save');
            return;
        }

        List<FEC_IPP_Schedule__c> toInsert = new List<FEC_IPP_Schedule__c>();
        Integer paymentNo = 1;
        for (FEC_GetCardSecInfo.IPP ipp : ippList) {
            FEC_IPP_Schedule__c sch = new FEC_IPP_Schedule__c();
            sch.FEC_IPP__c = ippRecord.Id;
            sch.FEC_IPP_Payment_No__c = paymentNo;
            sch.FEC_IPP_Opening_Balance__c = ipp.OpeningBalance != null ? ipp.OpeningBalance : 0;
            sch.FEC_IPP_Payment_Amount__c = ipp.PaymentAmount != null ? ipp.PaymentAmount : 0;
            sch.FEC_IPP_Monthly_Principal__c = ipp.MonthlyPrincipal != null ? ipp.MonthlyPrincipal : 0;
            sch.FEC_IPP_Monthly_Interest__c = ipp.MonthlyInterest != null ? ipp.MonthlyInterest : 0;
            toInsert.add(sch);
            paymentNo++;
        }

        if (!toInsert.isEmpty()) {
            try {
                insert toInsert;
                System.debug('### Inserted ' + toInsert.size() + ' IPP Schedule records for IPP ' + ippRecord.Id);
            } catch (Exception e) {
                System.debug('### ERROR inserting IPP Schedule: ' + e.getMessage());
                throw new AuraHandledException(e.getMessage());
            }
        }
    }

    private static Map<String, Object> buildResult(List<FEC_IPP_Schedule__c> schedules, FEC_IPP__c ippRecord) {
        List<FEC_IPP_Schedule__c> listVal = schedules != null ? schedules : new List<FEC_IPP_Schedule__c>();

        // Luôn tính total từ danh sách schedule để khớp với tổng các dòng trong bảng
        Decimal totalPaymentAmount = 0;
        Decimal totalMonthlyPrincipal = 0;
        Decimal totalMonthlyInterest = 0;
        for (FEC_IPP_Schedule__c sch : listVal) {
            totalPaymentAmount += (sch.FEC_IPP_Payment_Amount__c != null ? sch.FEC_IPP_Payment_Amount__c : 0);
            totalMonthlyPrincipal += (sch.FEC_IPP_Monthly_Principal__c != null ? sch.FEC_IPP_Monthly_Principal__c : 0);
            totalMonthlyInterest += (sch.FEC_IPP_Monthly_Interest__c != null ? sch.FEC_IPP_Monthly_Interest__c : 0);
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('schedules', listVal);
        result.put('totalPaymentAmount', totalPaymentAmount);
        result.put('totalMonthlyPrincipal', totalMonthlyPrincipal);
        result.put('totalMonthlyInterest', totalMonthlyInterest);
        result.put('ippRecord', ippRecord);
        return result;
    }
}