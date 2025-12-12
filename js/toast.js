// Sistema de notificações toast
// import { createSafeElement, sanitizeHTML } from './utils/security.js';

class ToastManager {
    constructor() {
        this.container = null;
        this.init();
    }

    init() {
        this.createContainer();
    }

    createContainer() {
        // Verificar se já existe
        if (document.getElementById('toast-container')) return;

        this.container = document.createElement('div');
        this.container.id = 'toast-container';
        this.container.className = 'toast-container';
        document.body.appendChild(this.container);
    }

    show(message, type = 'info', duration = 5000) {
        if (!this.container) this.createContainer();

        const toast = document.createElement('div');
        toast.className = `toast ${type} show`;

        const icons = {
            success: '✓',
            error: '✕',
            warning: '⚠',
            info: 'ℹ'
        };

        // Criar elementos de forma segura
        const toastContent = document.createElement('div');
        toastContent.className = 'toast-content';

        const toastIcon = document.createElement('div');
        toastIcon.className = 'toast-icon';
        toastIcon.textContent = icons[type] || icons.info;

        const toastMessage = document.createElement('div');
        toastMessage.className = 'toast-message';
        toastMessage.textContent = message;

        const closeButton = document.createElement('button');
        closeButton.className = 'toast-close';
        closeButton.textContent = '×';
        closeButton.onclick = function() { this.parentElement.remove(); };

        toastContent.appendChild(toastIcon);
        toastContent.appendChild(toastMessage);
        toast.appendChild(toastContent);
        toast.appendChild(closeButton);

        this.container.appendChild(toast);

        // Auto-remover após duração
        setTimeout(() => {
            if (toast.parentElement) {
                toast.remove();
            }
        }, duration);

        return toast;
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    success(message, duration) {
        return this.show(message, 'success', duration);
    }

    error(message, duration) {
        return this.show(message, 'error', duration);
    }

    warning(message, duration) {
        return this.show(message, 'warning', duration);
    }

    info(message, duration) {
        return this.show(message, 'info', duration);
    }
}

// Instância global
const toast = new ToastManager();

// Função global para compatibilidade
window.showToast = (message, type, duration) => toast.show(message, type, duration);

// // Export para módulos
// export default toast;