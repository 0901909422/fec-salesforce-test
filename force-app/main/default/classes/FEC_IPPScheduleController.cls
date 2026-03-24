/** Sync IPP Schedule (API → DB) và load từ DB. Account lấy từ FEC_Customer_History__c. */
public with sharing class FEC_IPPScheduleController {

    /** Sync schedule từ GetCardSecInfo (không populate Sales). Dùng nội bộ / tích hợp. */
    @AuraEnabled
    public static String syncIPPScheduleFromAPI(Id ippId) {
        if (ippId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Ipp Id'}));
        }
        FEC_IPP__c ippRecord = [
            SELECT Id, FEC_Customer_History__c, FEC_IPP_Record_No__c, FEC_IPP_Plan__c
            FROM FEC_IPP__c
            WHERE Id = :ippId
            LIMIT 1
        ];
        return syncIppDataFromApis(ippRecord, true);
    }

    /**
     * Mỗi lần gọi: luôn gọi API GetCardSecInfo để đồng bộ lịch IPP xuống DB.
     * Nếu skipPopulateSalesInfo=false và IPP chưa có Sales Info: gọi Sales API trước (cùng transaction: mọi callout trước DML).
     * Return: null=OK lịch; NO_ACCOUNT_NUMBER, API_RETURNED_NO_IPPS, FILTER_EMPTY, API_ERROR:...
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getIPPScheduleData(String ippId, Boolean skipPopulateSalesInfo) {
        if (ippId == null || String.isBlank(ippId)) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Ipp Id'}));
        }
        if (skipPopulateSalesInfo == null) {
            skipPopulateSalesInfo = false;
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

        String emptyScheduleReason = syncIppDataFromApis(ippRecord, skipPopulateSalesInfo);

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
            System.debug('### getIPPScheduleData re-query IPP: ' + e.getMessage());
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
            System.debug('### getIPPScheduleData query schedule failed: ' + e.getMessage());
            scheduleList = new List<FEC_IPP_Schedule__c>();
        }

        List<FEC_IPP_Schedule__c> listVal = scheduleList != null ? scheduleList : new List<FEC_IPP_Schedule__c>();
        System.debug(LoggingLevel.INFO, '### [getIPPScheduleData] ippId=' + ippId + ', scheduleCount=' + listVal.size());
        if (listVal.isEmpty()) {
            System.debug(LoggingLevel.WARN, '### [getIPPScheduleData] KHÔNG có schedule nào trong DB cho IPP ' + ippId);
        } else {
            System.debug(LoggingLevel.INFO, '### [getIPPScheduleData] sample row: PaymentNo=' + listVal[0].FEC_IPP_Payment_No__c + ', OpeningBalance=' + listVal[0].FEC_IPP_Opening_Balance__c);
        }
        Map<String, Object> result = buildResult(listVal, ippRecord);
        if (String.isNotBlank(emptyScheduleReason)) {
            result.put('emptyScheduleReason', emptyScheduleReason);
        }
        return result;
    }

    /** Giống getIPPScheduleData(ippId, true): đồng bộ lịch từ API, không populate Sales. */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> refreshIPPScheduleData(Id ippId) {
        if (ippId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Ipp Id'}));
        }
        System.debug(LoggingLevel.INFO, '### [refreshIPPScheduleData] ippId=' + ippId);
        return getIPPScheduleData(String.valueOf(ippId), true);
    }

    /** Query IPP Schedule từ DB (không gọi API). */
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

    /** Gọi API Sales Info, map vào ippRecord (không update DB). Return true nếu có thay đổi để update sau. */
    private static Boolean fetchAndMapSalesInfo(FEC_IPP__c ippRecord) {
        if (ippRecord == null || ippRecord.Id == null) return false;
        try {
            FEC_SalesInfoController.SalesInfoResult salesInfo = FEC_SalesInfoController.getSalesInfoByIPPRecord(ippRecord.Id);
            if (salesInfo == null || !salesInfo.isSuccess) return false;
            Boolean hasUpdate = false;
            if (String.isNotBlank(salesInfo.applicationId)) { ippRecord.FEC_Application_ID__c = salesInfo.applicationId; hasUpdate = true; }
            if (String.isNotBlank(salesInfo.originationChannel)) { ippRecord.FEC_Origination_Channel__c = salesInfo.originationChannel; hasUpdate = true; }
            if (String.isNotBlank(salesInfo.disbursementChannel)) { ippRecord.FEC_Disbursement_Channel__c = salesInfo.disbursementChannel; hasUpdate = true; }
            if (String.isNotBlank(salesInfo.ccCode)) { ippRecord.FEC_CC_Code__c = salesInfo.ccCode; hasUpdate = true; }
            if (String.isNotBlank(salesInfo.ccName)) { ippRecord.FEC_CC_Name__c = salesInfo.ccName; hasUpdate = true; }
            if (String.isNotBlank(salesInfo.dsaCode)) { ippRecord.FEC_DSA_Code__c = salesInfo.dsaCode; hasUpdate = true; }
            if (String.isNotBlank(salesInfo.dsaName)) { ippRecord.FEC_DSA_Name__c = salesInfo.dsaName; hasUpdate = true; }
            if (String.isNotBlank(salesInfo.tsaCode)) { ippRecord.FEC_TSA_Code__c = salesInfo.tsaCode; hasUpdate = true; }
            if (String.isNotBlank(salesInfo.tsaName)) { ippRecord.FEC_TSA_Name__c = salesInfo.tsaName; hasUpdate = true; }
            return hasUpdate;
        } catch (Exception e) {
            System.debug('### fetchAndMapSalesInfo: ' + e.getMessage());
            return false;
        }
    }

    /** Có Sales Info nếu có ít nhất CC_Code, DSA_Code, TSA_Code hoặc Application_ID. */
    private static Boolean hasSalesInfo(FEC_IPP__c ipp) {
        if (ipp == null) {
            return false;
        }
        return String.isNotBlank(ipp.FEC_CC_Code__c) 
            || String.isNotBlank(ipp.FEC_DSA_Code__c) 
            || String.isNotBlank(ipp.FEC_TSA_Code__c)
            || String.isNotBlank(ipp.FEC_Application_ID__c);
    }

    /** Update IPP từ kết quả Sales Info API (chỉ DML). */
    private static void applySalesInfoDml(Id ippId, FEC_SalesInfoController.SalesInfoResult salesInfo) {
        if (ippId == null || salesInfo == null || !salesInfo.isSuccess) {
            return;
        }
        FEC_IPP__c toUpdate = new FEC_IPP__c(Id = ippId);
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
        }
    }

    /**
     * Callout Sales (nếu cần) + GetCardSecInfo, sau đó DML Sales + lịch IPP.
     * Không gọi callout sau DML.
     */
    private static String syncIppDataFromApis(FEC_IPP__c ippRecord, Boolean skipPopulateSalesInfo) {
        if (ippRecord == null || ippRecord.Id == null) {
            return null;
        }

        FEC_SalesInfoController.SalesInfoResult salesInfo = null;
        if (skipPopulateSalesInfo != true && !hasSalesInfo(ippRecord)) {
            try {
                salesInfo = FEC_SalesInfoController.getSalesInfoByIPPRecord(ippRecord.Id);
            } catch (Exception e) {
                System.debug('### syncIppDataFromApis Sales API: ' + e.getMessage());
            }
        }

        List<FEC_GetCardSecInfo.IPP> ippList = new List<FEC_GetCardSecInfo.IPP>();
        List<FEC_GetCardSecInfo.IPP> filtered = new List<FEC_GetCardSecInfo.IPP>();
        String scheduleReason = null;
        String accountNumber = getAccountNumberFromIpp(ippRecord);

        if (String.isBlank(accountNumber)) {
            scheduleReason = 'NO_ACCOUNT_NUMBER';
            System.debug(LoggingLevel.WARN, '### [syncIppDataFromApis] Không có Account Number — không gọi GetCardSecInfo.');
        } else {
            try {
                FEC_GetCardSecInfo.ResponseWrapper secResponse = FEC_GetCardSecInfo.getCardSecInfo(accountNumber);
                ippList = (secResponse != null && secResponse.CardSecInfo != null && secResponse.CardSecInfo.IPPs != null)
                    ? secResponse.CardSecInfo.IPPs
                    : new List<FEC_GetCardSecInfo.IPP>();
                if (!ippList.isEmpty()) {
                    filtered = filterIPPByRecordNoOrPlan(ippList, ippRecord.FEC_IPP_Record_No__c, ippRecord.FEC_IPP_Plan__c);
                }
            } catch (Exception e) {
                System.debug('### GetCardSecInfo API FAILED: ' + e.getMessage());
                scheduleReason = 'API_ERROR: ' + (e.getMessage() != null ? e.getMessage().left(200) : '');
            }
        }

        Savepoint sp = Database.setSavepoint();
        try {
            applySalesInfoDml(ippRecord.Id, salesInfo);

            if (String.isBlank(accountNumber)) {
                return scheduleReason;
            }
            if (String.isNotBlank(scheduleReason) && scheduleReason.startsWith('API_ERROR')) {
                return scheduleReason;
            }
            if (filtered.isEmpty()) {
                return ippList.isEmpty() ? 'API_RETURNED_NO_IPPS' : 'FILTER_EMPTY';
            }
            deleteExistingScheduleData(ippRecord.Id);
            saveSchedulesToDatabase(filtered, ippRecord);
            return null;
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('### DML ERROR: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Lỗi khi lưu dữ liệu xuống hệ thống: ' + e.getMessage());
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

    /** Xóa schedule cũ của IPP trước khi sync. */
    private static void deleteExistingScheduleData(Id ippId) {
        if (ippId == null) return;
        try {
            List<FEC_IPP_Schedule__c> existing = [SELECT Id FROM FEC_IPP_Schedule__c WHERE FEC_IPP__c = :ippId];
            if (!existing.isEmpty()) delete existing;
        } catch (Exception e) {
            System.debug('### deleteExistingScheduleData: ' + e.getMessage());
        }
    }

    /** Insert schedule từ API vào DB (đã xóa cũ trước đó). */
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
                System.debug(LoggingLevel.INFO, '### [saveSchedulesToDatabase] Đã insert ' + toInsert.size() + ' FEC_IPP_Schedule__c cho IPP ' + ippRecord.Id);
            } catch (Exception e) {
                System.debug('### ERROR inserting IPP Schedule: ' + e.getMessage());
                throw new AuraHandledException(e.getMessage());
            }
        }
    }

    private static Map<String, Object> buildResult(List<FEC_IPP_Schedule__c> schedules, FEC_IPP__c ippRecord) {
        List<FEC_IPP_Schedule__c> listVal = schedules != null ? schedules : new List<FEC_IPP_Schedule__c>();
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