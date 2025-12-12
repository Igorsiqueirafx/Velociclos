// Sistema de checkout com Stripe (simulado)
class StripeCheckout {
    constructor() {
        this.init();
    }

    init() {
        this.setupCheckoutButtons();
    }

    setupCheckoutButtons() {
        this.removeExistingListeners(); // Prevenir duplicatas
        const buyButtons = document.querySelectorAll('[data-product-id]');
        buyButtons.forEach(button => {
            button.addEventListener('click', (e) => {
                e.preventDefault();
                const productId = button.dataset.productId;
                this.startCheckout(productId);
            });
        });
    }

    startCheckout(productId) {
        // Simulação de checkout
        if (window.showToast) {
            window.showToast('Redirecionando para checkout...', 'info');
        }

        // Simular processamento
        setTimeout(() => {
            alert(`Checkout simulado para: ${productId}\n\nEm produção, isso redirecionaria para Stripe Checkout.`);

            if (window.showToast) {
                window.showToast('Compra processada com sucesso!', 'success');
            }
        }, 2000);
    }

    // Método para integração real com Stripe
    createCheckoutSession(productId) {
        // Aqui seria a integração real com Stripe
        // Log apenas em desenvolvimento
                if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
                    console.log('Criando sessão de checkout para:', productId);
                }

        // Exemplo de como seria:
        /*
        fetch('/api/create-checkout-session', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ productId })
        })
        .then(response => response.json())
        .then(session => {
            // Redirecionar para Stripe
            window.location.href = session.url;
        });
        */
    }
}

// Inicializar checkout
document.addEventListener('DOMContentLoaded', () => {
    new StripeCheckout();
});