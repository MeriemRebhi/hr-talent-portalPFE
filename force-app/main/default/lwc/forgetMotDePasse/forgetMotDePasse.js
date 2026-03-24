import { LightningElement, track } from 'lwc';
import resetPassword from '@salesforce/apex/CustomPasswordResetController.resetPassword';

export default class ForgetMotDePasse extends LightningElement {
    @track email = '';
    @track success = false;
    @track error = false;
    @track errorMessage = '';

    handleEmailChange(event) {
        this.email = event.target.value;
    }

    handleSubmit(event) {
        event.preventDefault();
        this.success = false;
        this.error = false;
        this.errorMessage = '';
        resetPassword({ email: this.email })
            .then(() => {
                this.success = true;
            })
            .catch(err => {
                this.error = true;
                this.errorMessage = err.body && err.body.message ? err.body.message : 'Erreur lors de la réinitialisation.';
            });
    }
}
