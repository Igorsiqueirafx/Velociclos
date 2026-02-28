// Sistema de checkout com Stripe (simulado)
class StripeCheckout {
  constructor() {
    this.isSandbox =
      window.location.hostname === 'localhost' ||
      window.location.hostname === '127.0.0.1';

    this.init();
  }

  init() {
    this.setupCheckoutButtons();
  }

  // Opcional: aqui você poderia remover listeners antigos, se necessário
  removeExistingListeners() {
    // Implementação futura se virar problema de duplicar eventos
  }

  setupCheckoutButtons() {
    this.removeExistingListeners();

    const buyButtons = document.querySelectorAll('[data-product-id]');

    buyButtons.forEach((button) => {
      // Evita bind duplicado em ambientes SPA
      if (button.dataset.checkoutBound === '1') return;
      button.dataset.checkoutBound = '1';

      button.addEventListener('click', (e) => {
        e.preventDefault();
        const productId = button.dataset.productId;
        this.startCheckout(productId);
      });
    });
  }

  startCheckout(productId) {
    const activeButton = document.querySelector(
      `[data-product-id="${productId}"]`
    );

    if (activeButton) {
      activeButton.disabled = true;
      activeButton.classList.add('is-loading');
    }

    const finalize = () => {
      if (activeButton) {
        activeButton.disabled = false;
        activeButton.classList.remove('is-loading');
      }
    };

    if (this.isSandbox) {
      this.fakeCheckout(productId, finalize);
    } else {
      this.createCheckoutSession(productId).finally(finalize);
    }
  }

  fakeCheckout(productId, finalize) {
    if (window.showToast) {
      window.showToast('Redirecionando para checkout...', 'info');
    }

    setTimeout(() => {
      alert(
        `Checkout simulado para: ${productId}\n\nEm produção, isso redirecionaria para Stripe Checkout.`
      );

      if (window.showToast) {
        window.showToast('Compra processada com sucesso!', 'success');
      }

      if (typeof finalize === 'function') finalize();
    }, 2000);
  }

  async createCheckoutSession(productId) {
    try {
      if (window.showToast) {
        window.showToast('Iniciando checkout...', 'info');
      }

      const res = await fetch('/api/create-checkout-session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ productId }),
      });

      if (!res.ok) {
        throw new Error('Falha ao criar sessão de checkout');
      }

      const session = await res.json();

      if (session.url) {
        window.location.href = session.url;
      } else {
        throw new Error('URL da sessão não encontrada');
      }
    } catch (err) {
      console.error(err);
      if (window.showToast) {
        window.showToast('Erro ao iniciar checkout. Tente novamente.', 'error');
      }
    }
  }
}

// Instanciar automaticamente quando o script carregar
document.addEventListener('DOMContentLoaded', () => {
  window.velociclosStripeCheckout = new StripeCheckout();
});
