import { LightningElement, api, track } from 'lwc';

export default class JobFilter extends LightningElement {

    @api totalResults = 0;

    @track keyword = '';
    @track localisation = '';
    @track contrat = '';

    get resultsLabel() {
        return this.totalResults + ' offre(s) trouvée(s)';
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

    handleReset() {
        this.keyword = '';
        this.localisation = '';
        this.contrat = '';

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
                contrat: this.contrat
            }
        }));
    }
}