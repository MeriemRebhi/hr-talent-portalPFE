import { LightningElement, track } from 'lwc';
import sendPortalResetEmail from '@salesforce/apex/RegistrationController.sendPortalResetEmail';

export default class RegistrationForm extends LightningElement {
    @track email = '';
    @track success = false;
    @track error = '';

    handleEmailChange(event) {
        this.email = event.target.value;
    }

    handleSubmit(event) {
        event.preventDefault();
        this.success = false;
        this.error = '';
        sendPortalResetEmail({ email: this.email })
            .then(() => {
                this.success = true;
            })
            .catch(error => {
                this.error = error.body && error.body.message ? error.body.message : 'Erreur lors de l’envoi de l’email.';
            });
    }
}
