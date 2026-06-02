({
    _timer: null,

    closeOrNavigate: function(component) {
        var recordId = component.get('v.recordId');
        // Khi mở dạng tab (actionOverride), navigate về /lightning/r/Case/{id}/view
        if (recordId) {
            try {
                var navEvt = $A.get('e.force:navigateToURL');
                if (navEvt) {
                    navEvt.setParams({ url: '/lightning/r/Case/' + recordId + '/view' });
                    navEvt.fire();
                    return;
                }
            } catch(e) {}
        }
        window.history.back();
    },

    searchDebounced: function(component, term) {
        var self = this;
        if (self._timer) clearTimeout(self._timer);
        self._timer = setTimeout($A.getCallback(function() {
            var action = component.get('c.searchCases');
            action.setParams({ searchTerm: term });
            action.setCallback(this, function(res) {
                component.set('v.isLoading', false);
                if (res.getState() === 'SUCCESS') {
                    component.set('v.results', res.getReturnValue());
                }
            });
            $A.enqueueAction(action);
        }), 300);
    },

    save: function(component, saveAndNew) {
        var selectedId = component.get('v.selectedId');
        if (!selectedId) {
            component.set('v.errorMsg', $A.get('$Label.c.FEC_RelevantTicket_Select_Required'));
            return;
        }

        // Đảm bảo recordId luôn có giá trị
        var recordId = component.get('v.recordId');
        if (!recordId) {
            var url = window.location.href;
            console.log('[FEC_DEBUG] save url=' + url);
            var m = url.match(new RegExp('/r/Case/([a-zA-Z0-9]{15,18})/'));
            if (m) {
                recordId = m[1];
            } else {
                // tungnm37: thử parse inContextOfRef
                var ref = url.match(new RegExp('inContextOfRef=([^&]+)'));
                if (ref) {
                    try {
                        var dec = decodeURIComponent(ref[1]);
                        var b64 = dec.indexOf('.') !== -1 ? dec.substring(dec.indexOf('.') + 1) : dec;
                        while (b64.length % 4 !== 0) { b64 += '='; }
                        var obj = JSON.parse(atob(b64));
                        console.log('[FEC_DEBUG] inContextOfRef parsed=' + JSON.stringify(obj));
                        recordId = (obj.attributes && obj.attributes.recordId)
                                || (obj.state && obj.state.recordId)
                                || obj.recordId;
                    } catch(e) { console.log('[FEC_DEBUG] inContextOfRef parse error=' + e); }
                }
                // tungnm37: thử parse recordId trực tiếp từ URL params
                if (!recordId) {
                    var ridMatch = url.match(new RegExp('[?&]recordId=([a-zA-Z0-9]{15,18})'));
                    if (ridMatch) recordId = ridMatch[1];
                }
                // tungnm37: thử parse từ navigationContext
                if (!recordId) {
                    try {
                        var navCtx = url.match(new RegExp('navigationContext=([^&]+)'));
                        if (navCtx) {
                            var navDec = decodeURIComponent(navCtx[1]);
                            var navObj = JSON.parse(navDec);
                            console.log('[FEC_DEBUG] navigationContext=' + JSON.stringify(navObj));
                            recordId = navObj.recordId || (navObj.attributes && navObj.attributes.recordId);
                        }
                    } catch(e2) {}
                }
            }
            if (recordId) {
                component.set('v.recordId', recordId);
            }
        }

        if (!recordId) {
            component.set('v.errorMsg', $A.get('$Label.c.FEC_RelevantTicket_Case_Not_Found'));
            return;
        }

        component.set('v.isSaving', true);
        component.set('v.errorMsg', '');

        var action = component.get('c.createRelevantTicket');
        action.setParams({
            interactionId: selectedId,
            relatedToId: recordId
        });
        action.setCallback(this, function(res) {
            component.set('v.isSaving', false);
            if (res.getState() === 'SUCCESS') {
                // Toast success
                try {
                    var toast = $A.get('e.force:showToast');
                    if (toast) {
                        toast.setParams({
                            title: $A.get('$Label.c.FEC_Button_Save'),
                            message: $A.get('$Label.c.FEC_RelevantTicket_Save_Success'),
                            type: 'success',
                            duration: 4000
                        });
                        toast.fire();
                    }
                } catch(te) {}
                // Refresh parent record page/list immediately so newly linked ticket appears without manual reload
                try {
                    var refreshEvt = $A.get('e.force:refreshView');
                    if (refreshEvt) {
                        refreshEvt.fire();
                    }
                } catch(re) {}
                if (saveAndNew) {
                    component.set('v.selectedId', '');
                    component.set('v.selectedLabel', '');
                    component.set('v.searchTerm', '');
                    component.set('v.results', []);
                    component.set('v.errorMsg', '');
                    window.setTimeout($A.getCallback(function() {
                        try {
                            var refreshEvt2 = $A.get('e.force:refreshView');
                            if (refreshEvt2) {
                                refreshEvt2.fire();
                            }
                        } catch(re2) {}
                    }), 300);
                } else {
                    window.setTimeout($A.getCallback(function() {
                        try {
                            var refreshEvt2 = $A.get('e.force:refreshView');
                            if (refreshEvt2) {
                                refreshEvt2.fire();
                            }
                        } catch(re2) {}
                        this.closeOrNavigate(component);
                    }.bind(this)), 500);
                }
            } else {
                var errors = res.getError();
                var msg = $A.get('$Label.c.FEC_RelevantTicket_Save_Error');
                if (errors && errors[0]) {
                    if (errors[0].pageErrors && errors[0].pageErrors.length > 0) {
                        msg = errors[0].pageErrors[0].message;
                    } else if (errors[0].fieldErrors) {
                        var fe = errors[0].fieldErrors;
                        var keys = Object.keys(fe);
                        if (keys.length > 0 && fe[keys[0]].length > 0) {
                            msg = fe[keys[0]][0].message;
                        }
                    } else if (errors[0].message) {
                        msg = errors[0].message;
                    }
                }
                component.set('v.errorMsg', msg);
            }
        });
        $A.enqueueAction(action);
    }
})