public with sharing class FEC_NatureOfCaseTreeItem {
    @AuraEnabled public String label;
    @AuraEnabled public String name;
    @AuraEnabled public String FEC_Customer_Type;
    @AuraEnabled public String NameEN;
    @AuraEnabled public String Alias;
    @AuraEnabled public String ChangeStatus;
    @AuraEnabled public String iconName;
    @AuraEnabled public String Code;
    @AuraEnabled public String nameVN;
    @AuraEnabled public String idType;
    @AuraEnabled public String id;
    @AuraEnabled public String type;
    @AuraEnabled public Decimal PosOrder;
    @AuraEnabled public Boolean Status;
    @AuraEnabled public List<FEC_NatureOfCaseTreeItem> items;

    // transient helper map used only server-side while building tree
    public transient Map<String, FEC_NatureOfCaseTreeItem> mapChilds;

    public FEC_NatureOfCaseTreeItem(String label, String name, List<FEC_NatureOfCaseTreeItem> items,
        String alias, String code, String nameVN, Decimal posOrder, Boolean status,String changeStatus,String nameEN,String idType,String FEC_Customer_Type,String id,String type) {
        this.label = label;
        this.name = name;
        this.FEC_Customer_Type = FEC_Customer_Type;
        this.items = items;
        this.Alias = alias;
        this.Code = code;
        this.nameVN = nameVN;
        this.PosOrder = posOrder;
        this.Status = status;
        this.ChangeStatus = changeStatus;
        this.nameEN = nameEN;
        this.idType = idType;
        this.id = id;
        this.type = type;
        this.mapChilds = new Map<String, FEC_NatureOfCaseTreeItem>();

        if (status == true) {
            this.iconName = FEC_UIConstants.ICON_RECORD;
        } else {
            this.iconName = FEC_UIConstants.ICON_LOCK;
        }
    }

    // Convert transient map to items list recursively
    public void convertMapToList() {
        if (this.mapChilds != null && !this.mapChilds.isEmpty()) {
            this.items = new List<FEC_NatureOfCaseTreeItem>();
            for (FEC_NatureOfCaseTreeItem child : this.mapChilds.values()) {
                child.convertMapToList();
                this.items.add(child);
            }
            this.mapChilds.clear();
        }
    }
}