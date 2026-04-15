({
    doInit: function(component, event, helper) {
        var recordId = component.get('v.recordId');

        if (!recordId) {
            var url = window.location.href;
            var caseMatch = url.match(new RegExp('/r/Case/([a-zA-Z0-9]{15,18})/'));
            if (caseMatch) {
                recordId = caseMatch[1];
            } else {
                var refMatch = url.match(new RegExp('inContextOfRef=([^&]+)'));
                if (refMatch) {
                    try {
                        var dec = decodeURIComponent(refMatch[1]);
                        // Format: "1.{base64}" hoặc thuần base64
                        var b64 = dec.indexOf('.') !== -1 ? dec.substring(dec.indexOf('.') + 1) : dec;
                        // Pad base64 nếu cần
                        while (b64.length % 4 !== 0) { b64 += '='; }
                        var obj = JSON.parse(atob(b64));
                        recordId = (obj.attributes && obj.attributes.recordId)
                                || (obj.state && obj.state.recordId)
                                || obj.recordId;
                    } catch(e) {}
                }
            }
            if (recordId) {
                component.set('v.recordId', recordId);
            }
        }

        if (recordId) {
            var action = component.get('c.getCaseById');
            action.setParams({ caseId: recordId });
            action.setCallback(this, function(res) {
                if (res.getState() === 'SUCCESS' && res.getReturnValue()) {
                    var data = res.getReturnValue();
                    component.set('v.selectedId', data.id);
                    component.set('v.selectedLabel', data.label);
                }
            });
            $A.enqueueAction(action);
        }
    },

    handleInput: function(component, event, helper) {
        var term = event.target.value;
        component.set('v.searchTerm', term);
        if (term.length < 2) {
            component.set('v.results', []);
            component.set('v.isOpen', false);
            return;
        }
        component.set('v.isLoading', true);
        component.set('v.isOpen', true);
        helper.searchDebounced(component, term);
    },

    handleFocus: function(component, event, helper) {
        if (component.get('v.searchTerm').length >= 2) {
            component.set('v.isOpen', true);
        }
    },

    handleBlur: function(component, event, helper) {
        window.setTimeout($A.getCallback(function() {
            component.set('v.isOpen', false);
        }), 300);
    },

    handleSelect: function(component, event, helper) {
        var id = event.currentTarget.dataset.id;
        var label = event.currentTarget.dataset.label;
        component.set('v.selectedId', id);
        component.set('v.selectedLabel', label);
        component.set('v.isOpen', false);
        component.set('v.errorMsg', '');
    },

    handleRemove: function(component, event, helper) {
        component.set('v.selectedId', '');
        component.set('v.selectedLabel', '');
        component.set('v.searchTerm', '');
        component.set('v.results', []);
    },

    handleCancel: function(component, event, helper) {
        helper.closeOrNavigate(component);
    },

    handleSave: function(component, event, helper) {
        helper.save(component, false);
    },

    handleSaveNew: function(component, event, helper) {
        helper.save(component, true);
    }
})
