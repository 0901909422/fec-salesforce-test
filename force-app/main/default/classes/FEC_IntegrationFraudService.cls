global with sharing class FEC_IntegrationFraudService {

    
    public static Integer syncMasterDataIntegration() {
        String integrationChannelId = getIntegrationChannelCode('FIMA');
        // 1) Load ALL existing mapping records into a map for upsert comparison
        Map<String, FEC_Master_Data_Integration__c> existingMap = loadExisting(integrationChannelId);        

        // 2) Parse XML
        String xml = FEC_FraudCaseMockData.getFraudMasterData();
        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode root = doc.getRootElement();
        Dom.XmlNode body = getChildIgnoreNS(root, 'Body');
        Dom.XmlNode response = findChildByEndsWith(body, 'GetFraudMasterDataResponse');

        // Data to upsert
        Map<String, FEC_Master_Data_Integration__c> toUpsert = new Map<String, FEC_Master_Data_Integration__c>();

        for (Dom.XmlNode mdi : response.getChildElements()) {
            if (mdi.getName() == 'MasterDataItems') {
                processMasterDataItem(mdi, null, '', toUpsert, existingMap, integrationChannelId);
            }
        }

        // 3) UPSERT records
        upsertMasterDataRecords(toUpsert);

        return toUpsert.size();
    }
    

    // --------------------------------------------------------------------------------
    // UPSERT in batches
    // --------------------------------------------------------------------------------
    private static void upsertMasterDataRecords(Map<String, FEC_Master_Data_Integration__c> toUpsert) {
        List<FEC_Master_Data_Integration__c> batch = new List<FEC_Master_Data_Integration__c>();

        for (FEC_Master_Data_Integration__c rec : toUpsert.values()) {
            batch.add(rec);

            if (batch.size() == 150) {
                upsert batch;
                batch.clear();
            }
        }
        if (!batch.isEmpty()) upsert batch;
    }

    // --------------------------------------------------------------------------------
    // Process Master Node
    // --------------------------------------------------------------------------------
    private static void processMasterDataItem(
        Dom.XmlNode node,
        String parentId,
        String path,
        Map<String, FEC_Master_Data_Integration__c> upsertMap,
        Map<String, FEC_Master_Data_Integration__c> existingMap,
        String integrationChannelId
    ) {
        String id = text(node, 'ID');
        String name = text(node, 'Name');
        String nameVN = text(node, 'NameVN');
        String type = text(node, 'Type');
        String newPath = (path == '' ? name : path + ' > ' + name);
        String applyTo = text(node, 'ApplyTo');
        applyTo = String.isBlank(applyTo) ? null : applyTo;
        String posOrderStr = text(node, 'PosOrder');
        Integer posOrder = (posOrderStr != null && posOrderStr.trim() != '') ? Integer.valueOf(posOrderStr) : null;

        if (type != null && (
            type == 'Product' ||
            type == 'CaseType' ||
            type == 'Category' ||
            type == 'SubCategory' ||
            type == 'SubCode'
        )) {
            upsertNode(
                type, id, parentId, name, nameVN, null, null, null, newPath,
                existingMap, upsertMap, integrationChannelId, applyTo, posOrder
            );
        }

        // AdditionalProperties
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == 'AdditionalProperties') {
                processAdditionalProperty(child, id, newPath, upsertMap, existingMap, integrationChannelId);
            }
        }

        // Children
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == 'Children') {
                processMasterDataItem(child, id, newPath, upsertMap, existingMap, integrationChannelId);
            }
        }
    }

    // --------------------------------------------------------------------------------
    // Process Additional Properties
    // --------------------------------------------------------------------------------
    private static void processAdditionalProperty(
        Dom.XmlNode node,
        String parentId,
        String path,
        Map<String, FEC_Master_Data_Integration__c> upsertMap,
        Map<String, FEC_Master_Data_Integration__c> existingMap,
        String integrationChannelId
    ) {
        String fieldId = text(node, 'ID');
        String fieldName = text(node, 'Name');
        String nameVN = text(node, 'NameVN');
        String type = text(node, 'Type');
        String mandStr = text(node, 'Mandatory');
        Boolean mandatory = (mandStr != null && mandStr.toLowerCase() == 'true') ? true : false;
        String applyTo = text(node, 'ApplyTo');
        applyTo = String.isBlank(applyTo) ? null : applyTo;
        String posOrderStr = text(node, 'PosOrder');
        Integer posOrder = (posOrderStr != null && posOrderStr.trim() != '') ? Integer.valueOf(posOrderStr) : null;



        // Upsert AdditionalProperty
        upsertNode(
            'AdditionalProperty', fieldId, parentId, fieldName, nameVN,
            type, mandatory, null, path + ' > ' + fieldName,
            existingMap, upsertMap, integrationChannelId, applyTo, posOrder
        );

        // Available Values
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == 'AvailableValues') {
                String valId = text(child, 'ID');
                String valName = text(child, 'Name');
                String valNameVN = text(child, 'NameVN');
                applyTo = text(child, 'ApplyTo');
                applyTo = String.isBlank(applyTo) ? null : applyTo;
                posOrderStr = text(child, 'PosOrder');
                posOrder = (posOrderStr != null && posOrderStr.trim() != '') ? Integer.valueOf(posOrderStr) : null;

                upsertNode(
                    'AvailableValue', valId, fieldId,
                    valName, valNameVN,
                    null, null, valId,
                    path + ' > ' + fieldName + ' > ' + valName,
                    existingMap, upsertMap, integrationChannelId, applyTo, posOrder
                );
            }
        }
    }
    

    // Convert SOAP master data into UI-friendly hierarchical map
    // Build UI-friendly hierarchical master data from Salesforce object
    public static Map<String, Object> buildUiMasterData() {

        Map<String, Object> result = new Map<String, Object>();
        List<Map<String, Object>> categories = new List<Map<String, Object>>();

        // Load full master data
        List<FEC_Master_Data_Integration__c> recs = [
            SELECT 
                FEC_Source_Id__c,
                FEC_Source_Parent_Id__c,
                FEC_Source_Name__c,
                FEC_Source_NameVN__c,
                FEC_Source_Type__c,
                FEC_Source_Field_Type__c,
                FEC_Source_Enum_Value__c,
                FEC_Source_Enum_Label__c,
                FEC_Source_Enum_LabelVN__c,
                FEC_Source_Is_Mandatory__c,
                FEC_PosOrder__c
            FROM FEC_Master_Data_Integration__c
            ORDER BY FEC_PosOrder__c NULLS LAST
        ];
        System.debug('➡ Load full master data        = ' + JSON.serializePretty(recs));

        // Group records by Type
        Map<String, List<FEC_Master_Data_Integration__c>> typeMap = new Map<String, List<FEC_Master_Data_Integration__c>>();
        for (FEC_Master_Data_Integration__c r : recs) {
            String t = r.FEC_Source_Type__c != null ? r.FEC_Source_Type__c : 'UNKNOWN';
            if (!typeMap.containsKey(t)) {
                typeMap.put(t, new List<FEC_Master_Data_Integration__c>());
            }
            typeMap.get(t).add(r);
        }

        // Safe shortcuts
        List<FEC_Master_Data_Integration__c> categoryList        = typeMap.containsKey('Category')         ? typeMap.get('Category')         : new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> subCategoryList    = typeMap.containsKey('SubCategory')      ? typeMap.get('SubCategory')      : new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> subCodeList        = typeMap.containsKey('SubCode')          ? typeMap.get('SubCode')          : new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> additionalList     = typeMap.containsKey('AdditionalProperty')? typeMap.get('AdditionalProperty'): new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> availableValueList = typeMap.containsKey('AvailableValue')   ? typeMap.get('AvailableValue')   : new List<FEC_Master_Data_Integration__c>();
        System.debug('➡ Load full master categoryList        = ' + JSON.serializePretty(categoryList));
        System.debug('➡ Load full master subCategoryList        = ' + JSON.serializePretty(subCategoryList));
        System.debug('➡ Load full master additionalList        = ' + JSON.serializePretty(additionalList));
        System.debug('➡ Load full master availableValueList        = ' + JSON.serializePretty(availableValueList));
        // ------------------------------------------------------------
        // BUILD TREE: Category → SubCategory → SubCode → AP → Values
        // ------------------------------------------------------------
        for (FEC_Master_Data_Integration__c cat : categoryList) {

            Map<String, Object> catNode = new Map<String, Object>{
                'id'            => cat.FEC_Source_Id__c,
                'name'          => cat.FEC_Source_Name__c,
                'nameVN'        => cat.FEC_Source_NameVN__c,
                'posOrder'      => cat.FEC_PosOrder__c,
                'subCategories' => new List<Object>()
            };

            // ---------------- SUBCATEGORY ----------------
            for (FEC_Master_Data_Integration__c sub : subCategoryList) {
                if (sub.FEC_Source_Parent_Id__c == cat.FEC_Source_Id__c) {

                    Map<String, Object> subNode = new Map<String, Object>{
                        'id'        => sub.FEC_Source_Id__c,
                        'name'      => sub.FEC_Source_Name__c,
                        'nameVN'    => sub.FEC_Source_NameVN__c,
                        'subCodes'  => new List<Object>()
                    };

                    // ---------------- SUBCODE ----------------
                    for (FEC_Master_Data_Integration__c sc : subCodeList) {
                        if (sc.FEC_Source_Parent_Id__c == sub.FEC_Source_Id__c) {

                            Map<String, Object> scNode = new Map<String, Object>{
                                'id'        => sc.FEC_Source_Id__c,
                                'name'      => sc.FEC_Source_Name__c,
                                'nameVN'    => sc.FEC_Source_NameVN__c,
                                'additionalProperties' => new List<Object>()
                            };

                            // ---------------- ADDITIONAL PROPERTY ----------------
                            for (FEC_Master_Data_Integration__c ap : additionalList) {
                                if (ap.FEC_Source_Parent_Id__c == sc.FEC_Source_Id__c) {

                                    Map<String, Object> apNode = new Map<String, Object>{
                                        'id'            => ap.FEC_Source_Id__c,
                                        'name'          => ap.FEC_Source_Name__c,
                                        'nameVN'        => ap.FEC_Source_NameVN__c,
                                        'type'          => ap.FEC_Source_Field_Type__c,
                                        'mandatory'     => ap.FEC_Source_Is_Mandatory__c,
                                        'availableValues' => new List<Object>()
                                    };

                                    // ---------------- AVAILABLE VALUES ----------------
                                    for (FEC_Master_Data_Integration__c av : availableValueList) {
                                        if (av.FEC_Source_Parent_Id__c == ap.FEC_Source_Id__c) {

                                            List<Object> avList = (List<Object>) apNode.get('availableValues');
                                            if (avList == null) {
                                                avList = new List<Object>();
                                                apNode.put('availableValues', avList);
                                            }

                                            avList.add(new Map<String, Object>{
                                                'id'     => av.FEC_Source_Enum_Value__c,
                                                'name'   => av.FEC_Source_Enum_Label__c,
                                                'nameVN' => av.FEC_Source_Enum_LabelVN__c
                                            });
                                        }
                                    }

                                    // Add AP → SubCode
                                    ((List<Object>)scNode.get('additionalProperties')).add(apNode);
                                }
                            }

                            // Add SubCode → SubCategory
                            ((List<Object>)subNode.get('subCodes')).add(scNode);
                        }
                    }

                    // Add SubCategory → Category
                    ((List<Object>)catNode.get('subCategories')).add(subNode);
                }
            }

            categories.add(catNode);
        }
        System.debug('➡ Load full all categories = ' + JSON.serializePretty(categories));
        result.put('categories', categories);
        return result;
    }
    


    public static Map<String,Object> extractRequestData(String raw) {
        // Extract XML string from "data": "....."
        String xmlData = extractXml(raw);
        //System.debug('EXTRACTED XML:\n' + xmlData);

        // Clean JSON body by replacing XML with ""
        String jsonClean = cleanJson(raw);
        //System.debug('CLEAN JSON FOR PARSING:\n' + jsonClean);

        // Now safe to deserialize
        Map<String,Object> wrapper =
            (Map<String,Object>) JSON.deserializeUntyped(jsonClean);

        Map<String,Object> detail =
            (Map<String,Object>) wrapper.get('detail');

        //System.debug('DETAIL MAP:\n' + JSON.serializePretty(detail));

        // Final combined return
        return new Map<String,Object>{
            'detail' => detail,
            'xml'    => xmlData
        };
    }





    // Private function
    private static String formatDDMMYYYY(String rawDate) {
        // Null / length guard
        if (String.isBlank(rawDate) || rawDate.length() != 8) {
            return null;
        }
        // Ensure numeric
        if (!rawDate.isNumeric()) {
            return null;
        }
        return rawDate.substring(6, 8) + '/' +
            rawDate.substring(4, 6) + '/' +
            rawDate.substring(0, 4);
    }

    // -----------------------------
    // JSON EXTRACTOR (remove XML block)
    // -----------------------------
    public static String formatDateTime(DateTime dt) {
        return dt != null ? dt.format('dd/MM/yyyy HH:mm:ss') : null;
    }
    
    
    // private static String cleanJson(String raw) {
    //     Integer start = raw.indexOf('"data":');
    //     Integer firstQuote = raw.indexOf('"', start + 7);
    //     Integer closingQuote = raw.lastIndexOf('"');

    //     String json = raw.substring(0, firstQuote) + '""' + raw.substring(closingQuote + 1);
    //     return json;
    // }
    private static String cleanJson(String raw) {

    if (String.isBlank(raw)) {
        return raw;
    }

    Integer dataKeyIdx = raw.indexOf('"data":');
    if (dataKeyIdx == -1) {
        return raw;
    }

    // Find the first quote after "data":
    Integer valueStart = raw.indexOf('"', dataKeyIdx + 7);
    if (valueStart == -1) {
        return raw;
    }

    // We must find the END of the data value.
    // Strategy:
    //  - data is followed by , "messageTime"
    Integer nextFieldIdx = raw.indexOf(',"messageTime"', valueStart);
    if (nextFieldIdx == -1) {
        return raw;
    }

    // Replace the whole data value with empty string
    String cleaned =
        raw.substring(0, valueStart + 1) +
        raw.substring(nextFieldIdx);

    // Ensure "data":""
    cleaned = cleaned.replaceFirst('"data":"', '"data":""');

    return cleaned;
}


    // -----------------------------
    // Extract XML from raw body
    // -----------------------------
    private static String extractXml(String raw) {
        Integer start = raw.indexOf('<');
        Integer endT   = raw.lastIndexOf('>');

        return (start >= 0 && endT >= 0) 
            ? raw.substring(start, endT+1)
            : null;
    }

  
    // --------------------------------------------------------------------------------
    // Load existing data into a lookup map
    // --------------------------------------------------------------------------------
    private static Map<String, FEC_Master_Data_Integration__c> loadExisting(String integrationChannelId) {
        Map<String, FEC_Master_Data_Integration__c> mapData = new Map<String, FEC_Master_Data_Integration__c>();

        for (FEC_Master_Data_Integration__c rec : [
            SELECT 
                FEC_Source_Type__c,
                FEC_Source_Id__c,
                FEC_Source_Parent_Id__c,
                FEC_Source_Name__c,
                FEC_Source_NameVN__c,
                FEC_Source_Field_Type__c,
                FEC_Source_Enum_Value__c,
                FEC_Source_Enum_Label__c,
                FEC_Source_Enum_LabelVN__c,
                FEC_Source_Is_Mandatory__c,
                FEC_Source_Path__c
            FROM FEC_Master_Data_Integration__c
            WHERE FEC_Channel__c = :integrationChannelId
        ]) {
            String key = rec.FEC_Source_Type__c + '|' + rec.FEC_Source_Id__c + '|' + rec.FEC_Source_Parent_Id__c;
            mapData.put(key, rec);
        }
        return mapData;
    }


    // --------------------------------------------------------------------------------
    // Unified UPSERT helper
    // --------------------------------------------------------------------------------
    private static void upsertNode(
    String srcType,
    String srcId,
    String parentId,
    String name,
    String nameVN,
    String fieldType,
    Boolean mandatory,
    String enumValue,
    String fullPath,
    Map<String, FEC_Master_Data_Integration__c> existingMap,
    Map<String, FEC_Master_Data_Integration__c> upsertMap,
    String integrationChannelId,
    String applyTo,
    Integer posOrder
    ) {
        String key = srcType + '|' + srcId + '|' + parentId;
        FEC_Master_Data_Integration__c rec;

        if (existingMap.containsKey(key)) {
            rec = existingMap.get(key);
        } else {
            rec = new FEC_Master_Data_Integration__c();
            rec.FEC_Source_Type__c = srcType;
            rec.FEC_Source_Id__c = srcId;
            rec.FEC_Source_Parent_Id__c = parentId;
        }

        rec.FEC_Source_Name__c = name;
        rec.FEC_Source_NameVN__c = nameVN;
        rec.FEC_Source_Field_Type__c = fieldType;

        // ************* FIX START *************
        // Always enforce boolean
        if (mandatory == null) {
            rec.FEC_Source_Is_Mandatory__c = false;
        } else {
            rec.FEC_Source_Is_Mandatory__c = mandatory;
        }
        // ************* FIX END *************

        rec.FEC_Source_Enum_Value__c = enumValue;
        rec.FEC_Source_Path__c = fullPath;
        rec.FEC_Channel__c = integrationChannelId;
        rec.FEC_ApplyTo__c = applyTo;
        rec.FEC_PosOrder__c = posOrder;

        upsertMap.put(key, rec);
    }

    // --------------------------------------------------------------------------------
    // Helpers
    // --------------------------------------------------------------------------------
    private static String text(Dom.XmlNode parent, String name) {
        for (Dom.XmlNode c : parent.getChildElements())
            if (c.getName() == name) return c.getText();
        return null;
    }
    private static Dom.XmlNode getChildIgnoreNS(Dom.XmlNode node, String name) {
        for (Dom.XmlNode c : node.getChildElements())
            if (c.getName() == name ||
                (c.getName().contains(':') && c.getName().endsWith(name)))
                return c;
        return null;
    }
    private static Dom.XmlNode findChildByEndsWith(Dom.XmlNode node, String suffix) {
        for (Dom.XmlNode c : node.getChildElements())
            if (c.getName().endsWith(suffix)) return c;
        return null;
    }
    private static String getIntegrationChannelCode(String code) {
        List<FEC_Case_Channel__c> chs = [
            SELECT FEC_Alias__c, FEC_Code__c
            FROM FEC_Case_Channel__c
            WHERE FEC_Status__c = true
        ];

        for (FEC_Case_Channel__c c : chs) {
            if (c.FEC_Code__c == code) return c.FEC_Code__c;
        }
        return null;
    }
}