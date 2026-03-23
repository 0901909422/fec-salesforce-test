public class FEC_PushCampaignDataBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
    
    private static final Integer MAX_JSON_SIZE = 1000000; // 1000KB
    private Id specificMappingId;
    private Integer totalRecords = 0;
    private Integer processedCount = 0;
    private Integer chunkIndex = 0;

    public FEC_PushCampaignDataBatch(Id mappingId) {
        this.specificMappingId = mappingId;
    }

    public FEC_PushCampaignDataBatch() {}

    public Database.QueryLocator start(Database.BatchableContext BC) {
        DateTime dtStart = FEC_Util.getStartOfToday();
        DateTime dtEnd = FEC_Util.getEndOfToday();

        String countQuery = 'SELECT count() FROM FEC_DataCampaign__c ' +
                            'WHERE CreatedDate >= :dtStart AND CreatedDate <= :dtEnd ' +
                            'AND FEC_IsPushed__c = false ' +
                            'AND FEC_SendToCommsDB__c = null ' +
                            'AND FEC_SentInstantly__c = null ' +
                            'AND (NOT FEC_RecordStatus__c LIKE \'Resolved-%\')' +
                            'AND FEC_RecordStatus__c != \'Pending-callback\' ' +
                            'AND FEC_CS_Campaign__r.FEC_PushInstant__c = true ' +
                            'AND (FEC_CallbackRequested__c != \'true\' OR FEC_CallbackRequested__c = null)';
        
        this.totalRecords = Database.countQuery(countQuery);

        // 2. Main Query
        String query = 'SELECT Id, FEC_AppId__c, FEC_AccountOrContractNumber__c, FEC_ProductLine__c, ' +
                       'FEC_Number1__c, FEC_Number2__c, FEC_Number3__c, FEC_Number4__c, FEC_Number5__c, ' +
                       'FEC_String1__c, FEC_String2__c, FEC_String3__c, FEC_String4__c, FEC_String5__c, ' +
                       'FEC_DateTime1__c, FEC_DateTime2__c, FEC_DateTime3__c, ' +
                       'FEC_RecordId__c, FEC_RecordStatus__c, FEC_RecordLifetime__c, FEC_RecordCurrentLifetime__c, ' +
                       'FEC_MaxCallAttempt__c, FEC_CurrentCallAttempt__c, FEC_CampaignCallingList__c, FEC_SystemName__c, ' +
                       'CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name, ' +
                       'FEC_CS_Campaign__r.FEC_Campaign__r.FEC_CampaignId__c, ' +
                       'FEC_CS_Campaign__r.FEC_PushInstant__c ' +
                       'FROM FEC_DataCampaign__c ' +
                       'WHERE CreatedDate >= :dtStart AND CreatedDate <= :dtEnd ' +
                       'AND FEC_IsPushed__c = false ' +
                       'AND FEC_SendToCommsDB__c = null ' +
                       'AND FEC_SentInstantly__c = null ' +
                       'AND (NOT FEC_RecordStatus__c LIKE \'Resolved-%\')' +
                       'AND FEC_RecordStatus__c != \'Pending-callback\' ' +
                       'AND FEC_CS_Campaign__r.FEC_PushInstant__c = true ' +
                       'AND (FEC_CallbackRequested__c != \'true\' OR FEC_CallbackRequested__c = null)';

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

            // Kiểm tra xem đây có phải là record cuối cùng của toàn bộ Job hay không
            Boolean isLastRecordOfJob = (this.processedCount == this.totalRecords);
            
            String payload = JSON.serialize(currentChunk);
            
            // Nếu vượt size 400KB, gửi chunk hiện tại (không bao gồm record vừa thêm)
            if (Blob.valueOf(payload).size() > MAX_JSON_SIZE) {
                // Xóa record cuối vừa thêm để gửi chunk cũ
                currentChunk.remove(currentChunk.size() - 1);
                recordsInChunk.remove(recordsInChunk.size() - 1);
                this.processedCount--; // Lùi lại để tính vào chunk sau
                
                send(JSON.serialize(currentChunk));

                // Reset cho chunk mới bắt đầu bằng record vừa bị xóa
                currentChunk = new List<FEC_DataCampaign>{m};
                recordsInChunk = new List<FEC_DataCampaign__c>{rec};
                this.processedCount++;
                this.chunkIndex++;
            }
            
            // Nếu là record cuối cùng của toàn bộ Batch Job
            if (isLastRecordOfJob) {
                send(JSON.serialize(currentChunk));
                currentChunk.clear();
                recordsInChunk.clear();
            }
        }

        // Gửi phần dư còn lại của execute block nếu chưa phải là cuối job
        if (!currentChunk.isEmpty()) {
            send(JSON.serialize(currentChunk));
            this.chunkIndex++;
        }

        update toUpdate;
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
        if(!Test.isRunningTest()) new Http().send(req);
    }

    public void finish(Database.BatchableContext BC) {}
}