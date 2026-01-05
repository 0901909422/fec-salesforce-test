import { LightningElement, api, track } from 'lwc';

/**
 * fec_c360Info
 * Component for displaying Case/Customer 360 information, reusable based on input 'type'.
 * @created    : 2025/12/03 long.nguyen.50
 * @modified   : 
 */
export default class FecC360Info extends LightningElement {
    // Quy ước: Component dùng chung cần chú ý đặt input param
    @api type = 'Interaction'; // Input Param: Type, default value = Interaction
    @api recordId;             // Input Param: Case/Record ID
    
    // Giả định các trường sẽ được hiển thị
    @track customerData = {
        interactionChannel: 'Zalo',
        externalId: '02fb2871-651e-4e4f-bfe8-7fd615f37dce0',
        nationalId: '123456789',
        kycStatus: 'KYCED'
    };

    // Logic kiểm tra hiển thị (tương tự logic Page Search)
    get isVisible() {
        // Comment: Nếu type là Search và chưa có data (recordId), component sẽ ẩn.
        // Nếu type là Interaction, component luôn hiển thị.
        if (this.type === 'Search' && !this.recordId) {
            return false;
        }
        return true;
    }
}