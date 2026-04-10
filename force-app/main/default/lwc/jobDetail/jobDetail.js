import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getJobPosting from '@salesforce/apex/JobPostingController.getJobPosting';

export default class JobDetail extends NavigationMixin(LightningElement) {
    @api jobId;
    
    @track job = null;
    @track errorMessage = '';
    @track isLoading = true;

    connectedCallback() {
        this.loadJobDetails();
    }

    async loadJobDetails() {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            if (this.jobId) {
                const result = await getJobPosting({ jobId: this.jobId });
                this.job = result;
            }
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message)
                ? e.body.message
                : 'Erreur lors du chargement du détail de l\'offre.';
            console.error('getJobPosting error', e);
        } finally {
            this.isLoading = false;
        }
    }

    handleApply() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'postuler__c'
            },
            state: {
                jobId: this.jobId
            }
        });
    }

    handleGoBack() {
        window.history.back();
    }

    get isLoadingClass() {
        return this.isLoading ? 'show' : '';
    }
}
