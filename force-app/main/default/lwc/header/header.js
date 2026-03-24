import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class Header extends NavigationMixin(LightningElement) {

    handleLogoClick() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'home' }
        });
    }

    handleJobsClick() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'offres__c' }
        });
    }

    handleApplicationsClick() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'mes-candidatures__c' }
        });
    }

    handleContactClick() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'contact__c' }
        });
    }

    handleProfileClick() {
        // Émet un événement global pour ouvrir la modale loginPage
        window.dispatchEvent(new CustomEvent('open-login-modal'));
    }
}