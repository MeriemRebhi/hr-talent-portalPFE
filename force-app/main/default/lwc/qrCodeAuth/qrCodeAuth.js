
import { LightningElement, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import QRCodeLib from '@salesforce/resourceUrl/QRCode';
import generateQrToken from '@salesforce/apex/QrLoginController.generateQrToken';
import checkQrTokenValidated from '@salesforce/apex/QrLoginController.checkQrTokenValidated';

export default class QrCodeAuth extends LightningElement {
    @track qrCodeValue = '';
    @track isValidated = false;
    qrLibLoaded = false;
    token = '';
    pollingInterval;

    connectedCallback() {
        generateQrToken()
            .then(token => {
                this.token = token;
                // Mets ici l'URL de validation mobile (à personnaliser)
                this.qrCodeValue = 'https://tonsite.com/qr-login?token=' + token;
                this.startPolling();
            });
    }

    renderedCallback() {
        if (this.qrLibLoaded || !this.qrCodeValue) {
            this.generateQrCode();
            return;
        }
        loadScript(this, QRCodeLib)
            .then(() => {
                this.qrLibLoaded = true;
                this.generateQrCode();
            })
            .catch(() => {
                this.template.querySelector('.qr-instructions').innerHTML = '<span style="color:red">Librairie QRCode non chargée</span>';
            });
    }

    generateQrCode() {
        if (!window.QRCode || !this.qrCodeValue) return;
        const canvas = this.template.querySelector('.qr-canvas');
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        new window.QRCode(canvas, {
            text: this.qrCodeValue,
            width: 180,
            height: 180,
        });
    }

    startPolling() {
        this.pollingInterval = setInterval(() => {
            checkQrTokenValidated({ token: this.token })
                .then(validated => {
                    if (validated) {
                        this.isValidated = true;
                        clearInterval(this.pollingInterval);
                    }
                });
        }, 2000);
    }

    disconnectedCallback() {
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
        }
    }
}
