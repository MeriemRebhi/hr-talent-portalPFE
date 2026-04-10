import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class JobFilter extends NavigationMixin(LightningElement) {

    @api totalResults = 0;

    @track keyword = '';
    @track localisation = '';
    @track contrat = '';
    @track departement = '';

    get resultsLabel() {
        return this.totalResults + ' offre(s) trouvée(s)';
    }

    goHome() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'Home' }
        });
    }

    handleKeyword(event) {
        this.keyword = event.target.value;
        this.dispatchFilter();
    }

    handleLocalisation(event) {
        this.localisation = event.target.value;
        this.dispatchFilter();
    }

    handleContrat(event) {
        this.contrat = event.target.value;
        this.dispatchFilter();
    }

    handleDepartement(event) {
        this.departement = event.target.value;
        this.dispatchFilter();
    }

    handleReset() {
        this.keyword = '';
        this.localisation = '';
        this.contrat = '';
        this.departement = '';

        // Reset les inputs visuellement
        this.template.querySelectorAll('input, select')
            .forEach(el => el.value = '');

        this.dispatchFilter();
    }

    dispatchFilter() {
        this.dispatchEvent(new CustomEvent('filter', {
            detail: {
                keyword: this.keyword.toLowerCase().trim(),
                localisation: this.localisation,
                contrat: this.contrat,
                departement: this.departement
            }
        }));
    }
}