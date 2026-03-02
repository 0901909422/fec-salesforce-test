/**
 * Mock data chung cho Card Info, Card Payment và IPP.
 * Dùng khi FEC_API_Setting__c.FEC_Call_Mock__c = true (dev/SIT).
 * Controller gọi khi API không có data hoặc lỗi.
 */
public with sharing class FEC_MockData {

    /** Id giả cho IPP mock record - cùng giá trị với FEC_IPPController.MOCK_IPP_RECORD_ID để tương thích. */
    private static final String MOCK_IPP_RECORD_ID = 'mock-PLAN-DEMO-001';

    // ==================== CARD INFO (Card Delivery + Other Cards) ====================

    /**
     * Trả về dữ liệu hardcode Card Info (Card Delivery + Other Cards).
     * FEC_CardInfoController gọi khi Mock bật và API không có data/lỗi.
     */
    public static FEC_CardInfoController.CardInfoDTO getHardcodedCardInfo() {
        FEC_CardInfoController.CardInfoDTO dto = new FEC_CardInfoController.CardInfoDTO();
        dto.cardDeliveries = new List<FEC_CardInfoController.CardDeliveryDTO>();
        dto.otherCards = new List<FEC_CardInfoController.OtherCardDTO>();

        // Card Delivery - nhiều bản ghi mẫu
        dto.cardDeliveries.add(newCardDelivery(
            '034204******022', Date.valueOf('2026-01-10'), 'New Card', 'Hoàn tất',
            Date.valueOf('2026-01-12'), 'Nguyen Duc Minh', '1000031234567', 'Đã vận chuyển đến nơi'));
        dto.cardDeliveries.add(newCardDelivery(
            '411111******1111', Date.valueOf('2025-01-15'), 'New Card', 'Delivered',
            Date.valueOf('2025-01-20'), 'Nguyen Van A', 'VN123456789', 'Giao thành công'));
        dto.cardDeliveries.add(newCardDelivery(
            '550000******0001', Date.valueOf('2024-11-10'), 'Replacement', 'In Transit',
            null, 'Tran Thi B', 'VN987654321', 'Đang vận chuyển'));
        dto.cardDeliveries.add(newCardDelivery(
            '378282******0012', Date.valueOf('2024-09-05'), 'New Card', 'Delivered',
            Date.valueOf('2024-09-12'), 'Le Van C', 'VN555666777', 'Đã ký nhận'));

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
     */
    public static List<Map<String, Object>> getHardcodedCardPaymentRecordsForUI() {
        List<Map<String, Object>> records = new List<Map<String, Object>>();
        Map<String, Object> r = new Map<String, Object>();
        r.put('FEC_Rec__c', '1');
        r.put('FEC_REF_Number__c', 'REF-DEMO-001');
        r.put('FEC_Current_Balance__c', 45000000);
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
        return records;
    }

    /**
     * Trả về Card Payment Totals hardcode cho UI (loadCardPaymentTotals fallback).
     * Toàn bộ giá trị hardcode nằm trong class mock; controller chỉ build DTO từ tham số.
     */
    public static FEC_CardPaymentController.CardPaymentTotalsDTO getHardcodedCardPaymentTotalsForUI() {
        Map<String, String> helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Card_Payment__c.SObjectType);
        List<Decimal> values = new List<Decimal>{
            55000000, 45000000, 50000000, 5000000, 45000000,
            900000, 5000000, 675000, 67500, 22500, 0
        };
        return FEC_CardPaymentController.createCardPaymentTotalsFromValues(helpTexts, values);
    }

    // ==================== IPP ====================

    /** Giá trị mặc định cho interestRate khi Mock (fallback khi GetIPPDetails không gọi được / không có data). */
    public static Decimal getDefaultIPPInterestRateForMock() { return 1.5; }
    /** Giá trị mặc định cho ippTerm khi Mock. */
    public static Decimal getDefaultIPPTermForMock() { return 12; }

    /**
     * Trả về danh sách IPP records hardcode cho UI (getIPPRecords fallback).
     * FEC_IPPController gọi khi Mock bật và API không có data/lỗi.
     */
    public static List<FEC_IPPController.IPPRecordDTO> getHardcodedIPPRecordsForUI() {
        List<FEC_IPPController.IPPRecordDTO> result = new List<FEC_IPPController.IPPRecordDTO>();
        FEC_IPPController.IPPRecordDTO dto = new FEC_IPPController.IPPRecordDTO();
        dto.Id = MOCK_IPP_RECORD_ID;
        dto.recordNo = '1';
        dto.planNumber = 'IPP001';
        dto.openDate = Date.today().addMonths(-2);
        dto.firstDueDate = Date.today().addMonths(-1);
        dto.matureDate = Date.today().addMonths(10);
        dto.ippBalance = 50000000;
        dto.currentBalance = 45000000;
        dto.interestRate = 1.5;
        dto.ippTerm = 12;
        dto.currentTerm = 2;
        dto.totalIPPPaymentAmount = 55000000;
        dto.totalIPPMonthlyPrincipal = 4000000;
        dto.totalIPPMonthlyInterest = 75000;
        dto.ccCode = 'CC001';
        dto.ccName = 'Consumer Credit Center';
        dto.dsaCode = 'DSA001';
        dto.dsaName = 'Direct Sales Agent 001';
        dto.tsaCode = 'TSA001';
        dto.tsaName = 'Third Party Agent 001';
        dto.applicationId = 'APP-DEMO-2024001';
        dto.originationChannel = 'BRANCH';
        dto.disbursementChannel = 'ATM';
        result.add(dto);
        return result;
    }

    /**
     * Trả về dữ liệu IPP Schedule hardcode cho UI (getIPPScheduleData fallback).
     * FEC_IPPScheduleController gọi khi Mock bật và API không có data/lỗi, hoặc khi ippId là MOCK_IPP_RECORD_ID.
     * @param ippRecord IPP record từ DB (có thể null khi mở IPP mock – dùng placeholder cho ippRecord)
     * @return Map với keys: schedules, totalPaymentAmount, totalMonthlyPrincipal, totalMonthlyInterest, ippRecord
     */
    public static Map<String, Object> getHardcodedIPPScheduleDataForUI(FEC_IPP__c ippRecord) {
        List<Map<String, Object>> scheduleRows = new List<Map<String, Object>>();
        scheduleRows.add(newScheduleRow(1, 50000000, 4500000, 4000000, 75000));
        scheduleRows.add(newScheduleRow(2, 45500000, 4500000, 4000000, 75000));
        scheduleRows.add(newScheduleRow(3, 41000000, 4500000, 4000000, 75000));

        Decimal totalPaymentAmount = 13500000;
        Decimal totalMonthlyPrincipal = 12000000;
        Decimal totalMonthlyInterest = 225000;

        Map<String, Object> result = new Map<String, Object>();
        result.put('schedules', scheduleRows);
        result.put('totalPaymentAmount', totalPaymentAmount);
        result.put('totalMonthlyPrincipal', totalMonthlyPrincipal);
        result.put('totalMonthlyInterest', totalMonthlyInterest);
        result.put('ippRecord', ippRecord != null ? ippRecordToMap(ippRecord) : buildPlaceholderIppRecordForSchedule());
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

    private static Map<String, Object> buildPlaceholderIppRecordForSchedule() {
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
        rec.put('FEC_Total_IPP_Payment_Amount__c', 55000000);
        rec.put('FEC_Total_IPP_Monthly_Principal__c', 4000000);
        rec.put('FEC_Total_IPP_Monthly_Interest__c', 75000);
        return rec;
    }
}
