
import { LightningElement, track, api } from 'lwc';
import generateQrToken from '@salesforce/apex/QrLoginController.generateQrToken';
import checkQrTokenValidated from '@salesforce/apex/QrLoginController.checkQrTokenValidated';
import validateQrToken from '@salesforce/apex/QrLoginController.validateQrToken';

export default class QrCodeAuth extends LightningElement {
    @track qrImageUrl = '';
    @track isValidated = false;
    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';
    @track isExpired = false;
    @track isValidatingMobile = false;
    @track mobileValidationSuccess = false;

    token = '';
    pollingInterval;
    expirationTimeout;

    connectedCallback() {
        // Vérifier si on est en mode validation mobile (paramètre qrtoken dans l'URL)
        const urlParams = new URLSearchParams(window.location.search);
        const qrtoken = urlParams.get('qrtoken');

        if (qrtoken) {
            this.handleMobileValidation(qrtoken);
        } else {
            this.generateNewQrCode();
        }
    }

    /**
     * Mode mobile : validation du token QR scanné
     */
    handleMobileValidation(qrtoken) {
        this.isValidatingMobile = true;
        this.isLoading = true;

        validateQrToken({ token: qrtoken })
            .then(result => {
                this.isLoading = false;
                if (result) {
                    this.mobileValidationSuccess = true;
                } else {
                    this.hasError = true;
                    this.errorMessage = 'QR code expiré ou déjà utilisé. Veuillez en générer un nouveau.';
                }
            })
            .catch(() => {
                this.isLoading = false;
                this.hasError = true;
                this.errorMessage = 'Erreur lors de la validation du QR code.';
            });
    }

    /**
     * Mode desktop : génération et affichage du QR code
     */
    generateNewQrCode() {
        this.isLoading = true;
        this.hasError = false;
        this.isValidated = false;
        this.isExpired = false;
        this.qrImageUrl = '';

        // Nettoyer le polling précédent
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
        }
        if (this.expirationTimeout) {
            clearTimeout(this.expirationTimeout);
        }

        generateQrToken()
            .then(token => {
                this.token = token;
                this.isLoading = false;

                // Construire l'URL de validation pour le mobile
                const origin = window.location.origin;
                const path = window.location.pathname;
                const sIndex = path.indexOf('/s/');
                const communityPath = sIndex > 0 ? path.substring(0, sIndex) : '';
                const validationUrl = origin + communityPath + '/s/loginp?qrtoken=' + token;

                // Générer l'image QR via API externe
                const encodedUrl = encodeURIComponent(validationUrl);
                this.qrImageUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&margin=8&data=' + encodedUrl;

                // Démarrer le polling pour détecter la validation mobile
                this.startPolling();

                // Timer d'expiration (5 minutes)
                this.expirationTimeout = setTimeout(() => {
                    this.handleExpiration();
                }, 5 * 60 * 1000);
            })
            .catch(err => {
                this.isLoading = false;
                this.hasError = true;
                this.errorMessage = 'Impossible de générer le QR code. Réessayez.';
                console.error('QR generation error:', err);
            });
    }

    /**
     * Polling toutes les 2 secondes pour vérifier la validation côté mobile
     */
    startPolling() {
        this.pollingInterval = setInterval(() => {
            if (!this.token || this.isValidated || this.isExpired) {
                clearInterval(this.pollingInterval);
                return;
            }

            checkQrTokenValidated({ token: this.token })
                .then(validated => {
                    if (validated) {
                        this.isValidated = true;
                        clearInterval(this.pollingInterval);
                        if (this.expirationTimeout) {
                            clearTimeout(this.expirationTimeout);
                        }

                        // Notifier le composant parent (loginPage)
                        this.dispatchEvent(new CustomEvent('qrvalidated', {
                            bubbles: true,
                            composed: true
                        }));

                        // Rediriger vers le dashboard après 1.5 secondes
                        // eslint-disable-next-line @lwc/lwc/no-async-operation
                        setTimeout(() => {
                            const origin = window.location.origin;
                            const path = window.location.pathname;
                            const sIndex = path.indexOf('/s/');
                            const communityPath = sIndex > 0 ? path.substring(0, sIndex) : '';
                            window.location.href = origin + communityPath + '/s/dashboard';
                        }, 1500);
                    }
                })
                .catch(() => {
                    // Ignorer les erreurs de polling (réseau temporaire)
                });
        }, 2000);
    }

    /**
     * Gestion de l'expiration du QR code (5 minutes)
     */
    handleExpiration() {
        this.isExpired = true;
        this.qrImageUrl = '';
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
        }
    }

    /**
     * Régénérer un nouveau QR code (bouton)
     */
    handleRegenerate() {
        this.generateNewQrCode();
    }

    disconnectedCallback() {
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
        }
        if (this.expirationTimeout) {
            clearTimeout(this.expirationTimeout);
        }
    }

    get showQrCode() {
        return !this.isLoading && !this.hasError && !this.isValidated && !this.isExpired
               && !this.isValidatingMobile && this.qrImageUrl;
    }

    get showDesktopMode() {
        return !this.isValidatingMobile;
    }
}
