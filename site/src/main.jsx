import { createRoot } from 'react-dom/client';
import App from './App.jsx';
import './styles.css';
import siteChatUrl from './site-chat.js?url';

// Site chat widget (Phase 3). The tunnel endpoint is temporary, so it lives
// in this one constant only; the widget file itself is loaded verbatim and
// reads the endpoint and site slug from the script tag's data attributes.
const CHAT_ENDPOINT = 'https://creations-gary-rules-richmond.trycloudflare.com/chat';
const CHAT_SITE = 'r-credit-fairness-lab';

function loadSiteChat() {
  if (document.querySelector('script[data-site-chat]')) return;
  const script = document.createElement('script');
  script.src = siteChatUrl;
  script.dataset.endpoint = CHAT_ENDPOINT;
  script.dataset.site = CHAT_SITE;
  script.setAttribute('data-site-chat', '');
  document.body.appendChild(script);
}

createRoot(document.getElementById('root')).render(<App />);

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', loadSiteChat);
} else {
  loadSiteChat();
}
