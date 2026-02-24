import { LightningElement } from 'lwc';
import LightningConfirm from 'lightning/confirm';
import LightningAlert from 'lightning/alert';
import { showLog } from 'c/fecMDMUtils';

export default class FecMasterData extends LightningElement {
    selectedItem = {};
    clickedButtonLabel;

    handleItemSelect(event) {
        if (event.detail && event.detail.name) {
            this.selectedItem = event.detail; // object chứa id, type, name, label,...
            showLog('MasterData nhận item từ Tree:', this.selectedItem);
        } else {
            // Reset to default if no valid item selected
            this.selectedItem = {};
        }
    }

    handleRefreshTree(event) {
        console.log('MasterData nhận lệnh refresh từ Detail');

        // Tìm đến component Tree và gọi hàm refresh công khai của nó
        const treeComp = this.template.querySelector('c-fec-nature-of-case-tree');
        if (treeComp) {
            treeComp.refreshTreeData(); // Chúng ta sẽ định nghĩa hàm này ở bước 5
        }
    }

    async handleClick(event) {
        const result = await LightningConfirm.open({
            message: 'Do you want to save your new update? \n Attention: Affter saving, all new items wont be deleted ?',
            variant: 'headerless',
            label: 'Attention: Affter saving, all new items wont be deleted ?',
            // setting theme would have no effect
        });

        if (result) {
            await LightningAlert.open({
                message: 'Master data save success.',
                theme: 'success', // a red theme intended for error states
                label: 'Success!', // this is the header text
            });
        } else {
            await LightningAlert.open({
                message: 'Master data save fail.',
                theme: 'error', // a red theme intended for error states
                label: 'Error!', // this is the header text
            });
        }
    }
}