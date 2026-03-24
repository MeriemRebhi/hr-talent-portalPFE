import { LightningElement, track, api } from 'lwc';

export default class LoginPage extends LightningElement {
    handlerRef = null;

    connectedCallback() {
        this.handlerRef = this.handleOpenModal.bind(this);
        window.addEventListener('open-login-modal', this.handlerRef);
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
    @track showModal = false; // Affiche la modale uniquement sur clic

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

    handleSubmit(event) {
        event.preventDefault();
        // Ici, ajoute la logique d'authentification si besoin
        this.close();
    }
}
