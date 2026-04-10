import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class Header extends NavigationMixin(LightningElement) {

    @track mobileMenuOpen = false;

    handleLogoClick() {
        this.mobileMenuOpen = false;
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'home' }
        });
    }

    handleJobsClick() {
        this.mobileMenuOpen = false;
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'offres__c' }
        });
    }

    handleApplyClick() {
        this.mobileMenuOpen = false;
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'offres__c' }
        });
    }

    handleContactClick() {
        this.mobileMenuOpen = false;
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'contact__c' }
        });
    }

    handleProfileClick() {
        window.dispatchEvent(new CustomEvent('open-login-modal'));
    }

    toggleMobileMenu() {
        this.mobileMenuOpen = !this.mobileMenuOpen;
    }
}