public with sharing class FEC_CardInfoController {

    /* =====================================================
     * DTO
     * ===================================================== */
    public class CardInfoDTO {
        @AuraEnabled public List<CardDeliveryDTO> cardDeliveries;
        @AuraEnabled public List<OtherCardDTO> otherCards;
        @AuraEnabled public Map<String, String> helpTexts;
    }

    public class CardDeliveryDTO {
        @AuraEnabled public String cardNumber;
        @AuraEnabled public Date issueDate;
        @AuraEnabled public String typeOfIssue;
        @AuraEnabled public String deliveryStatus;
        @AuraEnabled public Date deliveryDate;
        @AuraEnabled public String recipient;
        @AuraEnabled public String trackingNumber;
        @AuraEnabled public String deliveryNote;
    }

    public class OtherCardDTO {
        @AuraEnabled public String cardholder;
        @AuraEnabled public String cardNumber;
        @AuraEnabled public String plasticId;
        @AuraEnabled public Date expiryDate;
        @AuraEnabled public String embossingName;
        @AuraEnabled public Date cardActivationDate;
        @AuraEnabled public Date issueDate;
        @AuraEnabled public String blockCode;
        @AuraEnabled public String gender;
    }

    /* =====================================================
     * CÁC METHOD CHÍNH
     * ===================================================== */
    
    /**
     * Tải thông tin Card (Card Delivery + Other Cards) - Method chính
     * Luồng: Query database trước, chỉ call API nếu không có dữ liệu (và chỉ 1 lần duy nhất)
     * Sau khi có dữ liệu trong database, sẽ không gọi API nữa
     * @param caseId - ID của Case record
     * @param forceRefresh - Nếu true, sẽ xóa dữ liệu cũ và force gọi API lại
     * @return CardInfoDTO chứa card deliveries và other cards
     */
    @AuraEnabled(cacheable=false)
    public static CardInfoDTO loadCardInfo(Id caseId, Boolean forceRefresh) {
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
        
        // Tìm Customer History từ Account Number nếu customerHistoryId null (chỉ tìm 1 lần ở đầu)
        if (customerHistoryId == null && String.isNotBlank(accountNumber)) {
            System.debug('### Customer History ID is null, trying to find by Account Number: ' + accountNumber);
            List<FEC_Customer_History__c> histories = [
                SELECT Id FROM FEC_Customer_History__c 
                WHERE FEC_Account_Number__c = :accountNumber 
                LIMIT 1
            ];
            if (!histories.isEmpty()) {
                customerHistoryId = histories[0].Id;
                System.debug('### Found Customer History by Account Number: ' + customerHistoryId);
            }
        }

        /* =====================================================
         * BƯỚC 1: QUERY DATABASE TRƯỚC
         * ===================================================== */
        CardInfoDTO dto = new CardInfoDTO();
        dto.cardDeliveries = new List<CardDeliveryDTO>();
        dto.otherCards = new List<OtherCardDTO>();

        /* ===== TẢI CARD DELIVERIES TỪ DATABASE ===== */
        try {
            if (customerHistoryId != null) {
                dto.cardDeliveries = mapCardDeliveriesToDTO([
                    SELECT FEC_Card_Number__c, FEC_Issue_Date__c, FEC_Type_of_Issue__c,
                           FEC_Delivery_Status__c, FEC_Delivery_Date__c, FEC_Recipient__c,
                           FEC_Tracking_Number__c, FEC_Delivery_Note__c
                    FROM FEC_Card_Delivery__c
                    WHERE FEC_Customer_History__c = :customerHistoryId
                    ORDER BY FEC_Issue_Date__c DESC
                ]);
            } else {
                System.debug('### Customer History ID is null, cannot query Card Delivery');
            }
        } catch (Exception e) {
            System.debug('### Load Card Deliveries FAILED: ' + e.getMessage());
        }

        /* ===== TẢI OTHER CARDS TỪ DATABASE ===== */
        try {
            if (customerHistoryId != null) {
                dto.otherCards = mapOtherCardsToDTO([
                    SELECT FEC_Cardholder__c, FEC_Card_Number__c, FEC_Plastic_ID__c,
                           FEC_Expiry_Date__c, FEC_Embossing_Name__c, FEC_Card_Activation_Date__c,
                           FEC_Issue_Date__c, FEC_Block_Code__c, FEC_Gender__c
                    FROM FEC_Other_Card__c
                    WHERE FEC_Customer_History__c = :customerHistoryId
                    ORDER BY FEC_Expiry_Date__c DESC
                ]);
            } else {
                System.debug('### Customer History ID is null, cannot query Other Cards');
            }
        } catch (Exception e) {
            System.debug('### Load Other Cards FAILED: ' + e.getMessage());
        }

        /* =====================================================
         * BƯỚC 2: KIỂM TRA XEM CÓ DỮ LIỆU KHÔNG
         * Kiểm tra từng loại dữ liệu riêng biệt để gọi API độc lập
         * ===================================================== */
        Boolean hasCardDeliveryData = dto.cardDeliveries != null && dto.cardDeliveries.size() > 0;
        Boolean hasOtherCardData = dto.otherCards != null && dto.otherCards.size() > 0;

        // Nếu đã có cả 2 loại dữ liệu thì return luôn (không gọi API nữa)
        if (hasCardDeliveryData && hasOtherCardData) {
            System.debug('### Found all data in database, returning without API call');
            return dto;
        }

        /* =====================================================
         * BƯỚC 3: GỌI API CHO TỪNG LOẠI DỮ LIỆU CÒN THIẾU (CHỈ 1 LẦN DUY NHẤT)
         * ===================================================== */
        if (String.isBlank(accountNumber)) {
            System.debug('### Account Number is blank, cannot call API');
            return dto;
        }

        /* ===== 1. GetStatus API - Card Delivery (chỉ gọi nếu chưa có dữ liệu) ===== */
        if (!hasCardDeliveryData && customerHistoryId != null) {
            System.debug('### No Card Delivery data found, calling GetStatus API...');
            System.debug('### Account Number: ' + accountNumber);
            System.debug('### Customer History ID: ' + customerHistoryId);
            try {
                FEC_GetStatus.CardDeliveryInfo cardDeliveryInfo = 
                    FEC_GetStatus.getDeliveryStatus(accountNumber);
                System.debug('### GetStatus API Response Code: ' + (cardDeliveryInfo != null ? cardDeliveryInfo.responseCode : 'NULL'));
                if (cardDeliveryInfo != null && cardDeliveryInfo.responseCode == '1') {
                    System.debug('### Saving Card Delivery to database...');
                    saveCardDeliveryToDatabase(cardDeliveryInfo, caseId, customerHistoryId);
                    System.debug('### Card Delivery saved successfully');
                } else {
                    System.debug('### GetStatus API returned invalid response or responseCode != 1');
                }
            } catch (Exception e) {
                System.debug('### GetStatus API FAILED: ' + e.getMessage());
                System.debug('### Stack trace: ' + e.getStackTraceString());
            }
        } else if (!hasCardDeliveryData && customerHistoryId == null) {
            System.debug('### Cannot call GetStatus API: Customer History ID is null');
        }

        /* ===== 2. GetCardSecInfo API - Other Cards (chỉ gọi nếu chưa có dữ liệu) ===== */
        if (!hasOtherCardData && customerHistoryId != null) {
            System.debug('### No Other Card data found, calling GetCardSecInfo API...');
            System.debug('### Account Number: ' + accountNumber);
            System.debug('### Customer History ID: ' + customerHistoryId);
            try {
                String transId = UUID.randomUUID().toString();
                String requestorId = FEC_ConstantCommon.REQUESTOR_CRM;
                String dateTimeStr = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
                
                FEC_GetCardSecInfo.ResponseWrapper response = 
                    FEC_GetCardSecInfo.callGetCardSecInfo(transId, requestorId, dateTimeStr, accountNumber);
                String responseCodeStr = (response != null && response.Sys != null) ? String.valueOf(response.Sys.Code) : 'NULL';
                System.debug('### GetCardSecInfo API Response Code: ' + responseCodeStr);
                System.debug('### Supplementary Cards count: ' + (response != null && response.CardSecInfo != null && response.CardSecInfo.SupplementaryCards != null ? response.CardSecInfo.SupplementaryCards.size() : 0));
                if (response != null && response.Sys != null && response.Sys.Code == 1 && 
                    response.CardSecInfo != null && response.CardSecInfo.SupplementaryCards != null &&
                    !response.CardSecInfo.SupplementaryCards.isEmpty()) {
                    System.debug('### Saving Supplementary Cards to database...');
                    saveSupplementaryCardsToDatabase(
                        response.CardSecInfo.SupplementaryCards, 
                        accountNumber, 
                        customerHistoryId
                    );
                    System.debug('### Supplementary Cards saved successfully');
                } else {
                    System.debug('### GetCardSecInfo API returned no data or failed');
                    if (response == null) {
                        System.debug('### response is NULL');
                    } else if (response.Sys == null) {
                        System.debug('### response.Sys is NULL');
                    } else if (response.Sys.Code != 1) {
                        System.debug('### response.Sys.Code != 1, actual: ' + response.Sys.Code);
                    } else if (response.CardSecInfo == null) {
                        System.debug('### response.CardSecInfo is NULL');
                    } else if (response.CardSecInfo.SupplementaryCards == null || response.CardSecInfo.SupplementaryCards.isEmpty()) {
                        System.debug('### SupplementaryCards is null or empty');
                    }
                }
            } catch (Exception e) {
                System.debug('### GetCardSecInfo API FAILED: ' + e.getMessage());
                System.debug('### Stack trace: ' + e.getStackTraceString());
            }
        } else if (!hasOtherCardData && customerHistoryId == null) {
            System.debug('### Cannot call GetCardSecInfo API: Customer History ID is null');
        }

        /* =====================================================
         * BƯỚC 4: QUERY LẠI DATABASE SAU KHI CALL API
         * ===================================================== */
        /* ===== TẢI LẠI CARD DELIVERIES ===== */
        try {
            if (customerHistoryId != null) {
                List<FEC_Card_Delivery__c> cardDeliveryRecords = [
                    SELECT FEC_Card_Number__c, FEC_Issue_Date__c, FEC_Type_of_Issue__c,
                           FEC_Delivery_Status__c, FEC_Delivery_Date__c, FEC_Recipient__c,
                           FEC_Tracking_Number__c, FEC_Delivery_Note__c
                    FROM FEC_Card_Delivery__c
                    WHERE FEC_Customer_History__c = :customerHistoryId
                    ORDER BY FEC_Issue_Date__c DESC
                ];
                System.debug('### Reload Card Deliveries: Found ' + cardDeliveryRecords.size() + ' records');
                dto.cardDeliveries = mapCardDeliveriesToDTO(cardDeliveryRecords);
            } else {
                System.debug('### Customer History ID is null, cannot reload Card Delivery');
            }
        } catch (Exception e) {
            System.debug('### Reload Card Deliveries FAILED: ' + e.getMessage());
            System.debug('### Stack trace: ' + e.getStackTraceString());
        }

        /* ===== TẢI LẠI OTHER CARDS ===== */
        try {
            if (customerHistoryId != null) {
                List<FEC_Other_Card__c> otherCardRecords = [
                    SELECT FEC_Cardholder__c, FEC_Card_Number__c, FEC_Plastic_ID__c,
                           FEC_Expiry_Date__c, FEC_Embossing_Name__c, FEC_Card_Activation_Date__c,
                           FEC_Issue_Date__c, FEC_Block_Code__c, FEC_Gender__c
                    FROM FEC_Other_Card__c
                    WHERE FEC_Customer_History__c = :customerHistoryId
                    ORDER BY FEC_Expiry_Date__c DESC
                ];
                System.debug('### Reload Other Cards: Found ' + otherCardRecords.size() + ' records');
                dto.otherCards = mapOtherCardsToDTO(otherCardRecords);
            } else {
                System.debug('### Customer History ID is null, cannot reload Other Cards');
            }
        } catch (Exception e) {
            System.debug('### Reload Other Cards FAILED: ' + e.getMessage());
            System.debug('### Stack trace: ' + e.getStackTraceString());
        }

        return dto;
    }

    /* =====================================================
     * CÁC METHOD HỖ TRỢ
     * ===================================================== */
    
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
     * Lưu dữ liệu Card Delivery vào database (chỉ INSERT, không UPDATE)
     * Method này chỉ được gọi 1 lần duy nhất khi chưa có dữ liệu trong database
     * @param info - Thông tin Card Delivery từ API
     * @param caseId - ID của Case record
     * @param customerHistoryId - ID của Customer History record (required field)
     */
    private static void saveCardDeliveryToDatabase(FEC_GetStatus.CardDeliveryInfo info, String caseId, Id customerHistoryId) {
        if (String.isBlank(info.cardNumber)) {
            System.debug('### Card Number is blank, cannot save Card Delivery');
            return;
        }
        
        if (customerHistoryId == null) {
            System.debug('### Customer History ID is null, cannot save Card Delivery');
            return;
        }

        try {
            String maskedCardNumber = FEC_CommonUltils.maskCardNumber(info.cardNumber);
            System.debug('### Masked Card Number: ' + maskedCardNumber);
            
            // Kiểm tra xem đã có record chưa (chỉ INSERT nếu chưa có)
            List<FEC_Card_Delivery__c> existing = [
                SELECT Id FROM FEC_Card_Delivery__c 
                WHERE FEC_Card_Number__c = :maskedCardNumber AND FEC_Customer_History__c = :customerHistoryId
                LIMIT 1
            ];

            // Nếu đã có record → không làm gì (không update)
            if (!existing.isEmpty()) {
                System.debug('### Card Delivery record already exists, skipping insert');
                return;
            }

            // Chỉ INSERT record mới
            FEC_Card_Delivery__c record = new FEC_Card_Delivery__c();
            record.FEC_Card_Number__c = maskedCardNumber;
            record.FEC_Case__c = caseId; // Vẫn giữ để reference, nhưng query theo Customer History
            record.FEC_Customer_History__c = customerHistoryId; // Required field - dùng để query
            record.FEC_Tracking_Number__c = info.trackingNo;
            record.FEC_Delivery_Status__c = info.status;
            record.FEC_Delivery_Note__c = info.deliveryNotes;
            record.FEC_Recipient__c = info.receiverName;
            
            if (String.isNotBlank(info.issueDate)) {
                try {
                    record.FEC_Issue_Date__c = Date.valueOf(info.issueDate);
                } catch (Exception e) {
                    System.debug('### Invalid issueDate format: ' + info.issueDate);
                }
            }
            
            System.debug('### Inserting Card Delivery record...');
            insert record;
            System.debug('### Card Delivery record inserted successfully, ID: ' + record.Id);
        } catch (Exception e) {
            System.debug('### Save Card Delivery FAILED: ' + e.getMessage());
            System.debug('### Stack trace: ' + e.getStackTraceString());
        }
    }

    /**
     * Lưu dữ liệu Supplementary Cards từ API vào FEC_Other_Card__c (chỉ INSERT, không UPDATE)
     * Method này chỉ được gọi 1 lần duy nhất khi chưa có dữ liệu trong database
     * @param suppList - Danh sách SupplementaryCard từ API
     * @param accountNumber - Số tài khoản
     * @param customerHistoryId - ID Customer History từ Case (ưu tiên dùng ID này)
     */
    private static void saveSupplementaryCardsToDatabase(List<FEC_GetCardSecInfo.SupplementaryCard> suppList, String accountNumber, Id customerHistoryId) {
        System.debug('### saveSupplementaryCardsToDatabase called with ' + suppList.size() + ' cards');
        
        if (customerHistoryId == null) {
            System.debug('### ERROR: Customer History ID is null, cannot save Supplementary Cards');
            throw new AuraHandledException('Customer History ID is required to save Supplementary Cards');
        }
        
        System.debug('### Using Customer History ID: ' + customerHistoryId);
        
        // Query các records cũ để kiểm tra (chỉ INSERT nếu chưa có)
        List<FEC_Other_Card__c> existingRecords = [
            SELECT Id, FEC_Card_Number__c, FEC_Customer_History__c
            FROM FEC_Other_Card__c 
            WHERE FEC_Customer_History__c = :customerHistoryId
        ];
        
        System.debug('### Found ' + existingRecords.size() + ' existing Other Card records');
        
        // Tạo Set để kiểm tra nhanh CardNumber đã tồn tại chưa
        Set<String> existingCardNumbers = new Set<String>();
        for (FEC_Other_Card__c existing : existingRecords) {
            if (String.isNotBlank(existing.FEC_Card_Number__c)) {
                existingCardNumbers.add(existing.FEC_Card_Number__c);
            }
        }
        
        List<FEC_Other_Card__c> recordsToInsert = new List<FEC_Other_Card__c>();

        for (FEC_GetCardSecInfo.SupplementaryCard item: suppList) {
            // Validate: Phải có số thẻ mới lưu
            if (String.isBlank(item.CardNumber)) {
                System.debug('### Skipping card with blank CardNumber');
                continue;
            }

            // Nếu CardNumber đã tồn tại → bỏ qua (không insert, không update)
            if (existingCardNumbers.contains(item.CardNumber)) {
                System.debug('### Other Card already exists: ' + item.CardNumber + ', skipping insert');
                continue;
            }
            
            // Chỉ INSERT record mới (CardNumber chưa tồn tại)
            FEC_Other_Card__c record = new FEC_Other_Card__c();
            record.FEC_Customer_History__c = customerHistoryId;
            record.FEC_Card_Number__c = item.CardNumber;
            record.FEC_Cardholder__c = item.CardholderName;
            record.FEC_Plastic_ID__c = item.PlasticIndicator;
            record.FEC_Embossing_Name__c = item.EmbossingName;
            record.FEC_Block_Code__c = item.BlockCode;
            record.FEC_Gender__c = item.Gender;
            
            // Ánh xạ các trường Date (CardIssueDate và CardActivationDate giờ là Date type, ExpiryDate vẫn là String)
            record.FEC_Expiry_Date__c = FEC_CommonUltils.parseDate(item.ExpiryDate);
            record.FEC_Card_Activation_Date__c = item.CardActivationDate; // Đã là Date type
            record.FEC_Issue_Date__c = item.CardIssueDate; // Đã là Date type
            
            recordsToInsert.add(record);
            System.debug('### Creating new Other Card: ' + item.CardNumber);
        }
        
        System.debug('### Total records to insert: ' + recordsToInsert.size());
        
        if (!recordsToInsert.isEmpty()) {
            try {
                System.debug('### Inserting ' + recordsToInsert.size() + ' Other Card records...');
                insert recordsToInsert;
                System.debug('### Other Card records inserted successfully');
            } catch (Exception e) {
                System.debug('### Save Supplementary Cards FAILED: ' + e.getMessage());
                System.debug('### Stack trace: ' + e.getStackTraceString());
                throw new AuraHandledException('Lỗi lưu dữ liệu: ' + e.getMessage());
            }
        } else {
            System.debug('### No new Other Card records to insert');
        }
    }
    
    /* =====================================================
     * CÁC METHOD ÁNH XẠ - CHUYỂN ĐỔI DTO
     * ===================================================== */

    /**
     * Ánh xạ Card Delivery records sang DTO
     * @param records - Danh sách FEC_Card_Delivery__c records
     * @return Danh sách CardDeliveryDTO
     */
    private static List<CardDeliveryDTO> mapCardDeliveriesToDTO(List<FEC_Card_Delivery__c> records) {
        List<CardDeliveryDTO> dtoList = new List<CardDeliveryDTO>();
        for (FEC_Card_Delivery__c rec : records) {
            CardDeliveryDTO dto = new CardDeliveryDTO();
            dto.cardNumber = rec.FEC_Card_Number__c;
            dto.issueDate = rec.FEC_Issue_Date__c;
            dto.typeOfIssue = rec.FEC_Type_of_Issue__c;
            dto.deliveryStatus = rec.FEC_Delivery_Status__c;
            dto.deliveryDate = rec.FEC_Delivery_Date__c;
            dto.recipient = rec.FEC_Recipient__c;
            dto.trackingNumber = rec.FEC_Tracking_Number__c;
            dto.deliveryNote = rec.FEC_Delivery_Note__c;
            dtoList.add(dto);
        }
        return dtoList;
    }

    /**
     * Ánh xạ Other Card records sang DTO
     * @param records - Danh sách FEC_Other_Card__c records
     * @return Danh sách OtherCardDTO
     */
    private static List<OtherCardDTO> mapOtherCardsToDTO(List<FEC_Other_Card__c> records) {
        List<OtherCardDTO> dtoList = new List<OtherCardDTO>();
        for (FEC_Other_Card__c rec : records) {
            OtherCardDTO dto = new OtherCardDTO();
            dto.cardholder = rec.FEC_Cardholder__c;
            dto.cardNumber = rec.FEC_Card_Number__c;
            dto.plasticId = rec.FEC_Plastic_ID__c;
            dto.expiryDate = rec.FEC_Expiry_Date__c;
            dto.embossingName = rec.FEC_Embossing_Name__c;
            dto.cardActivationDate = rec.FEC_Card_Activation_Date__c;
            dto.issueDate = rec.FEC_Issue_Date__c;
            dto.blockCode = rec.FEC_Block_Code__c;
            dto.gender = rec.FEC_Gender__c;
            dtoList.add(dto);
        }
        return dtoList;
    }

}