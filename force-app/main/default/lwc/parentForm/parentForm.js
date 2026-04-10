import { LightningElement, track } from 'lwc';

export default class ParentForm extends LightningElement {
    @track isOpen = false;

    handleOpenForm() {
        this.isOpen = true;
    }

    handleCloseForm() {
        this.isOpen = false;
    }
}
