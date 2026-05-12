({
    init: function(component, event, helper) {
        var pageReference = component.get("v.pageReference");
        if (pageReference && pageReference.state && pageReference.state.c__recordId) {
            component.set("v.recordId", pageReference.state.c__recordId);
        }
        helper.loadRecordName(component);
    },

    handleEdit: function(component, event, helper) {
        component.set("v.isEditMode", true);
        var detailCmp = component.find("detailComponent");
        if (detailCmp) {
            detailCmp.set("v.isEditMode", true);
        }
    },

    handleSaveSuccess: function(component, event, helper) {
        component.set("v.isEditMode", false);
        helper.loadRecordName(component);
    },

    handleCancelEdit: function(component, event, helper) {
        component.set("v.isEditMode", false);
    }
})
