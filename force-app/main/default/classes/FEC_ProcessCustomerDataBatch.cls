/**
 * Batch xử lý tổng hợp: Quét Config New, Parse Excel và Update trạng thái
 * @created      : 2025/12/31 trung.bui.4
 */
global class FEC_ProcessCustomerDataBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
    
    global void execute(SchedulableContext sc) {
        FEC_ProcessCustomerDataBatch batch = new FEC_ProcessCustomerDataBatch();
        Database.executeBatch(batch);
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, FEC_KeyIdentifier__c, FEC_FieldID__c 
            FROM FEC_CustomerAdditionalInfoConfig__c 
            WHERE FEC_Status__c = 'Uploaded'
        ]);
    }

    global void execute(Database.BatchableContext bc, List<FEC_CustomerAdditionalInfoConfig__c> scope) {
        List<FEC_CustomerAdditionalInfo__c> lstDetailsToInsert = new List<FEC_CustomerAdditionalInfo__c>();
        List<ContentVersion> lstCVToUpdate = new List<ContentVersion>();
        List<FEC_CustomerAdditionalInfoConfig__c> lstConfigToUpdate = new List<FEC_CustomerAdditionalInfoConfig__c>();

        // Set ID để tránh truy vấn lặp lại trong loop
        Set<Id> configIds = (new Map<Id, FEC_CustomerAdditionalInfoConfig__c>(scope)).keySet();

        // 2. Tìm các file 'Uploaded' liên kết với danh sách Config này
        Map<Id, ContentVersion> mapConfigToFile = new Map<Id, ContentVersion>();
        for (ContentDocumentLink link : [
            SELECT LinkedEntityId, ContentDocument.LatestPublishedVersionId, 
                   ContentDocument.LatestPublishedVersion.VersionData,
                   ContentDocument.LatestPublishedVersion.Title,
                   ContentDocument.LatestPublishedVersion.Description,
                   ContentDocument.LatestPublishedVersion.FEC_Comments__c
            FROM ContentDocumentLink 
            WHERE LinkedEntityId IN :configIds 
            AND ContentDocument.LatestPublishedVersion.Description = 'Uploaded'
        ]) {
            mapConfigToFile.put(link.LinkedEntityId, link.ContentDocument.LatestPublishedVersion);
        }

        for (FEC_CustomerAdditionalInfoConfig__c config : scope) {
            if (mapConfigToFile.containsKey(config.Id)) {
                ContentVersion cv = mapConfigToFile.get(config.Id);
                try {
                    // ĐỌC DỮ LIỆU TỪ COMMENTS
                    if (String.isNotBlank(cv.FEC_Comments__c)) {
                        List<Object> rows = (List<Object>) JSON.deserializeUntyped(cv.FEC_Comments__c);
                        List<FEC_CustomerAdditionalInfo__c> parsedList = new List<FEC_CustomerAdditionalInfo__c>();
                        
                        // Logic lặp qua rows để map vào SObject (như đã hướng dẫn ở step trước)
                        for (Integer i = 1; i < rows.size(); i++) {
                            List<Object> cols = (List<Object>) rows[i];
                            if (cols.size() < 2) continue;
                            parsedList.add(new FEC_CustomerAdditionalInfo__c(
                                FEC_Config__c = config.Id,
                                FEC_KeyIdentifier__c = config.FEC_KeyIdentifier__c,
                                FEC_FieldID__c = config.FEC_FieldID__c,
                                FEC_KeyIDValue__c = String.valueOf(cols[0]),
                                FEC_FieldValue__c = String.valueOf(cols[1]),
                                FEC_LinkedFilename__c = cv.Title
                            ));
                        }
                        
                        if(!parsedList.isEmpty()) lstDetailsToInsert.addAll(parsedList);
                        
                        cv.Description = 'Processed';
                        cv.FEC_Comments__c = '';
                        lstCVToUpdate.add(cv);
                        
                        config.FEC_Status__c = 'Processed';
                        lstConfigToUpdate.add(config);
                    }
                } catch (Exception e) {
                    lstCVToUpdate.add(cv);
                    config.FEC_Status__c = 'Failed';
                    lstConfigToUpdate.add(config);
                }
            }
        }

        if (!lstDetailsToInsert.isEmpty()) insert lstDetailsToInsert;
        if (!lstCVToUpdate.isEmpty()) update lstCVToUpdate;
        if (!lstConfigToUpdate.isEmpty()) update lstConfigToUpdate;
    }

    global void finish(Database.BatchableContext bc) {
        // Có thể gửi thông báo cho User tại đây
    }
}