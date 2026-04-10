import { LightningElement, track, api } from 'lwc';
import chat from '@salesforce/apex/CandidateChatController.chat';

const WELCOME =
    'Bonjour ! Je suis l\'assistant RH de Talan.\n' +
    'Je peux vous aider avec :\n' +
    '\u2022 Le statut de vos candidatures\n' +
    '\u2022 Votre score et analyse IA\n' +
    '\u2022 Les offres disponibles\n\n' +
    'Que souhaitez-vous savoir ?';

export default class AgentforceChat extends LightningElement {
    @track isOpen = false;
    @track messages = [];
    @track isTyping = false;
    @track inputValue = '';
    @track unreadCount = 0;

    @api email = '';
    _msgId = 0;
    _greeted = false;

    connectedCallback() {}

    toggleChat() {
        this.isOpen = !this.isOpen;
        if (this.isOpen) {
            this.unreadCount = 0;
            if (!this._greeted) {
                this._greeted = true;
                this._addBotMsg(WELCOME);
            }
            this._scrollDown();
        }
    }

    handleInput(evt) { this.inputValue = evt.target.value; }

    handleKeyUp(evt) {
        if (evt.key === 'Enter' && !this.isTyping) this.sendMessage();
    }

    sendMessage() {
        const text = (this.inputValue || '').trim();
        if (!text || this.isTyping) return;
        this._addUserMsg(text);
        this.inputValue = '';
        this._callApex(text);
    }

    quickStatut() {
        this._addUserMsg('Statut de mes candidatures');
        this._callApex('Statut de mes candidatures');
    }
    quickScore() {
        this._addUserMsg('Mon score IA');
        this._callApex('Mon score IA');
    }
    quickOffres() {
        this._addUserMsg('Offres disponibles');
        this._callApex('Offres disponibles');
    }

    get isSendDisabled() {
        return !this.inputValue || !this.inputValue.trim() || this.isTyping;
    }

    _callApex(userMsg) {
        this.isTyping = true;
        this._scrollDown();
        chat({ userMessage: userMsg, userEmail: this.email || '' })
            .then(resp => {
                this.isTyping = false;
                this._addBotMsg(resp.message, resp.type === 'error');
                this._scrollDown();
            })
            .catch(() => {
                this.isTyping = false;
                this._addBotMsg('Une erreur est survenue. Veuillez reessayer.', true);
                this._scrollDown();
            });
    }

    _addBotMsg(text, isError) {
        this.messages = [...this.messages, {
            id: ++this._msgId,
            text,
            time: this._now(),
            isBot: true,
            cssClass: 'msg-row ' + (isError ? 'error' : 'bot')
        }];
        if (!this.isOpen) this.unreadCount++;
    }

    _addUserMsg(text) {
        this.messages = [...this.messages, {
            id: ++this._msgId,
            text,
            time: this._now(),
            isBot: false,
            cssClass: 'msg-row user'
        }];
    }

    _now() {
        return new Date().toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
    }

    _scrollDown() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            try {
                const el = this.template.querySelector('.chat-messages');
                if (el) el.scrollTop = el.scrollHeight;
            } catch (e) {}
        }, 60);
    }
}
