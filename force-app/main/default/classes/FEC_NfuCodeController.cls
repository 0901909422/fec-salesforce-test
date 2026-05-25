/**
 * @description Controller for FEC_MDM_NFU_Code__c CRUD.
 */
public with sharing class FEC_NfuCodeController {

    @AuraEnabled(cacheable=true)
    public static List<FEC_MDM_NFU_Code__c> getAllNfuCodes() {
        return [SELECT Id, Name, FEC_Reason_VN__c, FEC_Active__c, CreatedDate
                FROM FEC_MDM_NFU_Code__c ORDER BY Name ASC];
    }

    @AuraEnabled
    public static Id saveNfuCode(String codeName, String reasonVN, Boolean isActive, String recordId) {
        FEC_MDM_NFU_Code__c rec;
        if (String.isNotBlank(recordId)) {
            rec = new FEC_MDM_NFU_Code__c(Id = recordId);
        } else {
            rec = new FEC_MDM_NFU_Code__c();
        }
        rec.Name = codeName;
        rec.FEC_Reason_VN__c = reasonVN;
        rec.FEC_Active__c = isActive != null ? isActive : true;
        upsert rec;
        return rec.Id;
    }

    @AuraEnabled
    public static void deleteNfuCode(Id recordId) {
        if (recordId == null) throw new AuraHandledException('Record Id required.');
        delete new FEC_MDM_NFU_Code__c(Id = recordId);
    }

    /**
     * @description Seed NFU codes from Pega data. Only inserts if table is empty.
     */
    @AuraEnabled
    public static Integer seedNfuCodes() {
        Integer existing = [SELECT COUNT() FROM FEC_MDM_NFU_Code__c];
        if (existing > 0) return 0;
        List<FEC_MDM_NFU_Code__c> codes = new List<FEC_MDM_NFU_Code__c>();
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_CLOSE_90', FEC_Reason_VN__c='Đang làm thủ tục trình đóng hợp đồng', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_COMPLAINT30', FEC_Reason_VN__c='KH khiếu nại và cần xác minh từ các Đơn vị liên quan', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_CLOSE_60', FEC_Reason_VN__c='Đang làm thủ tục đóng HĐ / thẻ tín dụng', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_FRAUD_90', FEC_Reason_VN__c='Giao dịch gian lận (đối với thẻ tín dụng)', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_FRAUD_SYS', FEC_Reason_VN__c='KH chưa nhận được khoản giải ngân (do lỗi VPB FC)', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_COMPLAINT90', FEC_Reason_VN__c='Đang trình hoàn lãi/ phí hoặc đóng hợp đồng đặc biệt', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_FRAUD_PD90', FEC_Reason_VN__c='Nhân viên chiếm dụng tiền thanh toán / thanh lý / giải ngân / tài sản của KH', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_COMPLAINT60', FEC_Reason_VN__c='Đang làm thủ tục điều chỉnh lãi/ phí/ lịch thanh toán do phát sinh sai', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_CANCEL', FEC_Reason_VN__c='KH đã hủy HĐ tín dụng nhưng vẫn bị nhắc nợ', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_FRAUD_60', FEC_Reason_VN__c='Sử dụng trái phép thông tin KH', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_COMPLAINT10', FEC_Reason_VN__c='Khiếu nại liên quan đến bảo hiểm cần xác minh lại với đối tác', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_PMT', FEC_Reason_VN__c='KH đã đóng tiền nhưng VPB FC không nhận được hoặc KH thanh toán sai số HĐ / TK', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_DEATH', FEC_Reason_VN__c='KH chết', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_CUSTMISSING', FEC_Reason_VN__c='KH mất tích', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_ETPMT', FEC_Reason_VN__c='KH đã thanh lý nhưng vẫn bị nhắc nợ', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_MBW', FEC_Reason_VN__c='KH đổi / trả sản phẩm', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_NODIS', FEC_Reason_VN__c='KH không đồng ý nhận khoản vay sau khi VPB FC đã giải ngân', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_NOINS', FEC_Reason_VN__c='KH thương tật', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_OTHERS', FEC_Reason_VN__c='Các trường hợp khác theo quyết định của Giám đốc TTTHN', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_COMPLAINT', FEC_Active__c=true));
        insert codes;
        return codes.size();
    }
}