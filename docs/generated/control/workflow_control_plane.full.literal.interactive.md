# Full control plane - Literal Interactive Viewer

## Legend (for non-experts)

- **Rounded boxes** = workflow steps (validation, generation, test/lint, CI/hooks, gates).
- **Rotated top boxes** = artifacts/files (JSON/YAML/MD/SVG) read or written by steps.
- **Arrows** = control/data flow; arrow direction = dependency direction.
- **Arrow colors** = workflow domains (validate/test/log/evidence/docs/CI/hooks).
- **Overall logic** = source state + observed manifests + verify outputs pass through guards and generators to produce status/evidence and generated docs.

<style>
#svg_viewer_full_literal { max-width: 95vw; margin: 0 auto; }
#svg_viewer_full_literal .toolbar { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; margin: 6px 0 10px; }
#svg_viewer_full_literal .toolbar button { border: 1px solid #94a3b8; background: #ffffff; color: #0f172a; border-radius: 6px; padding: 4px 10px; cursor: pointer; }
#svg_viewer_full_literal .toolbar input[type='range'] { width: 220px; }
#svg_viewer_full_literal .viewport { width: 95vw; height: 88vh; border: 1px solid #cbd5e1; border-radius: 8px; overflow: auto; background: #f8fafc; cursor: grab; position: relative; }
#svg_viewer_full_literal .viewport.dragging { cursor: grabbing; }
#svg_viewer_full_literal .stage { position: relative; min-width: 100%; min-height: 100%; }
#svg_viewer_full_literal .canvas { position: absolute; display: block; }
#svg_viewer_full_literal .canvas img { display: block; user-select: none; -webkit-user-drag: none; max-width: none; width: auto; height: auto; }
#svg_viewer_full_literal .overlay-meta { position: sticky; top: 8px; left: 8px; z-index: 5; display: inline-block; padding: 2px 8px; border-radius: 6px; border: 1px solid #cbd5e1; background: rgba(255,255,255,0.90); color: #334155; font-size: 0.78rem; }
#svg_viewer_full_literal .hint { color: #94a3b8; font-size: 0.90rem; margin-top: 8px; font-style: italic; }
#svg_viewer_full_literal .hint-cz-panel { color: #64748b; font-size: 0.90rem; margin-top: 8px; padding: 0; border: 0; border-radius: 0; background: transparent; }
#svg_viewer_full_literal .hint-cz-panel p { margin: 0 0 6px; }
#svg_viewer_full_literal .hint-cz-panel ol { margin: 4px 0 6px 20px; padding: 0; }
#svg_viewer_full_literal .hint-cz-panel li { margin: 2px 0; }
#svg_viewer_full_literal .hint-cz-panel a { color: #0369a1; text-decoration: underline; }
</style>

<div id="svg_viewer_full_literal">
  <div class="toolbar">
    <button type="button" data-action="zoom-out">-</button>
    <input type="range" min="5" max="800" step="5" value="100" data-role="zoom-slider" />
    <button type="button" data-action="zoom-in">+</button>
    <button type="button" data-action="reset">Reset</button>
    <span data-role="zoom-value">100%</span>
  </div>
  <div class="viewport" data-role="viewport" tabindex="0">
    <div class="overlay-meta" data-role="overlay-meta">workflow-control-plane v0.3.0 | data 2026-02-28T16:55:00Z | generated svg: loading...</div>
    <div class="stage" data-role="stage">
      <div class="canvas" data-role="canvas">
        <img src="/generated/control/workflow_control_plane.full.literal.svg" alt="Workflow control plane literal rotated SVG" draggable="false" data-role="image" />
      </div>
    </div>
  </div>
  <div class="hint">Mouse wheel = zoom, left-button drag = pan, scrollbars remain available.</div>
  <div class="hint">Mode: zoom + pan (scrollbars + mouse drag), range 5-800%.</div>
  <div class="hint-cz-panel">
    <p><strong>Component:</strong> <code>workflow-control-plane v0.3.0 | data 2026-02-28T16:55:00Z</code></p>
    <p><strong>SVG timestamp (Last-Modified or server Date):</strong> <span data-role="generated-at">loading...</span></p>
    <p><strong>CZ data source:</strong> <code>docs_control/workflow_control_plane.json</code></p>
    <p><strong>Aktualizace dat:</strong></p>
    <ol>
      <li>upravte SSOT,</li>
      <li>spusťte <code>validate_workflow_control_alignment -RefreshObserved</code> + <code>validate_capability_audit</code> + <code>preflight_state_discovery</code> + <code>verify_batch_status</code>,</li>
      <li>spusťte <code>generate_workflow_control_diagrams</code>,</li>
      <li>restart <code>mkdocs serve</code>.</li>
    </ol>
    <p><strong>Pro laika:</strong> po změně vstupního JSON stačí udělat 4 kroky výše; systém nejdřív zkontroluje stav a pak bezpečně přegeneruje všechny diagramy.</p>
    <p>Web links: <a href="/generated/control/workflow_control_plane.full.literal.svg">literal.svg</a> | <a href="/generated/control/workflow_control_plane.full.compact.fit.svg">compact.fit.svg</a> | <a href="/generated/control/workflow_control_plane.full.svg">full.svg</a> | <a href="/generated/control/WORKFLOW_CONTROL_PLANE/">workflow note</a></p>
  </div>
