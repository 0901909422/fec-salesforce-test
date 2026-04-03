({
    doInit : function(component, event, helper) {
        let pageRef = component.get("v.pageReference");
        let recordId = pageRef.attributes.recordId;
        console.log(recordId);

        component.set("v.recordId", recordId);
        helper.redirect(component, recordId);
    }
})