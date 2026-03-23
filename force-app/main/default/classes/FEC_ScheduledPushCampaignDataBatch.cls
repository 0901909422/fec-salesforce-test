public class FEC_ScheduledPushCampaignDataBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {
    
    private static final Integer MAX_JSON_SIZE = 1000000;
    private Integer totalRecords = 0;
    private Integer processedCount = 0;
    private Integer chunkIndex = 0;

    // --- Thực thi Schedulable (Đặt lịch chạy tự động) ---
    public void execute(SchedulableContext SC) {
        Database.executeBatch(new FEC_ScheduledPushCampaignDataBatch(), 200);
    }

    // --- Thực thi Batchable ---
    public Database.QueryLocator start(Database.BatchableContext BC) {
        // Lấy thứ của ngày hôm nay bằng Apex (ví dụ: 'Saturday', 'Sunday', 'Monday')
        String dayOfWeek = DateTime.now().format('EEEE');

        String query = 'SELECT Id, FEC_AppId__c, FEC_AccountOrContractNumber__c, FEC_ProductLine__c, ' +
                       'FEC_Number1__c, FEC_Number2__c, FEC_Number3__c, FEC_Number4__c, FEC_Number5__c, ' +
                       'FEC_String1__c, FEC_String2__c, FEC_String3__c, FEC_String4__c, FEC_String5__c, ' +
                       'FEC_DateTime1__c, FEC_DateTime2__c, FEC_DateTime3__c, ' +
                       'FEC_RecordId__c, FEC_RecordStatus__c, FEC_RecordLifetime__c, FEC_RecordCurrentLifetime__c, ' +
                       'FEC_MaxCallAttempt__c, FEC_CurrentCallAttempt__c, FEC_CampaignCallingList__c, FEC_SystemName__c, ' +
                       'CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name, ' +
                       'FEC_CS_Campaign__r.FEC_Campaign__r.FEC_CampaignId__c, ' +
                       'FEC_CS_Campaign__r.FEC_ScheduleCampaign__c, ' +
                       'FEC_CS_Campaign__r.FEC_SaturdaySchedule__c, ' +
                       'FEC_CS_Campaign__r.FEC_SundaySchedule__c ' +
                       'FROM FEC_DataCampaign__c ' +
                       'WHERE (NOT FEC_RecordStatus__c LIKE \'Resolved-%\')' +
                       'AND FEC_CS_Campaign__r.FEC_ScheduleCampaign__c = true ' +
                       'AND FEC_IsWithinLifetime__c = true';

        if (dayOfWeek == 'Saturday') {
            query += 'AND FEC_CS_Campaign__r.FEC_SaturdaySchedule__c = true ';
        } 
        else if (dayOfWeek == 'Sunday') {
            query += 'AND FEC_CS_Campaign__r.FEC_SundaySchedule__c = true ';
        }

        this.totalRecords = Database.countQuery(query.replaceFirst('SELECT .*? FROM', 'SELECT count() FROM'));

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<FEC_DataCampaign__c> scope) {
        List<FEC_DataCampaign> currentChunk = new List<FEC_DataCampaign>();
        List<FEC_DataCampaign__c> recordsInChunk = new List<FEC_DataCampaign__c>();
        List<FEC_DataCampaign__c> toUpdate = new List<FEC_DataCampaign__c>();

        for (Integer i = 0; i < scope.size(); i++) {
            FEC_DataCampaign__c rec = scope[i];
            this.processedCount++;
            
            FEC_DataCampaign m = mapToModel(rec);
            currentChunk.add(m);
            recordsInChunk.add(rec);

            Boolean isLastRecordOfJob = (this.processedCount == this.totalRecords);
            String payload = JSON.serialize(currentChunk);
            
            if (Blob.valueOf(payload).size() > MAX_JSON_SIZE) {
                currentChunk.remove(currentChunk.size() - 1);
                recordsInChunk.remove(recordsInChunk.size() - 1);
                this.processedCount--; 
                
                send(JSON.serialize(currentChunk));

                currentChunk = new List<FEC_DataCampaign>{m};
                recordsInChunk = new List<FEC_DataCampaign__c>{rec};
                this.processedCount++;
                this.chunkIndex++;
            }
            
            if (isLastRecordOfJob) {
                send(JSON.serialize(currentChunk));
                currentChunk.clear();
                recordsInChunk.clear();
            }
        }

        if (!currentChunk.isEmpty()) {
            send(JSON.serialize(currentChunk));
            this.chunkIndex++;
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    private Map<String, Object> wrapPayload(Integer idx, List<FEC_DataCampaign> data, Boolean isLast) {
        return new Map<String, Object>{
            'chunkIndex' => idx,
            'isLast' => isLast,
            'data' => data
        };
    }

    private FEC_DataCampaign mapToModel(FEC_DataCampaign__c r) {
        FEC_DataCampaign m = new FEC_DataCampaign();
        m.campaignID = r.FEC_CS_Campaign__r.FEC_Campaign__r.FEC_CampaignId__c;
        m.appID = r.FEC_AppId__c;
        m.accountOrContractNumber = r.FEC_AccountOrContractNumber__c;
        m.productLine = r.FEC_ProductLine__c;
        m.number1 = r.FEC_Number1__c; 
        m.number2 = r.FEC_Number2__c;
        m.number3 = r.FEC_Number3__c;
        m.number4 = r.FEC_Number4__c;
        m.number5 = r.FEC_Number5__c;
        m.string1 = r.FEC_String1__c;
        m.string2 = r.FEC_String2__c;
        m.string3 = r.FEC_String3__c;
        m.string4 = r.FEC_String4__c;
        m.string5 = r.FEC_String5__c;
        m.dateTime1 = r.FEC_DateTime1__c;
        m.dateTime2 = r.FEC_DateTime2__c;
        m.dateTime3 = r.FEC_DateTime3__c;
        m.recordID = r.FEC_RecordId__c;
        m.recordStatus = r.FEC_RecordStatus__c;
        m.createDateTime = r.CreatedDate;
        m.createBy = r.CreatedBy.Name;
        m.updateDateTime = r.LastModifiedDate;
        m.updateBy = r.LastModifiedBy.Name;
        m.campaignCallingList = r.FEC_CampaignCallingList__c;
        m.maxCallAttempt = r.FEC_MaxCallAttempt__c;
        m.recordLifetime = r.FEC_RecordLifetime__c;
        m.currentCallAttempt = r.FEC_CurrentCallAttempt__c;
        m.recordCurrentLifetime = r.FEC_RecordCurrentLifetime__c;
        return m;
    }

    private void send(String body) {
        System.debug(LoggingLevel.INFO, body);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:FEC_API');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(body);
        
        try {
            HttpResponse response = new http().send(req);
         
            System.debug('STATUS CODE: ' + response.getStatusCode());
            System.debug('BODY: ' + response.getBody());
         
            if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                System.debug('Call API thành công!');
            } else {
                System.debug('Lỗi từ Server: ' + response.getStatus());
            }
         
        } catch (Exception e) {
            System.debug('Lỗi kết nối: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('Scheduled Push Batch Completed.');
    }
}