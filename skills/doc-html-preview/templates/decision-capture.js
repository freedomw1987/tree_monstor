/* Decision capture JS for Hermes doc-html-preview boss version.
   Inline in boss HTML. No external assets, no libraries.
   Uses localStorage to persist user choices across sessions.
   Works on file:// in Chrome, Firefox; Safari requires user interaction first. */

(function () {
  'use strict';

  var DOC_NAME = document.body.getAttribute('data-doc') || 'unknown';
  var STORAGE_KEY = 'boss-decisions-' + DOC_NAME;

  function loadDecisions() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      return raw ? JSON.parse(raw) : {};
    } catch (e) {
      console.warn('[boss-decisions] localStorage unavailable:', e);
      return {};
    }
  }

  function saveDecisions(state) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch (e) {
      console.warn('[boss-decisions] localStorage write failed:', e);
    }
  }

  function applyExistingSelections() {
    var state = loadDecisions();
    var options = document.querySelectorAll('.boss-decision .option');
    options.forEach(function (opt) {
      var qid = opt.getAttribute('data-question-id');
      if (state[qid]) {
        if (opt.getAttribute('data-option-label') === state[qid]) {
          opt.classList.add('is-selected');
        } else {
          opt.classList.add('is-dimmed');
        }
      }
    });
  }

  function attachClickHandlers() {
    var options = document.querySelectorAll('.boss-decision .option');
    options.forEach(function (opt) {
      opt.addEventListener('click', function () {
        var qid = opt.getAttribute('data-question-id');
        var label = opt.getAttribute('data-option-label');
        var state = loadDecisions();
        state[qid] = label;
        saveDecisions(state);

        // Update visual state: clear all, then mark clicked as selected,
        // and mark other options in same question as dimmed
        var parent = opt.closest('.boss-decision');
        if (parent) {
          parent.querySelectorAll('.option').forEach(function (o) {
            o.classList.remove('is-selected', 'is-dimmed');
            o.style.opacity = '';
          });
        }
        opt.classList.add('is-selected');
        // Dim siblings in same question
        if (parent) {
          parent.querySelectorAll('.option').forEach(function (o) {
            if (o !== opt) o.classList.add('is-dimmed');
          });
        }

        renderMyDecisions();
      });
    });
  }

  function renderMyDecisions() {
    var container = document.getElementById('my-decisions');
    if (!container) return;

    var state = loadDecisions();
    var decisions = document.querySelectorAll('.boss-decision');
    var items = [];
    decisions.forEach(function (decEl, idx) {
      var qid = 'q-' + idx;
      var questionEl = decEl.querySelector('.question');
      var questionText = questionEl ? questionEl.textContent.replace(/^❓\s*/, '').trim() : '(question)';
      // Strip the "要你拍板" badge text
      questionText = questionText.replace(/要你拍板$/, '').trim();

      var selectedLabel = state[qid];
      var answerText = '(未答)';
      var answerClass = 'a';
      if (selectedLabel) {
        // Find the option text (label + pros + cons)
        var selectedOpt = decEl.querySelector('.option[data-option-label="' + cssEscape(selectedLabel) + '"]');
        if (selectedOpt) {
          answerText = selectedOpt.textContent.replace(/\s+/g, ' ').trim();
        } else {
          answerText = selectedLabel;
        }
        answerClass = 'a is-answered';
      }

      items.push(
        '<li>' +
          '<div class="q">' + escapeHtml(questionText) + '</div>' +
          '<div class="' + answerClass + '">' + escapeHtml(answerText) + '</div>' +
        '</li>'
      );
    });

    if (items.length === 0) {
      container.innerHTML = '<h2>我的決策</h2><p class="empty">呢份文檔冇拍板事項。</p>';
      container.classList.add('is-visible');
      return;
    }

    var anyAnswered = Object.keys(state).length > 0;
    var html = '<h2>我的決策</h2>';
    if (anyAnswered) {
      html += '<ul>' + items.join('') + '</ul>';
      html += '<button class="reset-btn" onclick="window.__bossReset()">🔄 重設決策</button>';
    } else {
      html += '<p class="empty">你仲未答任何問題 — 喺上面 click 選項就會儲存。</p>';
    }
    container.innerHTML = html;
    container.classList.add('is-visible');
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function cssEscape(s) {
    if (window.CSS && window.CSS.escape) return window.CSS.escape(s);
    return String(s).replace(/[^a-zA-Z0-9_-]/g, '\\$&');
  }

  // Expose reset for inline onclick
  window.__bossReset = function () {
    if (confirm('確定重設所有決策？呢個動作唔可以 undo。')) {
      try {
        localStorage.removeItem(STORAGE_KEY);
      } catch (e) { /* ignore */ }
      document.querySelectorAll('.boss-decision .option').forEach(function (o) {
        o.classList.remove('is-selected', 'is-dimmed');
        o.style.opacity = '';
      });
      renderMyDecisions();
    }
  };

  // Public API for power users / external scripts
  window.BossDecisions = {
    load: loadDecisions,
    save: saveDecisions,
    reset: function () { try { localStorage.removeItem(STORAGE_KEY); } catch (e) {} },
    key: STORAGE_KEY,
  };

  // Init
  function init() {
    applyExistingSelections();
    attachClickHandlers();
    renderMyDecisions();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
