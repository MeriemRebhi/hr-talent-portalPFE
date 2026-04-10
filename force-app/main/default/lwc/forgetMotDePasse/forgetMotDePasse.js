import { LightningElement, track } from 'lwc';
import resetPassword from '@salesforce/apex/CustomPasswordResetController.resetPassword';

export default class ForgetMotDePasse extends LightningElement {
    @track email = '';
    @track success = false;
    @track isLoading = false;
    @track errorMessage = '';

    get communityBasePath() {
        const path = window.location.pathname;
        const sIndex = path.indexOf('/s/');
        return sIndex > 0 ? path.substring(0, sIndex) : '';
    }

    get loginUrl() {
        return this.communityBasePath + '/s/loginp';
    }

    handleEmailChange(event) {
        this.email = event.target.value;
    }

    handleSubmit(event) {
        event.preventDefault();
        if (this.isLoading) return;
        this.isLoading = true;
        this.errorMessage = '';
        this.success = false;

        resetPassword({ email: this.email })
            .then(() => {
                this.success = true;
                this.isLoading = false;
            })
            .catch(err => {
                this.isLoading = false;
                this.errorMessage = err.body && err.body.message
                    ? err.body.message
                    : 'Erreur lors de la réinitialisation.';
            });
    }
}
