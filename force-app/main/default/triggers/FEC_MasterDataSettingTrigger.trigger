/**
 * @description Trigger Live FEC_Master_Data_Setting__c — chỉ tính FEC_Sync_Hash__c (vân tay nội dung)
 *              để so sánh Live↔MDM heap-safe. Không đụng nghiệp vụ khác.
 * @author DAT NGO
 * @date 2026-06-12
 */
trigger FEC_MasterDataSettingTrigger on FEC_Master_Data_Setting__c (before insert, before update) {
    FEC_MDMHashUtil.applyHash(Trigger.new);
}