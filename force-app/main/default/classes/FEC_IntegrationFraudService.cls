global with sharing class FEC_IntegrationFraudService {

    public static final Boolean DEBUG_LOG = true;
    public static final String DEFAULT_CHANNEL_INTEGRATION_CODE = 'FIMA';
    public static final String FIELD_TYPE_PRODUCT = 'Product';
	public static final String FIELD_TYPE_CASE_TYPE = 'CaseType';
	public static final String FIELD_TYPE_CATEGORY = 'Category';
	public static final String FIELD_TYPE_SUBCATEGORY = 'SubCategory';
	public static final String FIELD_TYPE_SUBCODE = 'SubCode';
    public static final String FIELD_TYPE_AVAILABELVAL = 'AvailableValues';
	public static final String FIELD_TYPE_ADDITIONALPROPERTY = 'AdditionalProperty';

    public class IntegrationFraudField {
        public final String GET_FRAUD_MASTER_DATA_RESPONSE = 'GetFraudMasterDataResponse';
		public final String MASTER_DATA_ITEMS = 'MasterDataItems';
		public final String MASTER_DATA_ID = 'ID';
		public final String MASTER_DATA_NAME = 'Name';
		public final String MASTER_DATA_NAMEVN = 'NameVN';
		public final String MASTER_DATA_TYPE = 'Type';
		public final String MASTER_DATA_APPLY_TO = 'ApplyTo';
		public final String MASTER_DATA_POST_ORDER = 'PosOrder';
		public final String MASTER_DATA_ADDITIONAL_PROPERTIES = 'AdditionalProperties';
		public final String MASTER_DATA_CHILDRENT = 'Children';
		public final String MASTER_DATA_MANDATORY = 'Mandatory';
    }

    IntegrationFraudField masterDataField = new IntegrationFraudField();

    /**
     * Synchronizes Fraud Master Data from the external integration source into Salesforce.
     *
     * This method performs the complete integration flow:
     *  1. Loads all existing master data records for the integration channel.
     *  2. Retrieves and parses the external XML payload.
     *  3. Transforms the XML structure into Salesforce records.
     *  4. Performs an upsert operation to insert new records and update existing ones.
     *
     * @return The total number of records inserted or updated.
     */
    public static Integer syncMasterDataIntegration() {
        
        String integrationChannelId = getIntegrationChannelCode(DEFAULT_CHANNEL_INTEGRATION_CODE);
        // 1) Load ALL existing mapping records into a map for upsert comparison
        Map<String, FEC_Master_Data_Integration__c> existingMap = loadExisting(integrationChannelId);        

        // 2) Parse XML
        String xml = FEC_FraudCaseMockData.getFraudMasterData();
        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode root = doc.getRootElement();
        Dom.XmlNode body = getChildIgnoreNS(root, 'Body');
        Dom.XmlNode response = findChildByEndsWith(body, masterDataField.GET_FRAUD_MASTER_DATA_RESPONSE);

        // Data to upsert
        Map<String, FEC_Master_Data_Integration__c> toUpsert = new Map<String, FEC_Master_Data_Integration__c>();

        for (Dom.XmlNode mdi : response.getChildElements()) {
            if (mdi.getName() == masterDataField.MASTER_DATA_ITEMS) {
                processMasterDataItem(mdi, null, '', toUpsert, existingMap, integrationChannelId);
            }
        }

        // 3) UPSERT records
        upsertMasterDataRecords(toUpsert);

        return toUpsert.size();
    }
    

    /**
     * Performs a bulk UPSERT operation for all prepared master data records.
     *
     * Records are processed in batches of 150 to:
     *  - Stay well within Salesforce governor limits
     *  - Improve performance and transaction reliability
     *
     * @param toUpsert A map containing all records that need to be inserted or updated.
     */
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

     /**
     * Recursively processes a MasterDataItem node from the integration XML and
     * transforms it into Salesforce records for upsert.
     *
     * This method:
     *  • Extracts basic attributes from the current XML node
     *  • Builds a hierarchical path for UI display and traceability
     *  • Creates or updates the corresponding Salesforce record
     *  • Processes all nested Additional Properties
     *  • Recursively traverses child nodes to build the full data tree
     *
     * @param node                 Current XML node being processed
     * @param parentId             Parent source ID (used to build hierarchy)
     * @param path                 Hierarchical path string for the UI
     * @param upsertMap            Map of records pending insert/update
     * @param existingMap          Map of existing records loaded from Salesforce
     * @param integrationChannelId Integration channel identifier
     */
    private static void processMasterDataItem(
        Dom.XmlNode node,
        String parentId,
        String path,
        Map<String, FEC_Master_Data_Integration__c> upsertMap,
        Map<String, FEC_Master_Data_Integration__c> existingMap,
        String integrationChannelId
    ) {
        String id = text(node, masterDataField.MASTER_DATA_ID);
        String name = text(node, masterDataField.MASTER_DATA_NAME);
        String nameVN = text(node, masterDataField.MASTER_DATA_NAMEVN);
        String type = text(node, masterDataField.MASTER_DATA_TYPE);
        String newPath = (path == '' ? name : path + ' > ' + name);
        String applyTo = text(node, masterDataField.MASTER_DATA_APPLY_TO);
        applyTo = String.isBlank(applyTo) ? null : applyTo;
        String posOrderStr = text(node, masterDataField.MASTER_DATA_POST_ORDER);
        Integer posOrder = (posOrderStr != null && posOrderStr.trim() != '') ? Integer.valueOf(posOrderStr) : null;

        if (type != null && (
            type == FIELD_TYPE_PRODUCT ||
            type == FIELD_TYPE_CASE_TYPE ||
            type == FIELD_TYPE_CATEGORY ||
            type == FIELD_TYPE_SUBCATEGORY ||
            type == FIELD_TYPE_SUBCODE
        )) {
            upsertNode(
                type, id, parentId, name, nameVN, null, null, null, newPath,
                existingMap, upsertMap, integrationChannelId, applyTo, posOrder
            );
        }

        // AdditionalProperties
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == masterDataField.MASTER_DATA_ADDITIONAL_PROPERTIES) {
                processAdditionalProperty(child, id, newPath, upsertMap, existingMap, integrationChannelId);
            }
        }

        // Children
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == masterDataField.MASTER_DATA_CHILDRENT) {
                processMasterDataItem(child, id, newPath, upsertMap, existingMap, integrationChannelId);
            }
        }
    }

    /**
     * Processes an AdditionalProperty node and all of its Available Values
     * from the integration XML, transforming them into Salesforce records.
     *
     * This method:
     *  • Extracts Additional Property metadata
     *  • Creates or updates the corresponding Salesforce record
     *  • Iterates through and processes all child Available Values
     *  • Maintains hierarchical path information for UI rendering
     *
     * @param node                 The AdditionalProperty XML node
     * @param parentId             Parent source ID (typically the SubCode ID)
     * @param path                 Hierarchical path for UI display
     * @param upsertMap            Records prepared for upsert
     * @param existingMap          Existing Salesforce records
     * @param integrationChannelId Integration channel identifier
     */
    private static void processAdditionalProperty(
        Dom.XmlNode node,
        String parentId,
        String path,
        Map<String, FEC_Master_Data_Integration__c> upsertMap,
        Map<String, FEC_Master_Data_Integration__c> existingMap,
        String integrationChannelId
    ) {
        String fieldId = text(node, masterDataField.MASTER_DATA_ID);
        String fieldName = text(node, masterDataField.MASTER_DATA_NAME);
        String nameVN = text(node, masterDataField.MASTER_DATA_NAMEVN);
        String type = text(node, masterDataField.MASTER_DATA_TYPE);
        String mandStr = text(node, masterDataField.MASTER_DATA_MANDATORY);
        Boolean mandatory = (mandStr != null && mandStr.toLowerCase() == 'true') ? true : false;
        String applyTo = text(node, masterDataField.MASTER_DATA_APPLY_TO);
        applyTo = String.isBlank(applyTo) ? null : applyTo;
        String posOrderStr = text(node, masterDataField.MASTER_DATA_POST_ORDER);
        Integer posOrder = (posOrderStr != null && posOrderStr.trim() != '') ? Integer.valueOf(posOrderStr) : null;



        // Upsert AdditionalProperty
        upsertNode(
            FIELD_TYPE_ADDITIONALPROPERTY, fieldId, parentId, fieldName, nameVN,
            type, mandatory, null, path + ' > ' + fieldName,
            existingMap, upsertMap, integrationChannelId, applyTo, posOrder
        );

        // Available Values
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == FIELD_TYPE_AVAILABELVAL) {
                String valId = text(child, masterDataField.MASTER_DATA_ID);
                String valName = text(child, masterDataField.MASTER_DATA_NAME);
                String valNameVN = text(child, masterDataField.MASTER_DATA_NAMEVN);
                applyTo = text(child, masterDataField.MASTER_DATA_APPLY_TO);
                applyTo = String.isBlank(applyTo) ? null : applyTo;
                posOrderStr = text(child, masterDataField.MASTER_DATA_POST_ORDER);
                posOrder = (posOrderStr != null && posOrderStr.trim() != '') ? Integer.valueOf(posOrderStr) : null;

                upsertNode(
                    FIELD_TYPE_AVAILABELVAL, valId, fieldId,
                    valName, valNameVN,
                    null, null, valId,
                    path + ' > ' + fieldName + ' > ' + valName,
                    existingMap, upsertMap, integrationChannelId, applyTo, posOrder
                );
            }
        }
    }
    
      
    /**
     * Loads all existing Master Data records for a given integration channel
     * and indexes them for fast lookup during the synchronization process.
     *
     * The returned map uses a composite key in the format:
     *   SourceType | SourceId | ParentSourceId
     *
     * This allows the integration engine to quickly determine whether
     * a record already exists (for update) or must be inserted.
     *
     * @param integrationChannelId The integration channel identifier
     * @return A map of existing records keyed by a composite business key
     */

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


    /**
     * Creates or updates a single Master Data record in memory for later UPSERT.
     *
     * This method:
     *  • Builds a composite business key for accurate matching
     *  • Reuses existing records when found
     *  • Applies incoming integration values
     *  • Enforces data consistency rules
     *  • Adds the record to the final UPSERT collection
     *
     * @param srcType              Source object type (Category, SubCategory, SubCode, etc.)
     * @param srcId                Unique source identifier
     * @param parentId             Parent source identifier (for hierarchy)
     * @param name                 English display name
     * @param nameVN               Vietnamese display name
     * @param fieldType            Field type for Additional Properties
     * @param mandatory            Mandatory flag for UI validation
     * @param enumValue            Enumeration value (for Available Values)
     * @param fullPath             Full hierarchical path for UI display
     * @param existingMap          Map of existing Salesforce records
     * @param upsertMap            Map collecting records for final UPSERT
     * @param integrationChannelId Integration channel identifier
     * @param applyTo              Optional context where this node applies
     * @param posOrder             Display ordering value
     */
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

   /**
     * Retrieves the text value of a direct child element by name.
     *
     * @param parent The parent XML node
     * @param name   The child element name to search for
     * @return The text value of the matching child element, or null if not found
     */
    private static String text(Dom.XmlNode parent, String name) {
        for (Dom.XmlNode c : parent.getChildElements())
            if (c.getName() == name) return c.getText();
        return null;
    }

    /**
     * Finds a child node by name while safely ignoring XML namespaces.
     *
     * This allows the parser to handle both:
     *   <Body> and <soap:Body>
     *
     * @param node The parent XML node
     * @param name The expected local name of the child
     * @return The matching child node, or null if not found
     */
    private static Dom.XmlNode getChildIgnoreNS(Dom.XmlNode node, String name) {
        for (Dom.XmlNode c : node.getChildElements())
            if (c.getName() == name ||
                (c.getName().contains(':') && c.getName().endsWith(name)))
                return c;
        return null;
    }

    /**
     * Finds the first child node whose name ends with the specified suffix.
     *
     * Useful for locating response elements that may include dynamic
     * or namespaced prefixes in their XML tag names.
     *
     * @param node   The parent XML node
     * @param suffix The expected ending of the node name
     * @return The matching child node, or null if not found
     */
    private static Dom.XmlNode findChildByEndsWith(Dom.XmlNode node, String suffix) {
        for (Dom.XmlNode c : node.getChildElements())
            if (c.getName().endsWith(suffix)) return c;
        return null;
    }

    /**
     * Retrieves the integration channel code if it is active.
     *
     * This method validates the provided code against active
     * channel configuration records in Salesforce.
     *
     * @param code The expected channel code (e.g. "FIMA")
     * @return The matching channel code if active, otherwise null
     */
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

    /**
     * Writes a log message to the debug log if debugging is enabled.
     *
     * This method centralizes logging behavior and ensures that debug
     * messages are only printed when the DEBUG_LOG flag is set to true.
     * It helps control log noise and improves performance in production
     * environments by avoiding unnecessary debug statements.
     *
     * @param msg The message to be written to the debug log.
     */
    private static void log(String msg) {
        if (DEBUG_LOG) {
            System.debug(LoggingLevel.INFO, msg);
        }
    }
}