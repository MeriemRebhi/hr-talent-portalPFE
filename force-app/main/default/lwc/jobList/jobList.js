import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getJobPostings from '@salesforce/apex/JobPostingController.getJobPostings';

export default class JobList extends NavigationMixin(LightningElement) {

    @track jobs = [];
    @track allJobs = [];
    @track errorMessage = '';
    @track isLoading = true;
    @track showDetailModal = false;
    @track selectedJob = null;
    @track showApplicationForm = false;
    @track selectedJobId = null;

    connectedCallback() {
        this.loadJobs();
    }

    async loadJobs() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const result = await getJobPostings();
            this.jobs = result || [];
            this.allJobs = result || [];
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message)
                ? e.body.message
                : 'Erreur lors du chargement des offres.';
        } finally {
            this.isLoading = false;
        }
    }

    handleFilter(event) {
        const { keyword, localisation, contrat } = event.detail;

        this.jobs = this.allJobs.filter(job => {
            const matchKeyword = !keyword ||
                (job.Name && job.Name.toLowerCase().includes(keyword)) ||
                (job.Description_Poste__c && job.Description_Poste__c.toLowerCase().includes(keyword));

            const matchLocalisation = !localisation ||
                (job.Localisation__c && job.Localisation__c === localisation);

            const matchContrat = !contrat ||
                (job.Type_de_Contrat__c && job.Type_de_Contrat__c === contrat);

            return matchKeyword && matchLocalisation && matchContrat;
        });
    }

    handleSeeMore(event) {
        const jobId = event.currentTarget.dataset.id;
        this.selectedJob = this.allJobs.find(job => job.Id === jobId);
        this.showDetailModal = true;
    }

    closeDetailModal() {
        this.showDetailModal = false;
        this.selectedJob = null;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleApply(event) {
        const jobId = event.currentTarget.dataset.id;
        this.selectedJobId = jobId;
        this.showApplicationForm = true;
    }

    handleApplyFromModal(event) {
        const jobId = event.currentTarget.dataset.id;
        this.selectedJobId = jobId;
        this.closeDetailModal();
        this.showApplicationForm = true;
    }

    closeApplicationForm() {
        this.showApplicationForm = false;
        this.selectedJobId = null;
    }
}