</div>

<script>
(function () {
  var root = document.getElementById('svg_viewer_full_literal');
  if (!root) return;
  var viewport = root.querySelector('[data-role="viewport"]');
  var stage = root.querySelector('[data-role="stage"]');
  var canvas = root.querySelector('[data-role="canvas"]');
  var image = root.querySelector('[data-role="image"]');
  var slider = root.querySelector('[data-role="zoom-slider"]');
  var zoomValue = root.querySelector('[data-role="zoom-value"]');
  var generatedAt = root.querySelector('[data-role="generated-at"]');
  var overlayMeta = root.querySelector('[data-role="overlay-meta"]');
  var zoom = 1;
  var minZoom = 0.05;
  var maxZoom = 8.0;
  var panPadding = 12000;
  var componentMeta = 'workflow-control-plane v0.3.0 | data 2026-02-28T16:55:00Z';
  var baseWidth = 0;
  var baseHeight = 0;
  var dragging = false;
  var dragStartX = 0;
  var dragStartY = 0;
  var scrollStartLeft = 0;
  var scrollStartTop = 0;

  function clamp(v, min, max) { return Math.max(min, Math.min(max, v)); }
  function ensureBaseSize() {
    if (baseWidth > 0 && baseHeight > 0) return true;
    var w = image.naturalWidth || image.width;
    var h = image.naturalHeight || image.height;
    if (!w || !h) return false;
    baseWidth = w;
    baseHeight = h;
    return true;
  }

  function formatDate(value) {
    if (!value) return 'unknown';
    var dt = new Date(value);
    if (Number.isNaN(dt.getTime())) return String(value);
    return dt.toISOString().replace('T', ' ').replace('Z', ' UTC');
  }

  function setGeneratedText(text) {
    var val = text || 'unknown';
    generatedAt.textContent = val;
    overlayMeta.textContent = componentMeta + ' | generated svg: ' + val;
  }

  function loadGeneratedTimestamp() {
    var src = image.getAttribute('src');
    fetch(src, { method: 'HEAD', cache: 'no-store' })
      .then(function (resp) {
        var lm = resp.headers.get('last-modified') || resp.headers.get('date');
        if (!lm) { setGeneratedText('unknown'); return; }
        setGeneratedText(formatDate(lm));
      })
      .catch(function () { setGeneratedText('unknown'); });
  }

  function applyScaledSize() {
    var scaledWidth = Math.max(1, Math.round(baseWidth * zoom));
    var scaledHeight = Math.max(1, Math.round(baseHeight * zoom));
    var stageWidth = Math.max(viewport.clientWidth, scaledWidth + (panPadding * 2));
    var stageHeight = Math.max(viewport.clientHeight, scaledHeight + (panPadding * 2));
    stage.style.width = stageWidth + 'px';
    stage.style.height = stageHeight + 'px';
    canvas.style.left = panPadding + 'px';
    canvas.style.top = panPadding + 'px';
    canvas.style.width = scaledWidth + 'px';
    canvas.style.height = scaledHeight + 'px';
    image.style.width = scaledWidth + 'px';
    image.style.height = scaledHeight + 'px';
  }

  function setZoom(next, focusX, focusY) {
    if (!ensureBaseSize()) return;
    var prevZoom = zoom;
    var localFocusX = (typeof focusX === 'number') ? focusX : (viewport.clientWidth / 2);
    var localFocusY = (typeof focusY === 'number') ? focusY : (viewport.clientHeight / 2);
    var worldX = (viewport.scrollLeft - panPadding + localFocusX) / prevZoom;
    var worldY = (viewport.scrollTop - panPadding + localFocusY) / prevZoom;
    zoom = clamp(next, minZoom, maxZoom);
    applyScaledSize();
    var maxLeft = Math.max(0, viewport.scrollWidth - viewport.clientWidth);
    var maxTop = Math.max(0, viewport.scrollHeight - viewport.clientHeight);
    viewport.scrollLeft = clamp(panPadding + (worldX * zoom) - localFocusX, 0, maxLeft);
    viewport.scrollTop = clamp(panPadding + (worldY * zoom) - localFocusY, 0, maxTop);
    var pct = Math.round(zoom * 100);
    slider.value = String(pct);
    zoomValue.textContent = pct + '%';
  }

  function resetView() {
    setZoom(1);
    viewport.scrollLeft = panPadding;
    viewport.scrollTop = panPadding;
  }

  root.querySelector('[data-action="zoom-in"]').addEventListener('click', function () { setZoom(zoom + 0.1); });
  root.querySelector('[data-action="zoom-out"]').addEventListener('click', function () { setZoom(zoom - 0.1); });
  root.querySelector('[data-action="reset"]').addEventListener('click', resetView);

  slider.addEventListener('input', function () { setZoom(Number(slider.value) / 100); });

  viewport.addEventListener('wheel', function (ev) {
    if (!ev.ctrlKey && !ev.altKey && !ev.shiftKey) {
      ev.preventDefault();
      var rect = viewport.getBoundingClientRect();
      var focusX = ev.clientX - rect.left;
      var focusY = ev.clientY - rect.top;
      var delta = ev.deltaY < 0 ? 0.08 : -0.08;
      setZoom(zoom + delta, focusX, focusY);
    }
  }, { passive: false });

  viewport.addEventListener('mousedown', function (ev) {
    if (ev.button !== 0) return;
    dragging = true;
    dragStartX = ev.clientX;
    dragStartY = ev.clientY;
    scrollStartLeft = viewport.scrollLeft;
    scrollStartTop = viewport.scrollTop;
    viewport.classList.add('dragging');
    ev.preventDefault();
  });

  window.addEventListener('mousemove', function (ev) {
    if (!dragging) return;
    var panGain = Math.max(1, Math.sqrt(zoom));
    viewport.scrollLeft = scrollStartLeft - ((ev.clientX - dragStartX) * panGain);
    viewport.scrollTop = scrollStartTop - ((ev.clientY - dragStartY) * panGain);
  });

  window.addEventListener('mouseup', function () {
    if (!dragging) return;
    dragging = false;
    viewport.classList.remove('dragging');
  });

  viewport.addEventListener('keydown', function (ev) {
    var panX = Math.max(80, Math.round(viewport.clientWidth * 1.0));
    var panY = Math.max(80, Math.round(viewport.clientHeight * 1.0));
    var handled = true;
    switch (ev.key) {
      case 'ArrowLeft': viewport.scrollLeft -= panX; break;
      case 'ArrowRight': viewport.scrollLeft += panX; break;
      case 'ArrowUp': viewport.scrollTop -= panY; break;
      case 'ArrowDown': viewport.scrollTop += panY; break;
      case 'PageUp': viewport.scrollTop -= panY; break;
      case 'PageDown': viewport.scrollTop += panY; break;
      case 'Home': viewport.scrollLeft = 0; viewport.scrollTop = 0; break;
      case 'End': viewport.scrollLeft = viewport.scrollWidth; viewport.scrollTop = viewport.scrollHeight; break;
      default: handled = false;
    }
    if (handled) ev.preventDefault();
  });

  window.addEventListener('resize', function () {
    if (!ensureBaseSize()) return;
    setZoom(zoom);
  });

  if (image.complete) {
    resetView();
    loadGeneratedTimestamp();
  } else {
    image.addEventListener('load', function () { resetView(); loadGeneratedTimestamp(); });
  }
})();
</script>
