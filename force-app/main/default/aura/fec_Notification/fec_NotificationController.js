({
  doInit: function (component, event, helper) {
    //get record type Id
    var recordTypeId = component.get("v.pageReference").state.recordTypeId;

    component.set("v.selectedRecordTypeId", recordTypeId);
  }
});