import { LightningElement, track, api } from 'lwc';
import login from '@salesforce/apex/QrLoginController.loginWithCredentials';

export default class LoginPage extends LightningElement {
    @api isStandalonePage = false;
    handlerRef = null;

    /** True si on est en mode validation QR mobile (paramètre ?qrtoken=xxx dans l'URL) */
    @track isQrMobileValidation = false;

    connectedCallback() {
        this.handlerRef = this.handleOpenModal.bind(this);
        window.addEventListener('open-login-modal', this.handlerRef);

        // Détecter si on est sur la page /loginp
        if (window.location.pathname.toLowerCase().includes('loginp')) {
            this.isStandalonePage = true;
        }

        // Détecter si on est en mode validation QR mobile
        const urlParams = new URLSearchParams(window.location.search);
        if (urlParams.get('qrtoken')) {
            this.isQrMobileValidation = true;
            this.isStandalonePage = true;
        }
    }

    disconnectedCallback() {
        if (this.handlerRef) {
            window.removeEventListener('open-login-modal', this.handlerRef);
        }
    }

    handleOpenModal() {
        this.open();
    }
    @track email = '';
    @track password = '';
    @track showModal = false;
    @track errorMsg = '';
    @track isLoggingIn = false;


    @api open() {
        this.showModal = true;
        document.body.classList.add('modal-open');
    }

    @api close() {
        this.showModal = false;
        document.body.classList.remove('modal-open');
    }

    handleBackdropClick(event) {
        if (event.target.classList.contains('modal-backdrop')) {
            this.close();
        }
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleEmailChange(event) {
        this.email = event.target.value;
    }

    handlePasswordChange(event) {
        this.password = event.target.value;
    }

    get communityBasePath() {
        const path = window.location.pathname;
        const sIndex = path.indexOf('/s/');
        return sIndex > 0 ? path.substring(0, sIndex) : '';
    }

    get resetPasswordUrl() {
        return this.communityBasePath + '/s/reset-mot-de-passe';
    }

    handleSubmit(event) {
        event.preventDefault();
        if (this.isLoggingIn) return;
        this.errorMsg = '';
        this.isLoggingIn = true;

        login({ username: this.email, password: this.password })
            .then(result => {
                if (result && result.startsWith('http')) {
                    window.location.href = result;
                } else {
                    const baseUrl = window.location.origin;
                    const communityPath = window.location.pathname.split('/s/')[0];
                    window.location.href = baseUrl + communityPath + '/s/dashboard';
                }
            })
            .catch(err => {
                this.isLoggingIn = false;
                this.errorMsg = err.body ? err.body.message : 'Email ou mot de passe incorrect.';
            });
    }

}
