import { LightningElement, track } from 'lwc';

const POPULAR_TAGS = [
    'Développeur', 'Marketing', 'Stage', 'CDI', 'Salesforce', 'RH', 'Télétravail'
];

const ALL_SUGGESTIONS = [
    'Développeur Full Stack',
    'Chef de projet',
    'Data Analyst',
    'Salesforce Admin',
    'Marketing Digital',
    'Stage RH',
    'Télétravail',
    'CDI',
    'CDD',
    'Alternance',
    'Product Owner',
    'UX Designer'
];

export default class SearchBar extends LightningElement {
    @track searchTerm = '';
    @track suggestions = [];
    @track showSuggestions = false;
    @track showTags = true;
    tags = POPULAR_TAGS;

    handleInput(event) {
        this.searchTerm = event.target.value;
        if (this.searchTerm.length > 0) {
            const term = this.searchTerm.toLowerCase();
            this.suggestions = ALL_SUGGESTIONS.filter(s =>
                s.toLowerCase().includes(term)
            ).slice(0, 6);
            this.showSuggestions = this.suggestions.length > 0;
            this.showTags = false;
        } else {
            this.showSuggestions = false;
            this.showTags = true;
        }
    }

    handleKeydown(event) {
        if (event.key === 'Enter') {
            this.showSuggestions = false;
            this.fireSearch();
        }
        if (event.key === 'Escape') {
            this.showSuggestions = false;
        }
    }

    handleBlur() {
        // Small delay to allow suggestion click to register
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showSuggestions = false; }, 200);
    }

    handleSuggestionClick(event) {
        this.searchTerm = event.currentTarget.textContent.trim();
        this.showSuggestions = false;
        this.showTags = false;
        this.fireSearch();
    }

    handleTagClick(event) {
        this.searchTerm = event.currentTarget.textContent.trim();
        this.showTags = false;
        this.fireSearch();
    }

    handleClear() {
        this.searchTerm = '';
        this.showSuggestions = false;
        this.showTags = true;
        this.fireSearch();
    }

    handleSearch() {
        this.showSuggestions = false;
        this.fireSearch();
    }

    fireSearch() {
        this.dispatchEvent(new CustomEvent('search', {
            detail: { term: this.searchTerm },
            bubbles: true,
            composed: true
        }));
    }
}
