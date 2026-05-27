/**
 * Mock data chung cho Card Info, Card Payment và IPP.
 * Dùng khi FEC_API_Setting__c.FEC_Call_Mock__c = true (dev/SIT).
 * Controller gọi khi API không có data hoặc lỗi.
 */
public with sharing class FEC_MockData {

    /** Số bản ghi Card Delivery mock trả về UI khi FEC_Call_Mock__c = true. */
    private static final Integer MOCK_CARD_DELIVERY_UI_RECORD_COUNT = 20;
    /** Số bản ghi IPP mock trả về UI khi FEC_Call_Mock__c = true. */
    private static final Integer MOCK_IPP_UI_RECORD_COUNT = 20;
    /** Id mock có đủ Sales Info + schedule demo (plan 60001). */
    private static final String MOCK_IPP_DETAIL_RECORD_ID = 'mock-ipp-004';

    // ==================== CARD INFO (Card Delivery + Other Cards) ====================

    /**
     * Trả về dữ liệu hardcode Card Info (Card Delivery + Other Cards).
     * FEC_CardInfoController gọi khi Mock bật và API không có data/lỗi.
     */
    public static FEC_CardInfoController.CardInfoDTO getHardcodedCardInfo() {
        FEC_CardInfoController.CardInfoDTO dto = new FEC_CardInfoController.CardInfoDTO();
        dto.cardDeliveries = new List<FEC_CardInfoController.CardDeliveryDTO>();
        dto.otherCards = new List<FEC_CardInfoController.OtherCardDTO>();

        // Card Delivery - đầy đủ 8 field (khớp cột fec_CardInfo)
        dto.cardDeliveries.add(newCardDelivery(
            '0005395XXXXXXXX7595', Date.valueOf('2023-08-10'), 'New Card', 'Delivered',
            Date.valueOf('2023-12-06'), 'TEST NAME1', 'TRK-5395-20231206', 'Giao thành công'));
        dto.cardDeliveries.add(newCardDelivery(
            '034204XXXXXXXX022', Date.valueOf('2026-01-10'), 'New Card', 'Hoàn tất',
            Date.valueOf('2026-01-12'), 'Nguyen Duc Minh', '1000031234567', 'Đã vận chuyển đến nơi'));
        dto.cardDeliveries.add(newCardDelivery(
            '411111XXXXXXXX1111', Date.valueOf('2025-01-15'), 'New Card', 'Delivered',
            Date.valueOf('2025-01-20'), 'Nguyen Van A', 'VN123456789', 'Giao thành công'));
        dto.cardDeliveries.add(newCardDelivery(
            '550000XXXXXXXX0001', Date.valueOf('2024-11-10'), 'Replacement', 'In Transit',
            Date.valueOf('2024-11-18'), 'Tran Thi B', 'VN987654321', 'Đang vận chuyển'));
        dto.cardDeliveries.add(newCardDelivery(
            '378282XXXXXXXX0012', Date.valueOf('2024-09-05'), 'New Card', 'Delivered',
            Date.valueOf('2024-09-12'), 'Le Van C', 'VN555666777', 'Đã ký nhận'));
        dto.cardDeliveries.add(newCardDelivery(
            '601100XXXXXXXX9012', Date.valueOf('2024-06-20'), 'Reissue', 'Pending',
            Date.valueOf('2024-07-05'), 'Pham Van D', 'VN444333222', 'Chờ in thẻ'));

        for (Integer n = 7; n <= MOCK_CARD_DELIVERY_UI_RECORD_COUNT; n++) {
            dto.cardDeliveries.add(buildGeneratedCardDelivery(n));
        }

        // Other Cards - nhiều bản ghi mẫu
        dto.otherCards.add(newOtherCard(
            'NGUYEN DUC MINH', '034204******022', 'PL001', Date.valueOf('2028-01-10'),
            Date.valueOf('2026-01-11'), Date.valueOf('2026-01-10'), '0', 'M'));
        dto.otherCards.add(newOtherCard(
            'TRAN THI B', '550000******0001', 'PL002', Date.valueOf('2027-11-10'),
            Date.valueOf('2024-11-15'), Date.valueOf('2024-11-10'), '0', 'F'));
        dto.otherCards.add(newOtherCard(
            'LE VAN C', '378282******0012', 'PL003', Date.valueOf('2027-09-05'),
            Date.valueOf('2024-09-08'), Date.valueOf('2024-09-05'), '1', 'M'));

        return dto;
    }

    private static FEC_CardInfoController.CardDeliveryDTO buildGeneratedCardDelivery(Integer seq) {
        List<String> typesOfIssue = new List<String>{
            'New Card', 'Replacement', 'Reissue', 'Renewal'
        };
        List<String> deliveryStatuses = new List<String>{
            'Delivered', 'In Transit', 'Hoàn tất', 'Pending', 'Processing'
        };
        List<String> deliveryNotes = new List<String>{
            'Giao thành công',
            'Đang vận chuyển',
            'Đã vận chuyển đến nơi',
            'Đã ký nhận',
            'Chờ in thẻ',
            'Giao lại lần 2'
        };

        String seqStr = seq < 10 ? '0' + String.valueOf(seq) : String.valueOf(seq);
        String cardNumber = '4532' + seqStr + 'XXXXXXXX' + String.valueOf(1000 + seq);
        Integer monthsBack = seq * 2;
        Date issueDate = Date.today().addMonths(-monthsBack);
        Date deliveryDate = issueDate.addDays(10 + Math.mod(seq, 20));
        String typeOfIssue = typesOfIssue[Math.mod(seq, typesOfIssue.size())];
        String deliveryStatus = deliveryStatuses[Math.mod(seq, deliveryStatuses.size())];
        String recipient = 'Mock Recipient ' + seqStr;
        String trackingNumber = 'TRK-MOCK-' + seqStr + '-' + String.valueOf(issueDate.year());
        String deliveryNote = deliveryNotes[Math.mod(seq, deliveryNotes.size())] + ' #' + seqStr;

        return newCardDelivery(
            cardNumber,
            issueDate,
            typeOfIssue,
            deliveryStatus,
            deliveryDate,
            recipient,
            trackingNumber,
            deliveryNote
        );
    }

    private static FEC_CardInfoController.CardDeliveryDTO newCardDelivery(
            String cardNumber, Date issueDate, String typeOfIssue, String deliveryStatus,
            Date deliveryDate, String recipient, String trackingNumber, String deliveryNote) {
        FEC_CardInfoController.CardDeliveryDTO dto = new FEC_CardInfoController.CardDeliveryDTO();
        dto.cardNumber = cardNumber;
        dto.issueDate = issueDate;
        dto.typeOfIssue = typeOfIssue;
        dto.deliveryStatus = deliveryStatus;
        dto.deliveryDate = deliveryDate;
        dto.recipient = recipient;
        dto.trackingNumber = trackingNumber;
        dto.deliveryNote = deliveryNote;
        return dto;
    }

    private static FEC_CardInfoController.OtherCardDTO newOtherCard(
            String cardholder, String cardNumber, String plasticId, Date expiryDate,
            Date cardActivationDate, Date issueDate, String blockCode, String gender) {
        FEC_CardInfoController.OtherCardDTO dto = new FEC_CardInfoController.OtherCardDTO();
        dto.cardholder = cardholder;
        dto.cardNumber = cardNumber;
        dto.plasticId = plasticId;
        dto.expiryDate = expiryDate;
        dto.embossingName = cardholder;
        dto.cardActivationDate = cardActivationDate;
        dto.issueDate = issueDate;
        dto.blockCode = blockCode;
        dto.gender = gender;
        return dto;
    }

    // ==================== CARD PAYMENT ====================

    /**
     * Trả về danh sách Card Payment records hardcode cho UI (loadCardPaymentInfo fallback).
     * Có bản ghi với giá trị âm để test highlight đỏ (balance, interest, fee...).
     */
    public static List<Map<String, Object>> getHardcodedCardPaymentRecordsForUI() {
        List<Map<String, Object>> records = new List<Map<String, Object>>();
        // Record 1: balance âm (credit)
        Map<String, Object> r = new Map<String, Object>();
        r.put('FEC_Rec__c', '1');
        r.put('FEC_REF_Number__c', 'REF-DEMO-001');
        r.put('FEC_Current_Balance__c', -45000000);
        r.put('FEC_Open_Date__c', Date.valueOf('2025-01-15'));
        r.put('FEC_Plan__c', 'PLAN-001');
        r.put('FEC_Base_Rate__c', 1.5);
        r.put('FEC_Begin_Date__c', Date.valueOf('2025-01-15'));
        r.put('FEC_Accrued_Interest__c', 675000);
        r.put('FEC_Per_Diem__c', 22500);
        r.put('FEC_Deferred_Interest__c', 0);
        r.put('FEC_IPP_Interest__c', 1.5);
        r.put('FEC_IPP_Accrued_Interest__c', 67500);
        r.put('FEC_Close_Fee__c', 2);
        r.put('FEC_Close_Fee_Amount__c', 900000);
        r.put('FEC_Plan_Payment_Amount__c', 5000000);
        records.add(r);
        // Record 2: nhiều trường âm để test highlight đỏ
        Map<String, Object> r2 = new Map<String, Object>();
        r2.put('FEC_Rec__c', '2');
        r2.put('FEC_REF_Number__c', 'REF-DEMO-002');
        r2.put('FEC_Current_Balance__c', -12000000);
        r2.put('FEC_Open_Date__c', Date.valueOf('2025-02-01'));
        r2.put('FEC_Plan__c', 'PLAN-002');
        r2.put('FEC_Base_Rate__c', 1.2);
        r2.put('FEC_Begin_Date__c', Date.valueOf('2025-02-01'));
        r2.put('FEC_Accrued_Interest__c', -150000);
        r2.put('FEC_Per_Diem__c', -5000);
        r2.put('FEC_Deferred_Interest__c', -200000);
        r2.put('FEC_IPP_Interest__c', 1.2);
        r2.put('FEC_IPP_Accrued_Interest__c', -30000);
        r2.put('FEC_Close_Fee__c', 1);
        r2.put('FEC_Close_Fee_Amount__c', -200000);
        r2.put('FEC_Plan_Payment_Amount__c', -1000000);
        records.add(r2);
        return records;
    }

    /**
     * Trả về Card Payment Totals cho UI (loadCardPaymentTotals fallback).
     * Bốn giá trị đầu (fullPaymentAmount, loanBalance, fullPaymentWithoutIPP, fullIPPPaymentAmount) giữ từ nguồn;
     * bảy trường total được tính tổng từ danh sách records (getHardcodedCardPaymentRecordsForUI).
     */
    public static FEC_CardPaymentController.CardPaymentTotalsDTO getHardcodedCardPaymentTotalsForUI() {
        Map<String, String> helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Card_Payment__c.SObjectType);
        List<Map<String, Object>> records = getHardcodedCardPaymentRecordsForUI();
        Decimal totalCurrentBalance = 0;
        Decimal totalCloseFeeAmount = 0;
        Decimal totalPlanPaymentAmount = 0;
        Decimal totalAccruedInterest = 0;
        Decimal totalIPPAccruedInterest = 0;
        Decimal totalPerDiem = 0;
        Decimal totalDeferredInterest = 0;
        for (Map<String, Object> r : records) {
            totalCurrentBalance += toDecimal(r.get('FEC_Current_Balance__c'));
            totalCloseFeeAmount += toDecimal(r.get('FEC_Close_Fee_Amount__c'));
            totalPlanPaymentAmount += toDecimal(r.get('FEC_Plan_Payment_Amount__c'));
            totalAccruedInterest += toDecimal(r.get('FEC_Accrued_Interest__c'));
            totalIPPAccruedInterest += toDecimal(r.get('FEC_IPP_Accrued_Interest__c'));
            totalPerDiem += toDecimal(r.get('FEC_Per_Diem__c'));
            totalDeferredInterest += toDecimal(r.get('FEC_Deferred_Interest__c'));
        }
        FEC_CardPaymentController.CardPaymentTotalsDTO dto = new FEC_CardPaymentController.CardPaymentTotalsDTO();
        dto.helpTexts = helpTexts;
        dto.fullPaymentAmount = 55000000;
        dto.loanBalance = -45000000;
        dto.fullPaymentWithoutIPP = 50000000;
        dto.fullIPPPaymentAmount = 5000000;
        dto.totalCurrentBalance = totalCurrentBalance;
        dto.totalCloseFeeAmount = totalCloseFeeAmount;
        dto.totalPlanPaymentAmount = totalPlanPaymentAmount;
        dto.totalAccruedInterest = totalAccruedInterest;
        dto.totalIPPAccruedInterest = totalIPPAccruedInterest;
        dto.totalPerDiem = totalPerDiem;
        dto.totalDeferredInterest = totalDeferredInterest;
        return dto;
    }

    private static Decimal toDecimal(Object val) {
        if (val == null) { return 0; }
        if (val instanceof Decimal) { return (Decimal) val; }
        if (val instanceof Integer) { return Decimal.valueOf((Integer) val); }
        return 0;
    }

    // ==================== IPP ====================

    /** Giá trị mặc định cho interestRate khi Mock (fallback khi GetIPPDetails không gọi được / không có data). */
    public static Decimal getDefaultIPPInterestRateForMock() { return 1.5; }
    /** Giá trị mặc định cho ippTerm khi Mock. */
    public static Decimal getDefaultIPPTermForMock() { return 12; }

    /**
     * Trả về 20 IPP records mock đầy đủ field cho UI khi FEC_Call_Mock__c = true.
     */
    public static List<FEC_IPPController.IPPRecordDTO> getHardcodedIPPRecordsForUI() {
        List<FEC_IPPController.IPPRecordDTO> result = new List<FEC_IPPController.IPPRecordDTO>();

        result.add(buildMockIppRow(
            'mock-ipp-001', '001', '20003',
            Date.newInstance(2025, 5, 23), Date.newInstance(2025, 6, 23), Date.newInstance(2026, 5, 23),
            13890278, 1666833, 1.65, 12, 3, 1
        ));
        result.add(buildMockIppRow(
            'mock-ipp-002', '002', '10001',
            Date.newInstance(2023, 12, 5), Date.newInstance(2024, 1, 5), Date.newInstance(2024, 12, 5),
            3291534, 394984, 1.45, 12, 12, 2
        ));
        result.add(buildMockIppRow(
            'mock-ipp-003', '003', '10009',
            Date.newInstance(2023, 12, 5), Date.newInstance(2024, 1, 5), Date.newInstance(2025, 6, 5),
            2907522, 348903, 1.55, 18, 15, 3
        ));
        result.add(buildMockIppRow(
            MOCK_IPP_DETAIL_RECORD_ID, '004', '60001',
            Date.newInstance(2022, 5, 31), Date.newInstance(2025, 6, 22), Date.newInstance(2026, 9, 22),
            2059768, 0, 1.50, 15, 8, 4
        ));

        for (Integer n = 5; n <= MOCK_IPP_UI_RECORD_COUNT; n++) {
            String mockId = 'mock-ipp-' + (n < 10 ? '0' + String.valueOf(n) : String.valueOf(n));
            String planNumber = String.valueOf(20000 + n * 101);
            String recordNo = (n < 10 ? '00' + String.valueOf(n) : String.valueOf(n));
            Integer monthsBack = n * 3;
            Date openDate = Date.today().addMonths(-monthsBack);
            Decimal ippTerm = pickMockIppTerm(n);
            Date firstDueDate = openDate.addMonths(1);
            Date matureDate = openDate.addMonths(ippTerm.intValue());
            Decimal ippBalance = 1500000 + (n * 487321);
            Decimal interestRate = 1.20 + (n * 0.08);
            Integer monthsElapsed = Math.max(1, openDate.monthsBetween(Date.today()));
            Decimal currentTerm = Math.min(ippTerm, Decimal.valueOf(monthsElapsed));
            Decimal currentBalance = resolveMockCurrentBalance(n, ippBalance);

            result.add(buildMockIppRow(
                mockId, recordNo, planNumber,
                openDate, firstDueDate, matureDate,
                ippBalance, currentBalance, interestRate, ippTerm, currentTerm, n
            ));
        }

        return result;
    }

    private static Decimal pickMockIppTerm(Integer rowIndex) {
        List<Decimal> terms = new List<Decimal>{ 6, 12, 18, 24 };
        return terms[Math.mod(rowIndex, terms.size())];
    }

    private static Decimal resolveMockCurrentBalance(Integer rowIndex, Decimal ippBalance) {
        if (rowIndex == 10) {
            return 0;
        }
        if (rowIndex == 16) {
            return -450000;
        }
        return (ippBalance * (0.08 + (Math.mod(rowIndex, 5) * 0.01))).setScale(0);
    }

    private static FEC_IPPController.IPPRecordDTO buildMockIppRow(
        String id,
        String recordNo,
        String planNumber,
        Date openDate,
        Date firstDueDate,
        Date matureDate,
        Decimal ippBalance,
        Decimal currentBalance,
        Decimal interestRate,
        Decimal ippTerm,
        Decimal currentTerm,
        Integer rowIndex
    ) {
        FEC_IPPController.IPPRecordDTO dto = new FEC_IPPController.IPPRecordDTO();
        dto.Id = id;
        dto.recordNo = recordNo;
        dto.planNumber = planNumber;
        dto.openDate = openDate;
        dto.firstDueDate = firstDueDate;
        dto.matureDate = matureDate;
        dto.ippBalance = ippBalance;
        dto.currentBalance = currentBalance;
        dto.interestRate = interestRate;
        dto.ippTerm = ippTerm;
        dto.currentTerm = currentTerm;

        Decimal termMonths = ippTerm != null && ippTerm > 0 ? ippTerm : getDefaultIPPTermForMock();
        dto.totalIPPPaymentAmount = (ippBalance * 0.85).setScale(0);
        dto.totalIPPMonthlyPrincipal = (ippBalance / termMonths).setScale(0);
        dto.totalIPPMonthlyInterest = (ippBalance * interestRate * 0.001).setScale(0);

        applyMockSalesInfo(dto, rowIndex);
        return dto;
    }

    private static void applyMockSalesInfo(FEC_IPPController.IPPRecordDTO dto, Integer rowIndex) {
        Integer idx = rowIndex == null ? 1 : rowIndex;
        String seq = idx < 10 ? '0' + String.valueOf(idx) : String.valueOf(idx);
        dto.ccCode = 'CC' + seq;
        dto.ccName = 'Consumer Credit Center ' + seq;
        dto.dsaCode = 'DSA' + seq;
        dto.dsaName = 'Direct Sales Agent ' + seq;
        dto.tsaCode = 'TSA' + seq;
        dto.tsaName = 'Third Party Agent ' + seq;
        dto.applicationId = 'APP-MOCK-2024-' + seq;
        dto.originationChannel = Math.mod(idx, 2) == 0 ? 'BRANCH' : 'ONLINE';
        dto.disbursementChannel = Math.mod(idx, 3) == 0 ? 'ATM' : 'TRANSFER';
    }

    /**
     * Trả về dữ liệu IPP Schedule hardcode cho UI (getIPPScheduleData fallback).
     * FEC_IPPScheduleController gọi khi ippId bắt đầu bằng mock-ipp- (mock mode).
     * @param ippRecord IPP record từ DB (có thể null khi mở IPP mock – dùng placeholder cho ippRecord)
     * @return Map với keys: schedules, totalPaymentAmount, totalMonthlyPrincipal, totalMonthlyInterest, ippRecord
     */
    public static Map<String, Object> getHardcodedIPPScheduleDataForUI(FEC_IPP__c ippRecord) {
        List<Map<String, Object>> scheduleRows = new List<Map<String, Object>>();
        // 2 dòng giống fec_IPPDetailPage (mock): dòng 1 Payment Amount âm để test highlight đỏ
        scheduleRows.add(newScheduleRow(1, 50000000, -5000000, 4000000, 100000));
        scheduleRows.add(newScheduleRow(2, 46000000, 5000000, 4000000, -92000));

        Decimal totalPaymentAmount = 0;
        Decimal totalMonthlyPrincipal = 0;
        Decimal totalMonthlyInterest = 0;
        for (Map<String, Object> row : scheduleRows) {
            totalPaymentAmount += toDecimal(row.get('FEC_IPP_Payment_Amount__c'));
            totalMonthlyPrincipal += toDecimal(row.get('FEC_IPP_Monthly_Principal__c'));
            totalMonthlyInterest += toDecimal(row.get('FEC_IPP_Monthly_Interest__c'));
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('schedules', scheduleRows);
        result.put('totalPaymentAmount', totalPaymentAmount);
        result.put('totalMonthlyPrincipal', totalMonthlyPrincipal);
        result.put('totalMonthlyInterest', totalMonthlyInterest);
        result.put('ippRecord', ippRecord != null ? ippRecordToMap(ippRecord) : buildPlaceholderIppRecordForSchedule(scheduleRows));
        return result;
    }

    private static Map<String, Object> ippRecordToMap(FEC_IPP__c ipp) {
        Map<String, Object> rec = new Map<String, Object>();
        if (ipp == null) { return rec; }
        rec.put('FEC_Application_ID__c', ipp.FEC_Application_ID__c);
        rec.put('FEC_CC_Code__c', ipp.FEC_CC_Code__c);
        rec.put('FEC_CC_Name__c', ipp.FEC_CC_Name__c);
        rec.put('FEC_DSA_Code__c', ipp.FEC_DSA_Code__c);
        rec.put('FEC_DSA_Name__c', ipp.FEC_DSA_Name__c);
        rec.put('FEC_TSA_Code__c', ipp.FEC_TSA_Code__c);
        rec.put('FEC_TSA_Name__c', ipp.FEC_TSA_Name__c);
        rec.put('FEC_Origination_Channel__c', ipp.FEC_Origination_Channel__c);
        rec.put('FEC_Disbursement_Channel__c', ipp.FEC_Disbursement_Channel__c);
        rec.put('FEC_Total_IPP_Payment_Amount__c', ipp.FEC_Total_IPP_Payment_Amount__c);
        rec.put('FEC_Total_IPP_Monthly_Principal__c', ipp.FEC_Total_IPP_Monthly_Principal__c);
        rec.put('FEC_Total_IPP_Monthly_Interest__c', ipp.FEC_Total_IPP_Monthly_Interest__c);
        return rec;
    }

    private static Map<String, Object> newScheduleRow(Integer paymentNo, Decimal openingBalance, Decimal paymentAmount, Decimal monthlyPrincipal, Decimal monthlyInterest) {
        Map<String, Object> row = new Map<String, Object>();
        row.put('FEC_IPP_Payment_No__c', paymentNo);
        row.put('FEC_IPP_Opening_Balance__c', openingBalance);
        row.put('FEC_IPP_Payment_Amount__c', paymentAmount);
        row.put('FEC_IPP_Monthly_Principal__c', monthlyPrincipal);
        row.put('FEC_IPP_Monthly_Interest__c', monthlyInterest);
        return row;
    }

    private static Map<String, Object> buildPlaceholderIppRecordForSchedule(List<Map<String, Object>> scheduleRows) {
        Decimal totalPaymentAmount = 0;
        Decimal totalMonthlyPrincipal = 0;
        Decimal totalMonthlyInterest = 0;
        if (scheduleRows != null) {
            for (Map<String, Object> row : scheduleRows) {
                totalPaymentAmount += toDecimal(row.get('FEC_IPP_Payment_Amount__c'));
                totalMonthlyPrincipal += toDecimal(row.get('FEC_IPP_Monthly_Principal__c'));
                totalMonthlyInterest += toDecimal(row.get('FEC_IPP_Monthly_Interest__c'));
            }
        }
        Map<String, Object> rec = new Map<String, Object>();
        rec.put('FEC_Application_ID__c', 'APP-DEMO-2024001');
        rec.put('FEC_CC_Code__c', 'CC001');
        rec.put('FEC_CC_Name__c', 'Consumer Credit Center');
        rec.put('FEC_DSA_Code__c', 'DSA001');
        rec.put('FEC_DSA_Name__c', 'Direct Sales Agent 001');
        rec.put('FEC_TSA_Code__c', 'TSA001');
        rec.put('FEC_TSA_Name__c', 'Third Party Agent 001');
        rec.put('FEC_Origination_Channel__c', 'BRANCH');
        rec.put('FEC_Disbursement_Channel__c', 'ATM');
        rec.put('FEC_Total_IPP_Payment_Amount__c', totalPaymentAmount);
        rec.put('FEC_Total_IPP_Monthly_Principal__c', totalMonthlyPrincipal);
        rec.put('FEC_Total_IPP_Monthly_Interest__c', totalMonthlyInterest);
        return rec;
    }
}
