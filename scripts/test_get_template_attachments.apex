// Test getTemplateAttachments method trực tiếp
List<Map<String, String>> result = FEC_CustomEmailService.getTemplateAttachments('a10Az00000GW96zIAD');
System.debug('Attachments count: ' + result.size());
for (Map<String, String> att : result) {
    System.debug('File: ' + att.get('fileName') + ' | MimeType: ' + att.get('mimeType') + ' | Base64Len: ' + att.get('base64Data').length());
}
