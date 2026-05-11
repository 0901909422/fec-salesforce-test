({
    init: function(component, event, helper) {
        var pageReference = component.get("v.pageReference");
        if (pageReference && pageReference.state && pageReference.state.c__recordId) {
            component.set("v.recordId", pageReference.state.c__recordId);
        }
        helper.loadRecordName(component);
    },

    handleEdit: function(component, event, helper) {
        var recordId = component.get("v.recordId");
        helper.publishEditMode(component, recordId);
    },

    handleSaveSuccess: function(component, event, helper) {
        var historyComponent = component.find("historyComponent");
        if (historyComponent) {
            historyComponent.refresh();
        }
        helper.loadRecordName(component);
    }
})
