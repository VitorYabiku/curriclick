// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { hooks as colocatedHooks } from "phoenix-colocated/curriclick";
import topbar from "../vendor/topbar";

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

const hooks = {
  ...colocatedHooks,
  ChatScroll: {
    mounted() {
      this.shouldAutoScroll = true;
      this.lastScrollTop = this.el.scrollTop;

      const isAtBottomDistanceThreshold = 50;
      this.el.addEventListener("scroll", () => {
        const { scrollTop, scrollHeight, clientHeight } = this.el;
        const distanceToBottom = scrollHeight - (scrollTop + clientHeight);
        const isAtBottom = distanceToBottom < isAtBottomDistanceThreshold;

        // If the user is close to the bottom, re-enable autoscroll.
        // Otherwise, only disable it if they scroll UP.
        // This prevents autoscroll from breaking when the window grows (which technically increases distanceToBottom temporarily)
        // or when scrolling down manually.
        if (isAtBottom) {
          this.shouldAutoScroll = true;
        } else if (scrollTop < this.lastScrollTop) {
          this.shouldAutoScroll = false;
        }

        this.lastScrollTop = scrollTop;
      });

      this.scrollToBottom();

      this.observer = new MutationObserver(() => {
        if (this.shouldAutoScroll) {
          this.scrollToBottom();
        }
      });
      this.observer.observe(this.el, { childList: true, subtree: true });
    },
    updated() {
      if (this.shouldAutoScroll) {
        this.scrollToBottom();
      }
    },
    destroyed() {
      if (this.observer) this.observer.disconnect();
    },
    scrollToBottom() {
      this.el.scrollTo({ top: this.el.scrollHeight, behavior: "instant" });
    },
  },
};

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      if (from.nodeName === "DETAILS") {
        if (from.hasAttribute("open")) {
          to.setAttribute("open", "");
        }
      }
    },
  },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

/**
 * Smart Tooltip Manager
 * Solves overflow/clipping issues by rendering tooltips at the body level with fixed positioning.
 * Usage: Add `data-smart-tooltip="Your text"` to any element.
 */
const TooltipManager = {
  tooltip: null,
  _timer: null,

  init() {
    // Mouse enter/leave delegation
    document.addEventListener("mouseover", (e) => {
      const target = e.target.closest("[data-smart-tooltip]");
      if (target) {
        this.scheduleShow(target);
      }
    });

    document.addEventListener("mouseout", (e) => {
      const target = e.target.closest("[data-smart-tooltip]");
      // If moving to the tooltip itself, don't hide (optional, but standard behavior usually hides)
      // For simple text tooltips, usually hiding immediately is fine.
      if (target) {
        this.scheduleHide();
      }
    });

    // Hide on scroll to prevent detached tooltips floating on screen
    window.addEventListener(
      "scroll",
      () => {
        if (this.tooltip) this.hide();
      },
      true
    );
  },

  scheduleShow(target) {
    this.clearTimer();
    // Small delay to prevent flickering
    this._timer = setTimeout(() => this.show(target), 50);
  },

  scheduleHide() {
    this.clearTimer();
    this._timer = setTimeout(() => this.hide(), 50);
  },

  clearTimer() {
    if (this._timer) {
      clearTimeout(this._timer);
      this._timer = null;
    }
  },

  show(target) {
    const text = target.getAttribute("data-smart-tooltip");
    if (!text) return;

    // If tooltip exists but is for a different target, remove it first
    if (this.tooltip && this.tooltip._target !== target) {
      this.hide();
    }

    // Create tooltip if not exists
    if (!this.tooltip) {
      this.tooltip = document.createElement("div");
      this.tooltip.className =
        "fixed z-[9999] px-2 py-1 text-sm leading-tight text-neutral-content bg-neutral rounded shadow-sm max-w-[20rem] break-words pointer-events-none transition-opacity duration-200 opacity-0";
      document.body.appendChild(this.tooltip);
    }

    this.tooltip._target = target;
    this.tooltip.textContent = text;
    this.updatePosition(target);

    // Fade in
    requestAnimationFrame(() => {
      if (this.tooltip) this.tooltip.classList.remove("opacity-0");
    });
  },

  hide() {
    if (this.tooltip) {
      this.tooltip.remove();
      this.tooltip = null;
    }
  },

  updatePosition(target) {
    if (!this.tooltip) return;

    const targetRect = target.getBoundingClientRect();
    const tooltipRect = this.tooltip.getBoundingClientRect();
    const gap = 8; // Space between element and tooltip

    // Default position: Top Center
    let top = targetRect.top - tooltipRect.height - gap;
    let left = targetRect.left + (targetRect.width - tooltipRect.width) / 2;

    // 1. Vertical flipping logic
    // If top is cut off, try bottom
    if (top < gap) {
      top = targetRect.bottom + gap;
      
      // If bottom is also cut off (very tall element or small screen), pick the side with more space
      if (top + tooltipRect.height > window.innerHeight - gap) {
        if (targetRect.top > window.innerHeight / 2) {
           // More space above
           top = targetRect.top - tooltipRect.height - gap;
        } else {
           // More space below
           top = targetRect.bottom + gap;
        }
      }
    }

    // 2. Horizontal clamping logic (prevent left/right overflow)
    if (left < gap) {
      left = gap;
    } else if (left + tooltipRect.width > window.innerWidth - gap) {
      left = window.innerWidth - tooltipRect.width - gap;
    }

    this.tooltip.style.top = `${top}px`;
    this.tooltip.style.left = `${left}px`;
  },
};

TooltipManager.init();

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs();

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtDef(e.target);
          }
        },
        true,
      );

      window.liveReloader = reloader;
    },
  );
}
