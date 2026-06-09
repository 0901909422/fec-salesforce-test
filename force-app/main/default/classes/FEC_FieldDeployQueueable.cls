/**
 * @description Queueable class để deploy custom field qua Tooling API.
 * Queueable + Database.AllowsCallouts cho phép HTTP callout đến chính org.
 * UserInfo.getSessionId() available trong Queueable context (khác với @future).
 * @date 2026-04-21
 */
public with sharing class FEC_FieldDeployQueueable implements Queueable, Database.AllowsCallouts {

    private static final String TARGET_OBJECT = 'FEC_Additional_Info__c';

    private String fieldApiName;
    private String fieldLabel;
    private String propertyType;
    private List<String> picklistValues;

    public FEC_FieldDeployQueueable(String fieldApiName, String fieldLabel, String propertyType, List<String> picklistValues) {
        this.fieldApiName = fieldApiName;
        this.fieldLabel = fieldLabel;
        this.propertyType = propertyType;
        this.picklistValues = picklistValues;
    }

    public void execute(QueueableContext context) {
        try {
            String requestBody = buildRequestBody();

            HttpRequest req = new HttpRequest();
            req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v60.0/tooling/sobjects/CustomField/');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            req.setBody(requestBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
                System.debug('FEC_DEBUG FieldDeployQueueable: SUCCESS - ' + fieldApiName);
            } else {
                System.debug('FEC_DEBUG FieldDeployQueueable: FAILED (' + res.getStatusCode() + '): ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('FEC_DEBUG FieldDeployQueueable: EXCEPTION - ' + e.getMessage());
        }
    }

    private String buildRequestBody() {
        Map<String, Object> body = new Map<String, Object>();
        body.put('FullName', TARGET_OBJECT + '.' + fieldApiName);

        Map<String, Object> metadata = new Map<String, Object>();
        metadata.put('label', fieldLabel);
        metadata.put('description', 'Auto-created from MDM Property');

        switch on propertyType {
            when 'List' {
                metadata.put('type', 'Picklist');
                Map<String, Object> valueSet = new Map<String, Object>();
                valueSet.put('restricted', true);
                Map<String, Object> valueSetDef = new Map<String, Object>();
                valueSetDef.put('sorted', false);
                List<Map<String, Object>> values = new List<Map<String, Object>>();
                if (picklistValues != null) {
                    for (String val : picklistValues) {
                        values.add(new Map<String, Object>{
                            'fullName' => val,
                            'label' => val,
                            'default' => false
                        });
                    }
                }
                valueSetDef.put('value', values);
                valueSet.put('valueSetDefinition', valueSetDef);
                metadata.put('valueSet', valueSet);
            }
            when 'String' {
                metadata.put('type', 'Text');
                metadata.put('length', 255);
            }
            when 'Number' {
                metadata.put('type', 'Number');
                metadata.put('precision', 18);
                metadata.put('scale', 2);
            }
            when 'Boolean' {
                metadata.put('type', 'Checkbox');
                metadata.put('defaultValue', false);
            }
            when 'Date' {
                metadata.put('type', 'Date');
            }
            when 'DateTime' {
                metadata.put('type', 'DateTime');
            }
            when 'Phone number' {
                metadata.put('type', 'Phone');
            }
            when else {
                metadata.put('type', 'Text');
                metadata.put('length', 255);
            }
        }

        body.put('Metadata', metadata);
        return JSON.serialize(body);
    }
}