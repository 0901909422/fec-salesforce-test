/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Queue job to query CustomSync records and send email report
Test Class:    FEC_CustomSyncAllInOneTest 
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/03/31     Duan Nguyen          Init
2026/04/08     Duan Nguyen          Add email report with HTML table
------------------------------------------------------------*/
public class FEC_QueueReportCustomSyncBix implements Queueable {   

    public void execute(QueueableContext context) { 
        List<CustomSync__c> records = [
            SELECT name, WhatSync__c, StartAt__c, EndAt__c, SyncFailed__c,
                   SyncSuccessFully__c, TotalRecordSync__c, Active__c,ProcessingQuantity__c
            FROM CustomSync__c
            WHERE Active__c = true
            ORDER BY name DESC 
        ];

        if (records.isEmpty()) return;  

        String htmlBody = buildHtmlTable(records);
        sendEmail(htmlBody, records.size());
    }

    private String buildHtmlTable(List<CustomSync__c> records) {
        List<String> htmlRows = new List<String>();
    
        htmlRows.add('<html><body>');
        htmlRows.add('<h2>Sync To Bix Report</h2>');
        htmlRows.add('<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse;font-family:Arial,sans-serif;font-size:13px;width:100%;">');
        htmlRows.add('<thead style="background-color:#0070d2;color:#ffffff;"><tr>');
        
        htmlRows.add('<th>Number</th>'); 
        htmlRows.add('<th>Sync Name</th>'); 
        htmlRows.add('<th>Start At</th>');
        htmlRows.add('<th>End At</th>');
        htmlRows.add('<th>Status (Success Rate)</th>');  
        htmlRows.add('<th>Failed</th>');
        htmlRows.add('<th>Success</th>'); 
        htmlRows.add('<th>Total Record</th>');

        htmlRows.add('</tr></thead><tbody>');

        Integer count = 1;

        for (CustomSync__c rec : records) {
            htmlRows.add('<tr>'); 
            Decimal failed = rec.SyncFailed__c != null ? rec.SyncFailed__c : 0;
            Decimal success = rec.SyncSuccessFully__c != null ? rec.SyncSuccessFully__c : 0;
            Decimal total = rec.TotalRecordSync__c != null ? rec.TotalRecordSync__c : 0;  
            String statusHtml = '';

            if (failed > 0) {
                Decimal totalCalculated = success + failed;
                if (totalCalculated > 0) {
                    Decimal percent = (success / totalCalculated) * 100;
                    statusHtml = '<span style="color:#d4504c; font-weight:bold;">' + percent.setScale(2) + '%</span>'; 
                } else {
                    statusHtml = '0%';
                }
            } else if (success > 0) {
                statusHtml = '<span style="color:#04844b; font-weight:bold;">100%</span>'; 
            } else {
                statusHtml = '<span style="color:#706e6b;">N/A</span>'; 
            } 

            htmlRows.add('<td style="text-align:center; font-weight:bold;">' + count + '</td>');
            count++; 
            
            htmlRows.add('<td style="font-weight:bold;">' + rec.Name + '</td>');
            htmlRows.add('<td>' + (rec.StartAt__c != null ? rec.StartAt__c.format('dd/MM/yyyy HH:mm') : '') + '</td>');
            htmlRows.add('<td>' + (rec.EndAt__c != null ? rec.EndAt__c.format('dd/MM/yyyy HH:mm') : '') + '</td>');
             
            htmlRows.add('<td style="text-align:center;">' + statusHtml + '</td>');
            
            htmlRows.add('<td style="text-align:center;">' + failed.format() + '</td>');
            htmlRows.add('<td style="text-align:center;">' + success.format() + '</td>');
              
            
            htmlRows.add('<td style="text-align:center;">' + total.format() + '</td>');
            
            htmlRows.add('</tr>');
        }

        htmlRows.add('</tbody></table>');
        htmlRows.add('</body></html>');

        return String.join(htmlRows, '');
    }

    private void sendEmail(String htmlBody, Integer totalRecords) { 
        CustomSyncSetting__c setting = CustomSyncSetting__c.getOrgDefaults();
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ setting.EmailReport__c });
        mail.setSubject('Report Sync to Bix - ' + System.now().format('dd/MM/yyyy hh:mm a'));
        mail.setHtmlBody(htmlBody);
        mail.setSaveAsActivity(false); 
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug('FEC_QueueReportCustomSyncBix Error: ' + e.getMessage());
        }
    }
}