public with sharing class FEC_CardInfoController {

    /* =====================================================
     * DTO
     * ===================================================== */
    public class CardInfoDTO {
        @AuraEnabled public List<CardDeliveryDTO> cardDeliveries;
        @AuraEnabled public List<OtherCardDTO> otherCards;
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
     * @return CardInfoDTO chứa card deliveries và other cards
     */
    @AuraEnabled(cacheable=false)
    public static CardInfoDTO loadCardInfo(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
        }

        /* ===== TẢI CASE (cần cho cả luồng Mock và luồng thật) ===== */
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
            List<FEC_Customer_History__c> histories = [
                SELECT Id FROM FEC_Customer_History__c 
                WHERE FEC_Account_Number__c = :accountNumber 
                LIMIT 1
            ];
            if (!histories.isEmpty()) {
                customerHistoryId = histories[0].Id;
            }
        }

        /* =====================================================
         * BƯỚC 1: QUERY DATABASE TRƯỚC (chung cho cả Mock và không Mock)
         * Đã có data trong DB → return luôn, không gọi API (kể cả khi Mock bật)
         * ===================================================== */
        CardInfoDTO dto = new CardInfoDTO();
        dto.cardDeliveries = new List<CardDeliveryDTO>();
        dto.otherCards = new List<OtherCardDTO>();

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
            }
        } catch (Exception e) {
            System.debug('Load Card Deliveries error: ' + e.getMessage());
        }

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
            }
        } catch (Exception e) {
            System.debug('Load Other Cards error: ' + e.getMessage());
        }

        Boolean hasCardDeliveryData = dto.cardDeliveries != null && dto.cardDeliveries.size() > 0;
        Boolean hasOtherCardData = dto.otherCards != null && dto.otherCards.size() > 0;

        /* =====================================================
         * KHI BẬT MOCK: đã có data trong DB → return; chưa có thì gọi API, lưu DB rồi return
         * ===================================================== */
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting != null && apiSetting.FEC_Call_Mock__c == true) {
            if (hasCardDeliveryData && hasOtherCardData) {
                return dto;
            }
            try {
                if (String.isNotBlank(accountNumber) && customerHistoryId != null) {
                    FEC_GetStatus.CardDeliveryInfo getStatusInfo = FEC_GetStatus.getDeliveryStatus(accountNumber);
                    FEC_GetCardSecInfo.ResponseWrapper cardSecResponse = FEC_GetCardSecInfo.getCardSecInfo(accountNumber);
                    CardInfoDTO mockDto = buildCardInfoFromResponses(getStatusInfo, cardSecResponse);
                    if (mockDto != null) {
                        Boolean hasData = (mockDto.cardDeliveries != null && !mockDto.cardDeliveries.isEmpty())
                            || (mockDto.otherCards != null && !mockDto.otherCards.isEmpty());
                        if (hasData) {
                            if (!hasCardDeliveryData && getStatusInfo != null && getStatusInfo.responseCode == '1') {
                                FEC_Card_Delivery__c insertedCard = insertCardDeliveryFromGetStatus(getStatusInfo, caseId, customerHistoryId);
                                if (insertedCard != null && cardSecResponse != null && cardSecResponse.CardSecInfo != null && cardSecResponse.CardSecInfo.CardsDeliveries != null && !cardSecResponse.CardSecInfo.CardsDeliveries.isEmpty()) {
                                    Boolean needsUpdate = false;
                                    FEC_GetCardSecInfo.CardsDelivery matchedDelivery = null;
                                    for (FEC_GetCardSecInfo.CardsDelivery delivery : cardSecResponse.CardSecInfo.CardsDeliveries) {
                                        Boolean isMatch = String.isNotBlank(delivery.CardNumber) && compareCardNumbers(insertedCard.FEC_Card_Number__c, delivery.CardNumber);
                                        if (isMatch) { matchedDelivery = delivery; break; }
                                    }
                                    if (matchedDelivery == null && !cardSecResponse.CardSecInfo.CardsDeliveries.isEmpty()) {
                                        matchedDelivery = cardSecResponse.CardSecInfo.CardsDeliveries[0];
                                    }
                                    if (matchedDelivery != null) {
                                        if (String.isNotBlank(matchedDelivery.KindOfIssue)) { insertedCard.FEC_Type_of_Issue__c = matchedDelivery.KindOfIssue; needsUpdate = true; }
                                        if (String.isNotBlank(matchedDelivery.DeliveryDate)) {
                                            try { insertedCard.FEC_Delivery_Date__c = parseDeliveryDate(matchedDelivery.DeliveryDate); needsUpdate = true; } catch (Exception ex) { }
                                        }
                                    }
                                    if (needsUpdate) { update insertedCard; }
                                }
                            }
                            if (!hasOtherCardData && cardSecResponse != null && cardSecResponse.CardSecInfo != null && cardSecResponse.CardSecInfo.SupplementaryCards != null && !cardSecResponse.CardSecInfo.SupplementaryCards.isEmpty()) {
                                insertSupplementaryCards(cardSecResponse.CardSecInfo.SupplementaryCards, customerHistoryId);
                            }
                            return mockDto;
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('Mock GetStatus/GetCardSecInfo error: ' + e.getMessage());
            }
            return FEC_MockData.getHardcodedCardInfo();
        }

        /* =====================================================
         * BƯỚC 2: KIỂM TRA XEM CÓ DỮ LIỆU KHÔNG
         * Kiểm tra từng loại dữ liệu riêng biệt để gọi API độc lập
         * ===================================================== */

        /* =====================================================
         * BƯỚC 3: GỌI API CHO TỪNG LOẠI DỮ LIỆU CÒN THIẾU (CHỈ 1 LẦN DUY NHẤT)
         * Chỉ gọi API nếu chưa có dữ liệu, sau đó chỉ INSERT (không UPSERT)
         * ===================================================== */
        if (String.isBlank(accountNumber) || customerHistoryId == null) {
            return dto;
        }

        // Chỉ gọi API khi CHƯA CÓ dữ liệu (cả Card Delivery hoặc Other Cards)
        if (!hasCardDeliveryData || !hasOtherCardData) {
            try {
                FEC_GetCardSecInfo.ResponseWrapper response = 
                    FEC_GetCardSecInfo.getCardSecInfo(accountNumber);
                    
                if (response != null && response.Sys != null && response.Sys.Code == 1 && response.CardSecInfo != null) {
                    /* ===== Card Deliveries - CHỈ INSERT NẾU CHƯA CÓ ===== */
                    if (!hasCardDeliveryData) {
                        // Gọi GetStatus API để lấy thông tin cơ bản
                        try {
                            FEC_GetStatus.CardDeliveryInfo cardDeliveryInfo = 
                            FEC_GetStatus.getDeliveryStatus(accountNumber);
                            if (cardDeliveryInfo != null && cardDeliveryInfo.responseCode == '1') {
                                // INSERT Card Delivery từ GetStatus
                                FEC_Card_Delivery__c insertedCard = insertCardDeliveryFromGetStatus(
                                    cardDeliveryInfo, 
                                    caseId, 
                                    customerHistoryId
                                );
                                
                                // UPDATE Type of Issue và Delivery Date từ CardSecInfo
                                // Match theo cardNumber nếu có, nếu không thì lấy delivery đầu tiên
                                if (insertedCard != null && response.CardSecInfo.CardsDeliveries != null && !response.CardSecInfo.CardsDeliveries.isEmpty()) {
                                    Boolean needsUpdate = false;
                                    FEC_GetCardSecInfo.CardsDelivery matchedDelivery = null;
                                    
                                    // Tìm delivery matching với card number
                                    for (FEC_GetCardSecInfo.CardsDelivery delivery : response.CardSecInfo.CardsDeliveries) {
                                        Boolean isMatch = false;
                                        if (String.isNotBlank(delivery.CardNumber)) {
                                            isMatch = compareCardNumbers(insertedCard.FEC_Card_Number__c, delivery.CardNumber);
                                        }
                                        
                                        if (isMatch) {
                                            matchedDelivery = delivery;
                                            break;
                                        }
                                    }
                                    
                                    // Nếu không match được theo CardNumber, lấy delivery đầu tiên
                                    if (matchedDelivery == null && !response.CardSecInfo.CardsDeliveries.isEmpty()) {
                                        matchedDelivery = response.CardSecInfo.CardsDeliveries[0];
                                    }
                                    
                                    // Update fields từ matched delivery
                                    if (matchedDelivery != null) {
                                        if (String.isNotBlank(matchedDelivery.KindOfIssue)) {
                                            insertedCard.FEC_Type_of_Issue__c = matchedDelivery.KindOfIssue;
                                            needsUpdate = true;
                                        }
                                        if (String.isNotBlank(matchedDelivery.DeliveryDate)) {
                                            try {
                                                insertedCard.FEC_Delivery_Date__c = parseDeliveryDate(matchedDelivery.DeliveryDate);
                                                needsUpdate = true;
                                            } catch (Exception e) {
                                                System.debug('Parse delivery date error: ' + e.getMessage());
                                            }
                                        }
                                    }
                                    
                                    if (needsUpdate) {
                                        update insertedCard;
                                    }
                                }
                            }
                        } catch (Exception e) {
                            System.debug('GetStatus API error: ' + e.getMessage());
                        }
                    }
                    
                    /* ===== Other Cards - CHỈ INSERT NẾU CHƯA CÓ ===== */
                    if (!hasOtherCardData && response.CardSecInfo.SupplementaryCards != null && !response.CardSecInfo.SupplementaryCards.isEmpty()) {
                        insertSupplementaryCards(
                            response.CardSecInfo.SupplementaryCards, 
                            customerHistoryId
                        );
                    }
                }
            } catch (Exception e) {
                System.debug('CardSecInfo API error: ' + e.getMessage());
            }
        }

        /* =====================================================
         * BƯỚC 4: QUERY LẠI DATABASE SAU KHI CALL API ĐỂ LẤY DỮ LIỆU MỚI NHẤT
         * ===================================================== */
        /* ===== TẢI LẠI CARD DELIVERIES SAU KHI INSERT/UPDATE ===== */
        if (!hasCardDeliveryData && customerHistoryId != null) {
            try {
                List<FEC_Card_Delivery__c> cardDeliveryRecords = [
                    SELECT FEC_Card_Number__c, FEC_Issue_Date__c, FEC_Type_of_Issue__c,
                           FEC_Delivery_Status__c, FEC_Delivery_Date__c, FEC_Recipient__c,
                           FEC_Tracking_Number__c, FEC_Delivery_Note__c
                    FROM FEC_Card_Delivery__c
                    WHERE FEC_Customer_History__c = :customerHistoryId
                    ORDER BY FEC_Issue_Date__c DESC
                ];
                dto.cardDeliveries = mapCardDeliveriesToDTO(cardDeliveryRecords);
            } catch (Exception e) {
                System.debug('Reload Card Deliveries error: ' + e.getMessage());
            }
        }

        /* ===== TẢI LẠI OTHER CARDS SAU KHI INSERT ===== */
        if (!hasOtherCardData && customerHistoryId != null) {
            try {
                List<FEC_Other_Card__c> otherCardRecords = [
                    SELECT FEC_Cardholder__c, FEC_Card_Number__c, FEC_Plastic_ID__c,
                           FEC_Expiry_Date__c, FEC_Embossing_Name__c, FEC_Card_Activation_Date__c,
                           FEC_Issue_Date__c, FEC_Block_Code__c, FEC_Gender__c
                    FROM FEC_Other_Card__c
                    WHERE FEC_Customer_History__c = :customerHistoryId
                    ORDER BY FEC_Expiry_Date__c DESC
                ];
                dto.otherCards = mapOtherCardsToDTO(otherCardRecords);
            } catch (Exception e) {
                System.debug('Reload Other Cards error: ' + e.getMessage());
            }
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
            List<FEC_Customer_History__c> histories = [
                SELECT FEC_Account_Number__c
                FROM FEC_Customer_History__c
                WHERE Id = :c.FEC_Account_or_Contract__c
                LIMIT 1
            ];
            if (!histories.isEmpty() && String.isNotBlank(histories[0].FEC_Account_Number__c)) {
                return histories[0].FEC_Account_Number__c;
            }
        }
        return c.FEC_Account_Number__c;
    }
    
    /**
     * INSERT Card Delivery từ GetStatus API (chỉ INSERT, không UPDATE)
     * Method này chỉ được gọi 1 lần duy nhất khi chưa có dữ liệu trong database
     * @param info - Thông tin Card Delivery từ GetStatus API
     * @param caseId - ID của Case record
     * @param customerHistoryId - ID của Customer History record (required field)
     */
    private static FEC_Card_Delivery__c insertCardDeliveryFromGetStatus(FEC_GetStatus.CardDeliveryInfo info, String caseId, Id customerHistoryId) {
        if (String.isBlank(info.cardNumber) || customerHistoryId == null) {
            return null;
        }

        try {
            String maskedCardNumber = FEC_CommonUltils.maskCardNumber(info.cardNumber);
            
            // Kiểm tra xem đã có record chưa (chỉ INSERT nếu chưa có)
            List<FEC_Card_Delivery__c> existing = [
                SELECT Id, FEC_Card_Number__c, FEC_Issue_Date__c, FEC_Type_of_Issue__c,
                       FEC_Delivery_Status__c, FEC_Delivery_Date__c, FEC_Recipient__c,
                       FEC_Tracking_Number__c, FEC_Delivery_Note__c
                FROM FEC_Card_Delivery__c 
                WHERE FEC_Card_Number__c = :maskedCardNumber AND FEC_Customer_History__c = :customerHistoryId
                LIMIT 1
            ];

            // Nếu đã có record → return existing record (không update)
            if (!existing.isEmpty()) {
                return existing[0];
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
                    // Invalid date format
                }
            }
            
            insert record;
            return record;
        } catch (Exception e) {
            System.debug('Save Card Delivery error: ' + e.getMessage());
            return null;
        }
    }



    /**
     * Parse delivery date từ nhiều format khác nhau
     * Hỗ trợ: 1/1/2024, 01/01/2024, 2024-01-01, yyyyMMdd, etc.
     * Tái sử dụng FEC_CommonUltils.parseDate cho format yyyyMMdd và yyyy-MM-dd.
     */
    private static Date parseDeliveryDate(String dateStr) {
        if (String.isBlank(dateStr)) return null;
        
        try {
            // Format có dấu /: M/d/yyyy hoặc MM/dd/yyyy (1/1/2024 hoặc 01/01/2024)
            if (dateStr.contains('/')) {
                List<String> parts = dateStr.split('/');
                if (parts.size() == 3) {
                    Integer month = Integer.valueOf(parts[0]);
                    Integer day = Integer.valueOf(parts[1]);
                    Integer year = Integer.valueOf(parts[2]);
                    return Date.newInstance(year, month, day);
                }
            }
            
            // Format yyyyMMdd, yyyy-MM-dd, 00000000: dùng chung FEC_CommonUltils.parseDate
            return FEC_CommonUltils.parseDate(dateStr);
        } catch (Exception e) {
            System.debug('parseDeliveryDate error for "' + dateStr + '": ' + e.getMessage());
        }
        
        return null;
    }
    
    /**
     * So sánh 2 card numbers (có thể masked với format khác nhau)
     * Chỉ compare 6 số đầu và 4 số cuối (bỏ qua phần mask)
     * @param card1 - Card number 1 (có thể masked hoặc full)
     * @param card2 - Card number 2 (có thể masked hoặc full)
     * @return true nếu 6 số đầu và 4 số cuối giống nhau
     */
    private static Boolean compareCardNumbers(String card1, String card2) {
        if (String.isBlank(card1) || String.isBlank(card2)) {
            return false;
        }
        
        // Remove spaces and convert to uppercase
        card1 = card1.replaceAll('\\s+', '').toUpperCase();
        card2 = card2.replaceAll('\\s+', '').toUpperCase();
        
        // Both cards must be at least 10 characters
        if (card1.length() < 10 || card2.length() < 10) {
            return false;
        }
        
        // Extract first 6 digits and last 4 digits
        String card1First6 = card1.substring(0, 6);
        String card1Last4 = card1.substring(card1.length() - 4);
        
        String card2First6 = card2.substring(0, 6);
        String card2Last4 = card2.substring(card2.length() - 4);
        
        // Compare only digits (ignore X, *, or other mask characters)
        return card1First6.equals(card2First6) && card1Last4.equals(card2Last4);
    }
    
    /**
     * INSERT Supplementary Cards từ CardSecInfo API (chỉ INSERT, không UPDATE)
     * Method này chỉ được gọi 1 lần duy nhất khi chưa có dữ liệu trong database
     * @param suppList - Danh sách SupplementaryCard từ API
     * @param customerHistoryId - ID Customer History từ Case
     */
    private static List<FEC_Other_Card__c> insertSupplementaryCards(List<FEC_GetCardSecInfo.SupplementaryCard> suppList, Id customerHistoryId) {
        if (customerHistoryId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Customer History ID'}));
        }
        
        // Query tất cả existing Other Cards trong database
        List<FEC_Other_Card__c> existingCards = [
            SELECT FEC_Card_Number__c
            FROM FEC_Other_Card__c
            WHERE FEC_Customer_History__c = :customerHistoryId
        ];
        
        // Build Set để check duplicate nhanh
        Set<String> existingCardNumbers = new Set<String>();
        for (FEC_Other_Card__c card : existingCards) {
            if (String.isNotBlank(card.FEC_Card_Number__c)) {
                existingCardNumbers.add(card.FEC_Card_Number__c);
            }
        }
        
        List<FEC_Other_Card__c> recordsToInsert = new List<FEC_Other_Card__c>();
        Set<String> processedCardNumbers = new Set<String>(); // Tránh duplicate TRONG response

        for (FEC_GetCardSecInfo.SupplementaryCard item: suppList) {
            // Validate: Phải có số thẻ mới lưu
            if (String.isBlank(item.CardNumber)) {
                continue;
            }

            // Tránh duplicate CardNumber TRONG database (đã tồn tại)
            if (existingCardNumbers.contains(item.CardNumber)) {
                continue;
            }

            // Tránh duplicate CardNumber TRONG response (nếu API trả về duplicate)
            if (processedCardNumbers.contains(item.CardNumber)) {
                continue;
            }
            
            // INSERT record mới
            FEC_Other_Card__c record = new FEC_Other_Card__c();
            record.FEC_Customer_History__c = customerHistoryId;
            record.FEC_Card_Number__c = item.CardNumber;
            record.FEC_Cardholder__c = item.CardholderName;
            record.FEC_Plastic_ID__c = item.PlasticIndicator;
            record.FEC_Embossing_Name__c = item.EmbossingName;
            record.FEC_Block_Code__c = item.BlockCode;
            record.FEC_Gender__c = item.Gender;
            
            // Ánh xạ các trường Date
            record.FEC_Expiry_Date__c = FEC_CommonUltils.parseDate(item.ExpiryDate);
            record.FEC_Card_Activation_Date__c = item.CardActivationDate; // Đã là Date type
            record.FEC_Issue_Date__c = item.CardIssueDate; // Đã là Date type
            
            recordsToInsert.add(record);
            processedCardNumbers.add(item.CardNumber); // Đánh dấu đã xử lý
        }
        
        if (!recordsToInsert.isEmpty()) {
            try {
                insert recordsToInsert;
                return recordsToInsert;
            } catch (Exception e) {
                System.debug('Insert Supplementary Cards error: ' + e.getMessage());
                throw new AuraHandledException('Lỗi lưu dữ liệu: ' + e.getMessage());
            }
        }
        
        return new List<FEC_Other_Card__c>();
    }
    
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

    /**
     * Build CardInfoDTO từ response GetStatus + GetCardSecInfo (không gọi API).
     * Dùng khi đã có sẵn getStatusInfo và cardSecResponse (Mock: gọi 1 lần rồi build + insert).
     */
    private static CardInfoDTO buildCardInfoFromResponses(FEC_GetStatus.CardDeliveryInfo getStatusInfo, FEC_GetCardSecInfo.ResponseWrapper cardSecResponse) {
        if (getStatusInfo == null || getStatusInfo.responseCode != '1') {
            return null;
        }
        if (cardSecResponse != null && (cardSecResponse.Sys == null || cardSecResponse.Sys.Code != 1 || cardSecResponse.CardSecInfo == null)) {
            cardSecResponse = null;
        }

        CardInfoDTO dto = new CardInfoDTO();
        dto.cardDeliveries = new List<CardDeliveryDTO>();
        dto.otherCards = new List<OtherCardDTO>();

        CardDeliveryDTO deliveryDto = new CardDeliveryDTO();
        deliveryDto.cardNumber = String.isNotBlank(getStatusInfo.cardNumber) ? FEC_CommonUltils.maskCardNumber(getStatusInfo.cardNumber) : getStatusInfo.cardNumber;
        deliveryDto.issueDate = String.isNotBlank(getStatusInfo.issueDate) ? parseDeliveryDate(getStatusInfo.issueDate) : null;
        if (deliveryDto.issueDate == null && String.isNotBlank(getStatusInfo.issueDate)) {
            try { deliveryDto.issueDate = Date.valueOf(getStatusInfo.issueDate); } catch (Exception ex) { }
        }
        deliveryDto.typeOfIssue = null;
        deliveryDto.deliveryStatus = getStatusInfo.status;
        deliveryDto.deliveryDate = null;
        deliveryDto.recipient = getStatusInfo.receiverName;
        deliveryDto.trackingNumber = getStatusInfo.trackingNo;
        deliveryDto.deliveryNote = getStatusInfo.deliveryNotes;
        if (cardSecResponse != null && cardSecResponse.CardSecInfo.CardsDeliveries != null && !cardSecResponse.CardSecInfo.CardsDeliveries.isEmpty()) {
            for (FEC_GetCardSecInfo.CardsDelivery cd : cardSecResponse.CardSecInfo.CardsDeliveries) {
                if (String.isNotBlank(cd.CardNumber) && compareCardNumbers(deliveryDto.cardNumber, cd.CardNumber)) {
                    deliveryDto.typeOfIssue = cd.KindOfIssue;
                    deliveryDto.deliveryDate = parseDeliveryDate(cd.DeliveryDate);
                    break;
                }
            }
            if (deliveryDto.typeOfIssue == null && !cardSecResponse.CardSecInfo.CardsDeliveries.isEmpty()) {
                FEC_GetCardSecInfo.CardsDelivery first = cardSecResponse.CardSecInfo.CardsDeliveries[0];
                deliveryDto.typeOfIssue = first.KindOfIssue;
                deliveryDto.deliveryDate = parseDeliveryDate(first.DeliveryDate);
            }
        }
        dto.cardDeliveries.add(deliveryDto);

        if (cardSecResponse != null && cardSecResponse.CardSecInfo.SupplementaryCards != null) {
            for (FEC_GetCardSecInfo.SupplementaryCard sc : cardSecResponse.CardSecInfo.SupplementaryCards) {
                if (String.isBlank(sc.CardNumber)) continue;
                OtherCardDTO oc = new OtherCardDTO();
                oc.cardholder = sc.CardholderName;
                oc.cardNumber = sc.CardNumber;
                oc.plasticId = sc.PlasticIndicator;
                oc.expiryDate = FEC_CommonUltils.parseDate(sc.ExpiryDate);
                oc.embossingName = sc.EmbossingName;
                oc.cardActivationDate = sc.CardActivationDate;
                oc.issueDate = sc.CardIssueDate;
                oc.blockCode = sc.BlockCode;
                oc.gender = sc.Gender;
                dto.otherCards.add(oc);
            }
        }
        return dto;
    }

}
