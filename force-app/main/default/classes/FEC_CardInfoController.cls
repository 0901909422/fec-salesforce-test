public with sharing class FEC_CardInfoController {

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

    /** Card Delivery + Other Cards: DB trước, gọi GetCardSecInfo, insert lần đầu nếu thiếu, reload DB. */
    @AuraEnabled(cacheable=false)
    public static CardInfoDTO loadCardInfo(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
        }

        Case c = [
            SELECT Id, FEC_Account_or_Contract__c, FEC_Account_Number__c,
                   FEC_Account_or_Contract__r.FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        Id customerHistoryId = c.FEC_Account_or_Contract__c;
        String accountNumber = getAccountNumber(c);
        
        if (customerHistoryId == null && String.isNotBlank(accountNumber)) {
            List<FEC_Customer_History__c> h = [
                SELECT Id FROM FEC_Customer_History__c
                WHERE FEC_Account_Number__c = :accountNumber
                LIMIT 1
            ];
            if (!h.isEmpty()) {
                customerHistoryId = h[0].Id;
            }
        }

        CardInfoDTO dto = new CardInfoDTO();
        dto.cardDeliveries = new List<CardDeliveryDTO>();
        dto.otherCards = new List<OtherCardDTO>();

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        Boolean isMockMode = apiSetting == null || apiSetting.FEC_Call_Mock__c != false;
        if (isMockMode) {
            return loadCardInfoForMockMode(customerHistoryId);
        }

        if (customerHistoryId != null) {
            dto.cardDeliveries = mapCardDeliveriesToDTO(queryCardDeliveries(customerHistoryId));
            dto.otherCards = mapOtherCardsToDTO(queryOtherCards(customerHistoryId));
        }

        Boolean hasCd = dto.cardDeliveries != null && !dto.cardDeliveries.isEmpty();
        Boolean hasOc = dto.otherCards != null && !dto.otherCards.isEmpty();

        if (String.isNotBlank(accountNumber) && customerHistoryId != null) {
            try {
                FEC_GetCardSecInfo.ResponseWrapper res = FEC_GetCardSecInfo.getCardSecInfo(accountNumber);
                if (res != null && res.Sys != null && res.Sys.Code == 1 && res.CardSecInfo != null) {
                    FEC_GetCardSecInfo.CardSecInfo info = res.CardSecInfo;
                    if (!hasCd && info.CardsDeliveries != null && !info.CardsDeliveries.isEmpty()) {
                        try {
                            insertCardDeliveriesFromCardSecInfo(info.CardsDeliveries, caseId, customerHistoryId);
                        } catch (Exception ex) {
                            System.debug('Insert Card Deliveries: ' + ex.getMessage());
                        }
                    }
                    if (!hasOc && info.SupplementaryCards != null && !info.SupplementaryCards.isEmpty()) {
                        try {
                            insertSupplementaryCards(info.SupplementaryCards, customerHistoryId);
                        } catch (Exception ex) {
                            System.debug('Insert Supplementary Cards: ' + ex.getMessage());
                        }
                    }
                }
            } catch (Exception ex) {
                System.debug('CardSecInfo API: ' + ex.getMessage());
            }

            FEC_GetCardSecInfo.logApiResponse();

            if (!hasCd) {
                dto.cardDeliveries = mapCardDeliveriesToDTO(queryCardDeliveries(customerHistoryId));
            }
            if (!hasOc) {
                dto.otherCards = mapOtherCardsToDTO(queryOtherCards(customerHistoryId));
            }
        }

        return dto;
    }

    /** Mock mode: Card Delivery từ FEC_MockData; Other Cards giữ DB nếu có. */
    private static CardInfoDTO loadCardInfoForMockMode(Id customerHistoryId) {
        CardInfoDTO mockInfo = FEC_MockData.getHardcodedCardInfo();
        CardInfoDTO dto = new CardInfoDTO();
        dto.cardDeliveries = mockInfo.cardDeliveries != null
            ? mockInfo.cardDeliveries
            : new List<CardDeliveryDTO>();
        dto.otherCards = new List<OtherCardDTO>();
        if (customerHistoryId != null) {
            List<OtherCardDTO> fromDb = mapOtherCardsToDTO(queryOtherCards(customerHistoryId));
            if (!fromDb.isEmpty()) {
                dto.otherCards = fromDb;
            }
        }
        if (dto.otherCards.isEmpty() && mockInfo.otherCards != null) {
            dto.otherCards = mockInfo.otherCards;
        }
        return dto;
    }

    /** 1) Account__r, 2) SOQL History, 3) Case.FEC_Account_Number__c */
    private static String getAccountNumber(Case c) {
        if (c.FEC_Account_or_Contract__r != null
            && String.isNotBlank(c.FEC_Account_or_Contract__r.FEC_Account_Number__c)) {
            return c.FEC_Account_or_Contract__r.FEC_Account_Number__c;
        }
        if (c.FEC_Account_or_Contract__c != null) {
            List<FEC_Customer_History__c> rows = [
                SELECT FEC_Account_Number__c
                FROM FEC_Customer_History__c
                WHERE Id = :c.FEC_Account_or_Contract__c
                LIMIT 1
            ];
            if (!rows.isEmpty() && String.isNotBlank(rows[0].FEC_Account_Number__c)) {
                return rows[0].FEC_Account_Number__c;
            }
        }
        return c.FEC_Account_Number__c;
    }

    private static List<FEC_Card_Delivery__c> queryCardDeliveries(Id customerHistoryId) {
        try {
            return [
                SELECT FEC_Card_Number__c, FEC_Issue_Date__c, FEC_Type_of_Issue__c,
                       FEC_Delivery_Status__c, FEC_Delivery_Date__c, FEC_Recipient__c,
                       FEC_Tracking_Number__c, FEC_Delivery_Note__c
                FROM FEC_Card_Delivery__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                ORDER BY FEC_Issue_Date__c DESC
            ];
        } catch (Exception ex) {
            System.debug('queryCardDeliveries: ' + ex.getMessage());
            return new List<FEC_Card_Delivery__c>();
        }
    }

    private static List<FEC_Other_Card__c> queryOtherCards(Id customerHistoryId) {
        try {
            return [
                SELECT FEC_Cardholder__c, FEC_Card_Number__c, FEC_Plastic_ID__c,
                       FEC_Expiry_Date__c, FEC_Embossing_Name__c, FEC_Card_Activation_Date__c,
                       FEC_Issue_Date__c, FEC_Block_Code__c, FEC_Gender__c
                FROM FEC_Other_Card__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                ORDER BY FEC_Expiry_Date__c DESC
            ];
        } catch (Exception ex) {
            System.debug('queryOtherCards: ' + ex.getMessage());
            return new List<FEC_Other_Card__c>();
        }
    }

    private static List<FEC_Card_Delivery__c> insertCardDeliveriesFromCardSecInfo(
        List<FEC_GetCardSecInfo.CardsDelivery> deliveries,
        String caseId,
        Id customerHistoryId
    ) {
        if (deliveries == null || deliveries.isEmpty() || customerHistoryId == null) {
            return new List<FEC_Card_Delivery__c>();
        }

        Set<String> inDb = new Set<String>();
        for (FEC_Card_Delivery__c x : [
            SELECT FEC_Card_Number__c FROM FEC_Card_Delivery__c
            WHERE FEC_Customer_History__c = :customerHistoryId
        ]) {
            if (String.isNotBlank(x.FEC_Card_Number__c)) {
                inDb.add(x.FEC_Card_Number__c);
            }
        }

        List<FEC_Card_Delivery__c> toInsert = new List<FEC_Card_Delivery__c>();
        Set<String> seen = new Set<String>();

        for (FEC_GetCardSecInfo.CardsDelivery d : deliveries) {
            if (String.isBlank(d.CardNumber)) {
                continue;
            }
            String masked = FEC_CommonUltils.maskCardNumber(d.CardNumber);
            if (seen.contains(masked) || inDb.contains(masked)) {
                continue;
            }
            seen.add(masked);

            FEC_Card_Delivery__c rec = new FEC_Card_Delivery__c();
            rec.FEC_Card_Number__c = masked;
            rec.FEC_Case__c = caseId;
            rec.FEC_Customer_History__c = customerHistoryId;
            rec.FEC_Type_of_Issue__c = d.KindOfIssue;
            rec.FEC_Delivery_Status__c = d.FinalSt;
            rec.FEC_Recipient__c = d.Recipient;
            rec.FEC_Tracking_Number__c = d.TrackingNo;
            rec.FEC_Delivery_Note__c = d.DelayNotes;
            rec.FEC_Issue_Date__c = parseIssueDateFromCardSecInfo(d.IssuelastUpdate);
            rec.FEC_Delivery_Date__c = parseDeliveryDate(d.DeliveryDate);
            toInsert.add(rec);
        }

        if (toInsert.isEmpty()) {
            return new List<FEC_Card_Delivery__c>();
        }
        try {
            insert toInsert;
            return toInsert;
        } catch (Exception ex) {
            System.debug('insertCardDeliveriesFromCardSecInfo: ' + ex.getMessage());
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static Date parseIssueDateFromCardSecInfo(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        Date d = parseDeliveryDate(raw);
        if (d != null) {
            return d;
        }
        String t = raw.trim();
        if (t.length() >= 10) {
            try {
                return Date.valueOf(t.substring(0, 10));
            } catch (Exception ex) {
                System.debug('parseIssueDateFromCardSecInfo: ' + ex.getMessage());
            }
        }
        return null;
    }

    private static Date parseDeliveryDate(String dateStr) {
        if (String.isBlank(dateStr)) {
            return null;
        }
        try {
            if (dateStr.contains('/')) {
                List<String> p = dateStr.split('/');
                if (p.size() == 3) {
                    return Date.newInstance(Integer.valueOf(p[2]), Integer.valueOf(p[0]), Integer.valueOf(p[1]));
                }
            }
            return FEC_CommonUltils.parseDate(dateStr);
        } catch (Exception ex) {
            System.debug('parseDeliveryDate: ' + dateStr + ' — ' + ex.getMessage());
        }
        return null;
    }

    private static List<FEC_Other_Card__c> insertSupplementaryCards(
        List<FEC_GetCardSecInfo.SupplementaryCard> suppList,
        Id customerHistoryId
    ) {
        if (customerHistoryId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Customer History ID'}));
        }

        Set<String> inDb = new Set<String>();
        for (FEC_Other_Card__c x : [
            SELECT FEC_Card_Number__c FROM FEC_Other_Card__c
            WHERE FEC_Customer_History__c = :customerHistoryId
        ]) {
            if (String.isNotBlank(x.FEC_Card_Number__c)) {
                inDb.add(x.FEC_Card_Number__c);
            }
        }

        List<FEC_Other_Card__c> toInsert = new List<FEC_Other_Card__c>();
        Set<String> seen = new Set<String>();

        for (FEC_GetCardSecInfo.SupplementaryCard item : suppList) {
            if (String.isBlank(item.CardNumber) || inDb.contains(item.CardNumber) || seen.contains(item.CardNumber)) {
                continue;
            }
            seen.add(item.CardNumber);
            FEC_Other_Card__c rec = new FEC_Other_Card__c();
            rec.FEC_Customer_History__c = customerHistoryId;
            rec.FEC_Card_Number__c = item.CardNumber;
            rec.FEC_Cardholder__c = item.CardholderName;
            rec.FEC_Plastic_ID__c = item.PlasticIndicator;
            rec.FEC_Embossing_Name__c = item.EmbossingName;
            rec.FEC_Block_Code__c = item.BlockCode;
            rec.FEC_Gender__c = item.Gender;
            rec.FEC_Expiry_Date__c = FEC_CommonUltils.parseDate(item.ExpiryDate);
            rec.FEC_Card_Activation_Date__c = item.CardActivationDate;
            rec.FEC_Issue_Date__c = item.CardIssueDate;
            toInsert.add(rec);
        }

        if (toInsert.isEmpty()) {
            return new List<FEC_Other_Card__c>();
        }
        try {
            insert toInsert;
            return toInsert;
        } catch (Exception ex) {
            System.debug('insertSupplementaryCards: ' + ex.getMessage());
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static List<CardDeliveryDTO> mapCardDeliveriesToDTO(List<FEC_Card_Delivery__c> records) {
        List<CardDeliveryDTO> out = new List<CardDeliveryDTO>();
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
            out.add(dto);
        }
        return out;
    }

    private static List<OtherCardDTO> mapOtherCardsToDTO(List<FEC_Other_Card__c> records) {
        List<OtherCardDTO> out = new List<OtherCardDTO>();
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
            out.add(dto);
        }
        return out;
    }
}
