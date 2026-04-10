import { LightningElement, track } from 'lwc';
import validateToken from '@salesforce/apex/PasswordResetController.validateToken';
import setPasswordWithToken from '@salesforce/apex/PasswordResetController.setPasswordWithToken';
import validatePasswordStrength from '@salesforce/apex/PasswordResetController.validatePasswordStrength';

export default class SetPassword extends LightningElement {
    @track isLoading = true;
    @track showError = false;
    @track showForm = false;
    @track showSuccess = false;
    @track errorMessage = '';
    @track userEmail = '';
    @track formError = '';
    @track newPassword = '';
    @track confirmPassword = '';
    @track isSubmitting = false;
    @track showPasswordText = false;

    // Strength tracking
    @track has8Chars = false;
    @track hasUpper = false;
    @track hasLower = false;
    @track hasDigit = false;
    @track hasSpecial = false;

    _token = null;
    _basePath = '';

    connectedCallback() {
        const path = window.location.pathname;
        const sIndex = path.indexOf('/s/');
        this._basePath = sIndex > 0 ? path.substring(0, sIndex) : '';
        this._token = this.getUrlParam('token');
        if (!this._token) {
            this.showErrorState('Aucun token fourni dans le lien.');
            return;
        }
        this.doValidateToken();
    }

    getUrlParam(name) {
        const urlParams = new URLSearchParams(window.location.search);
        return urlParams.get(name);
    }

    doValidateToken() {
        validateToken({ token: this._token })
            .then(result => {
                this.isLoading = false;
                if (result.status === 'OK') {
                    this.userEmail = result.email;
                    this.showForm = true;
                } else {
                    this.showErrorState(result.message);
                }
            })
            .catch(err => {
                this.isLoading = false;
                this.showErrorState(err.body ? err.body.message : 'Erreur de validation du lien.');
            });
    }

    showErrorState(message) {
        this.isLoading = false;
        this.showError = true;
        this.errorMessage = message;
    }

    // ═══ PASSWORD INPUT HANDLING ═══

    handleNewPasswordInput(event) {
        this.newPassword = event.target.value;
        this.formError = '';
        this.evaluateStrength();
    }

    handleConfirmPasswordInput(event) {
        this.confirmPassword = event.target.value;
        this.formError = '';
    }

    get loginUrl() {
        return this._basePath + '/s/loginp';
    }

    get homeUrl() {
        return this._basePath + '/s/';
    }

    togglePasswordVisibility() {
        this.showPasswordText = !this.showPasswordText;
    }

    get passwordFieldType() {
        return this.showPasswordText ? 'text' : 'password';
    }

    // ═══ STRENGTH EVALUATION ═══

    evaluateStrength() {
        const pwd = this.newPassword;
        this.has8Chars = pwd.length >= 8;
        this.hasUpper = /[A-Z]/.test(pwd);
        this.hasLower = /[a-z]/.test(pwd);
        this.hasDigit = /[0-9]/.test(pwd);
        this.hasSpecial = /[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]/.test(pwd);
    }

    get strengthScore() {
        let score = 0;
        if (this.has8Chars) score++;
        if (this.hasUpper) score++;
        if (this.hasLower) score++;
        if (this.hasDigit) score++;
        if (this.hasSpecial) score++;
        return score;
    }

    get strengthLabel() {
        if (!this.newPassword) return '';
        const s = this.strengthScore;
        if (s <= 2) return 'Faible';
        if (s <= 3) return 'Moyen';
        if (s <= 4) return 'Fort';
        return 'Excellent';
    }

    get strengthLabelClass() {
        const s = this.strengthScore;
        if (s <= 2) return 'strength-label weak';
        if (s <= 3) return 'strength-label medium';
        if (s <= 4) return 'strength-label strong';
        return 'strength-label excellent';
    }

    get strengthBarClass() {
        return 'strength-bar';
    }

    get strengthBarStyle() {
        const pct = (this.strengthScore / 5) * 100;
        const s = this.strengthScore;
        let color = '#ef4444';
        if (s >= 5) color = '#059669';
        else if (s >= 4) color = '#2F7D59';
        else if (s >= 3) color = '#f59e0b';
        return 'width:' + pct + '%;background:' + color;
    }

    get rule8CharsClass() { return this.has8Chars ? 'rule valid' : 'rule'; }
    get ruleUpperClass() { return this.hasUpper ? 'rule valid' : 'rule'; }
    get ruleLowerClass() { return this.hasLower ? 'rule valid' : 'rule'; }
    get ruleDigitClass() { return this.hasDigit ? 'rule valid' : 'rule'; }
    get ruleSpecialClass() { return this.hasSpecial ? 'rule valid' : 'rule'; }

    get passwordMismatch() {
        return this.confirmPassword.length > 0 && this.newPassword !== this.confirmPassword;
    }

    get isSubmitDisabled() {
        return this.isSubmitting || this.strengthScore < 5 || this.passwordMismatch || !this.confirmPassword;
    }

    // ═══ SUBMIT ═══

    handleSubmit(event) {
        event.preventDefault();
        if (this.isSubmitDisabled) return;

        this.formError = '';
        this.isSubmitting = true;

        setPasswordWithToken({ token: this._token, newPassword: this.newPassword })
            .then(() => {
                this.showForm = false;
                this.showSuccess = true;
            })
            .catch(err => {
                this.isSubmitting = false;
                this.formError = err.body ? err.body.message : 'Erreur lors de la mise à jour du mot de passe.';
            });
    }
}
