import { Controller } from "@hotwired/stimulus";

const MAX_ITEMS = 400;
const MAX_PENDING = 200;
const BOTTOM_THRESHOLD = 80;
const TOP_THRESHOLD = 120;
const VIEW_HEARTBEAT_INTERVAL = 30000;
const TIME_ZONE_COOKIE = "telesink_time_zone";
const TIME_ZONE_COOKIE_MAX_AGE = 31_536_000;

export default class extends Controller {
  static targets = [
    "detail",
    "jumpBar",
    "list",
    "loadedCount",
    "localClock",
    "newCount",
    "newestTime",
    "olderLoader",
    "positionStatus",
    "connectionStatus",
    "scroll",
    "utcClock",
  ];
  static values = {
    calendarMonth: String,
    canMarkViewed: Boolean,
    eventDate: String,
    eventType: String,
    propertyKey: String,
    propertyOp: String,
    propertyValue: String,
    searchQuery: String,
    seenCutoff: String,
    viewUrl: String,
  };

  connect() {
    if (this.#syncBrowserTimeZone()) return;

    this.pendingEvents = [];
    this.pendingOverflow = false;
    this.isAtBottom = true;
    this.canLoadOlder = false;
    this.seenCutoffTime = this.#parseSeenCutoff();
    this.isLoadingOlder = false;
    this.isMarkingViewed = false;
    this.needsMarkViewed = false;
    this.openDetailFrameId = null;
    this.prependAnchor = null;
    this._olderLoadController = null;
    this._connectFrame = null;
    this._ensureScrollableFrame = null;
    this._scrollFrame = null;
    this._autofillTimer = null;
    this._viewTimer = null;
    this._viewHeartbeatTimer = null;
    this._clockTimer = null;

    this.scrollHandler = this.#scheduleScrollHandling.bind(this);
    this.keydownHandler = this.#onKeydown.bind(this);
    this.scrollTarget.addEventListener("scroll", this.scrollHandler, {
      passive: true,
    });
    document.addEventListener("keydown", this.keydownHandler);

    this.frameLoadHandler = this.#onFrameLoad.bind(this);
    this.element.addEventListener("turbo:frame-load", this.frameLoadHandler);

    this.visibilityHandler = this.#onVisibilityChange.bind(this);
    document.addEventListener("visibilitychange", this.visibilityHandler);

    this.connectionHandler = this.#updateConnectionStatus.bind(this);
    window.addEventListener("online", this.connectionHandler);
    window.addEventListener("offline", this.connectionHandler);

    this.observer = new MutationObserver((mutations) => {
      this.#handleMutations(mutations);
    });

    if (this.hasListTarget) {
      this.observer.observe(this.listTarget, { childList: true });
    }

    this._connectFrame = requestAnimationFrame(() => {
      if (!this.element.isConnected) return;

      this.#rebuildFeedDecorations();
      this.#scrollToBottom();
      this.#scheduleMarkViewed();
      this.#updateFeedStatus();
      this.#updateConnectionStatus();
      this.#startClocks();
      this.#startViewHeartbeat();
      this._autofillTimer = setTimeout(() => {
        this._autofillTimer = null;
        if (!this.element.isConnected) return;

        this.canLoadOlder = true;
        this.#ensureScrollable();
      }, 250);
    });
  }

  disconnect() {
    if (this.scrollHandler) {
      this.scrollTarget?.removeEventListener("scroll", this.scrollHandler);
    }

    if (this.keydownHandler) {
      document.removeEventListener("keydown", this.keydownHandler);
    }

    if (this.frameLoadHandler) {
      this.element.removeEventListener("turbo:frame-load", this.frameLoadHandler);
    }

    if (this.visibilityHandler) {
      document.removeEventListener("visibilitychange", this.visibilityHandler);
    }

    if (this.connectionHandler) {
      window.removeEventListener("online", this.connectionHandler);
      window.removeEventListener("offline", this.connectionHandler);
    }

    this.observer?.disconnect();
    this._olderLoadController?.abort();
    cancelAnimationFrame(this._connectFrame);
    cancelAnimationFrame(this._ensureScrollableFrame);
    cancelAnimationFrame(this._scrollFrame);
    clearTimeout(this._autofillTimer);
    clearTimeout(this._viewTimer);
    clearInterval(this._viewHeartbeatTimer);
    clearInterval(this._clockTimer);

    if (this.isAtBottom) this.#markViewed();
  }

  openDetail(event) {
    const { params } = event;
    const frame = document.getElementById(params.detailFrame);

    if (frame?.innerHTML.trim() || this.openDetailFrameId === params.detailFrame) {
      event.preventDefault();
      if (frame) frame.innerHTML = "";
      this.openDetailFrameId = null;
      this.#setDetailExpanded(event.currentTarget, false);
      this.#setDetailBusy(event.currentTarget, false);
      return;
    }

    this.openDetailFrameId = params.detailFrame;
    this.#applyDetailContext(event.currentTarget);
    this.#setDetailExpanded(event.currentTarget, true);
    this.#setDetailBusy(event.currentTarget, true);

    this.detailTargets.forEach((frame) => {
      if (frame.id !== params.detailFrame) {
        frame.innerHTML = "";
        this.#setDetailExpandedByFrame(frame.id, false);
        this.#setDetailBusyByFrame(frame.id, false);
      }
    });
  }

  jumpToBottom() {
    this.#flushPending();
    this.#scrollToBottom({ smooth: true });
    this.#scheduleMarkViewed();
  }

  loadOlder(event) {
    event.preventDefault();
    this.canLoadOlder = true;
    this.#loadOlderIfNeeded({ force: true, silent: false });
  }

  #handleMutations(mutations) {
    let prependedHeight = 0;
    let shouldStickToBottom = false;
    let shouldRestorePrependAnchor = false;
    let shouldRebuildDelimiters = false;

    for (const mutation of mutations) {
      const insertedAtBottom = mutation.nextSibling === null;
      const insertedAtTop = !insertedAtBottom && mutation.previousSibling === null;

      for (const node of mutation.addedNodes) {
        if (node.nodeType !== Node.ELEMENT_NODE) continue;
        if (node.classList.contains("day-delimiter")) continue;
        if (node.classList.contains("events__older-loader")) continue;
        if (node.classList.contains("unread-delimiter")) continue;
        if (this.#removeDuplicateEvent(node)) continue;

        if (insertedAtBottom) {
          if (!this.#handleAppend(node)) continue;
          if (this.isAtBottom) shouldStickToBottom = true;
        } else if (insertedAtTop) {
          prependedHeight += node.offsetHeight;
          shouldRestorePrependAnchor = true;
        }

        shouldRebuildDelimiters = true;
      }
    }

    if (shouldRebuildDelimiters) {
      this.#rebuildFeedDecorations();

      if (shouldRestorePrependAnchor) {
        const restored = this.#restorePrependAnchor();
        if (!restored && prependedHeight > 0) {
          this.scrollTarget.scrollTop += prependedHeight;
        }
      } else if (shouldStickToBottom) {
        this.#scrollToBottom();
      }

      this.#ensureScrollable();
      this.#updateFeedStatus();
    }
  }

  #handleAppend(node) {
    if (!this.#matchesLiveFilter(node)) {
      node.remove();
      return false;
    }

    if (node.dataset.eventFeedFlush === "true") {
      delete node.dataset.eventFeedFlush;
      return true;
    }

    if (this.isAtBottom) {
      this.#trimTop();
      this.#scrollToBottom();

      if (document.visibilityState === "visible") {
        const datetime = node.querySelector("time")?.getAttribute("datetime");
        const eventTime = this.#dateFromDatetime(datetime);
        if (eventTime) this.seenCutoffTime = eventTime;

        this.#scheduleMarkViewed();
      }

      return true;
    }

    if (this.pendingEvents.length >= MAX_PENDING) {
      this.pendingEvents.shift();
      this.pendingOverflow = true;
    }

    this.pendingEvents.push(node);
    node.remove();
    this.#updateFeedStatus();
    return false;
  }

  #matchesLiveFilter(node) {
    if (!this.#matchesEventDate(node)) return false;
    if (!this.#matchesSearchQuery(node)) return false;
    if (!["lt", "gt"].includes(this.propertyOpValue)) return true;
    if (!this.hasPropertyKeyValue || !this.hasPropertyValueValue) return true;

    const threshold = Number(this.propertyValueValue);
    if (Number.isNaN(threshold)) return true;

    let properties = {};

    try {
      properties = JSON.parse(node.dataset.filterProperties || "{}");
    } catch {
      return false;
    }

    const value = Number(properties[this.propertyKeyValue]);
    if (Number.isNaN(value)) return false;

    return this.propertyOpValue === "lt"
      ? value < threshold
      : value > threshold;
  }

  #matchesEventDate(node) {
    if (!this.hasEventDateValue) return true;

    const selectedDate = this.eventDateValue.trim();
    if (!selectedDate) return true;

    const datetime = node.querySelector("time")?.getAttribute("datetime");
    const eventDate = this.#dateFromDatetime(datetime);
    if (!eventDate) return false;

    return this.#localDateKey(eventDate) === selectedDate;
  }

  #removeDuplicateEvent(node) {
    const eventId = node.dataset.eventId;
    if (!eventId) return false;

    const alreadyRendered = this
      .#eventItems()
      .some((eventEl) => eventEl !== node && eventEl.dataset.eventId === eventId);

    if (alreadyRendered) {
      node.remove();
      return true;
    }

    const alreadyPending = this.pendingEvents.some((eventEl) => (
      eventEl !== node && eventEl.dataset.eventId === eventId
    ));

    if (alreadyPending) {
      node.remove();
      return true;
    }

    return false;
  }

  #matchesSearchQuery(node) {
    if (!this.hasSearchQueryValue) return true;

    const query = this.searchQueryValue.trim().toLowerCase();
    if (!query) return true;

    const eventText = node.dataset.searchText || "";

    return eventText.toLowerCase().includes(query);
  }

  #flushPending() {
    if (!this.pendingEvents.length) return false;

    this.pendingEvents.forEach((node) => {
      node.dataset.eventFeedFlush = "true";
      this.listTarget.append(node);
    });

    this.pendingEvents = [];
    this.pendingOverflow = false;
    this.#trimTop();
    this.#rebuildFeedDecorations();
    this.#updateFeedStatus();

    return true;
  }

  #onScroll() {
    const wasAtBottom = this.isAtBottom;
    this.isAtBottom = this.#atBottom();

    if (!wasAtBottom && this.isAtBottom) {
      if (this.#flushPending()) this.#scrollToBottom();
      this.#scheduleMarkViewed();
    }

    this.#updateFeedStatus();

    if (this.canLoadOlder) {
      this.#loadOlderIfNeeded();
    }
  }

  #scheduleScrollHandling() {
    if (this._scrollFrame) return;

    this._scrollFrame = requestAnimationFrame(() => {
      this._scrollFrame = null;
      if (!this.element.isConnected) return;

      this.#onScroll();
    });
  }

  #onVisibilityChange() {
    if (document.visibilityState === "visible" && this.isAtBottom) {
      this.#scheduleMarkViewed();
    }
  }

  #onFrameLoad(event) {
    const frame = event.target;
    if (!this.detailTargets.includes(frame)) return;

    if (frame.id !== this.openDetailFrameId) {
      frame.innerHTML = "";
      this.#setDetailExpandedByFrame(frame.id, false);
      this.#setDetailBusyByFrame(frame.id, false);
      return;
    }

    this.#setDetailExpandedByFrame(frame.id, true);
    this.#setDetailBusyByFrame(frame.id, false);
    requestAnimationFrame(() => this.#scrollDetailIntoView(frame));
  }

  #onKeydown(event) {
    if (event.key !== "Escape") return;
    if (!this.openDetailFrameId && !this.#hasOpenDetail()) return;

    const activeElement = document.activeElement;
    if (
      activeElement &&
      activeElement !== document.body &&
      !this.element.contains(activeElement)
    ) {
      return;
    }

    event.preventDefault();
    this.#closeOpenDetails();
  }

  #hasOpenDetail() {
    return this.detailTargets.some((frame) => frame.innerHTML.trim());
  }

  #closeOpenDetails() {
    this.openDetailFrameId = null;

    this.detailTargets.forEach((frame) => {
      frame.innerHTML = "";
      this.#setDetailExpandedByFrame(frame.id, false);
      this.#setDetailBusyByFrame(frame.id, false);
    });
  }

  #setDetailExpanded(link, expanded) {
    if (!link) return;

    link.setAttribute("aria-expanded", String(expanded));
  }

  #setDetailBusy(link, busy) {
    if (!link) return;

    if (busy) {
      link.setAttribute("aria-busy", "true");
    } else {
      link.removeAttribute("aria-busy");
    }
  }

  #setDetailExpandedByFrame(frameId, expanded) {
    this.#setDetailExpanded(this.#detailLinkForFrame(frameId), expanded);
  }

  #setDetailBusyByFrame(frameId, busy) {
    this.#setDetailBusy(this.#detailLinkForFrame(frameId), busy);
  }

  #detailLinkForFrame(frameId) {
    return this.element.querySelector(
      `[aria-controls="${CSS.escape(frameId)}"]`,
    );
  }

  #scrollDetailIntoView(frame) {
    if (!frame?.isConnected) return;

    const scrollRect = this.scrollTarget.getBoundingClientRect();
    const frameRect = frame.getBoundingClientRect();
    const topOverflow = frameRect.top - scrollRect.top;
    const bottomOverflow = frameRect.bottom - scrollRect.bottom;

    if (bottomOverflow > 0) {
      this.scrollTarget.scrollTop += bottomOverflow;
    } else if (topOverflow < 0) {
      this.scrollTarget.scrollTop += topOverflow;
    } else {
      return;
    }

    this.isAtBottom = this.#atBottom();
    this.#updateFeedStatus();
  }

  #atBottom() {
    const distance =
      this.scrollTarget.scrollHeight -
      this.scrollTarget.scrollTop -
      this.scrollTarget.clientHeight;

    return distance < BOTTOM_THRESHOLD;
  }

  #atTop() {
    return this.scrollTarget.scrollTop <= TOP_THRESHOLD;
  }

  #scrollToBottom({ smooth = false } = {}) {
    this.scrollTarget.scrollTo({
      top: this.scrollTarget.scrollHeight,
      behavior: smooth ? "smooth" : "auto",
    });
    this.isAtBottom = true;
    this.#updateFeedStatus();
  }

  #ensureScrollable() {
    if (!this.canLoadOlder) return;
    if (this.#isScrollable()) {
      this.#hideManualOlderLoader();
      return;
    }

    this.#showManualOlderLoader();
  }

  #isScrollable() {
    return this.scrollTarget.scrollHeight > this.scrollTarget.clientHeight + 1;
  }

  #loadOlderIfNeeded({ force = false, silent = force } = {}) {
    if (this.isLoadingOlder || !this.hasOlderLoaderTarget) return;
    const loader = this.olderLoaderTarget;
    const url = loader.dataset.url;

    if (!url) return;
    if (!force && !this.#atTop()) return;

    this.prependAnchor = this.#capturePrependAnchor();
    this.isLoadingOlder = true;
    this._olderLoadController = new AbortController();
    this.#hideManualOlderLoader();

    if (silent) {
      loader.textContent = "";
    } else {
      loader.textContent = "loading older events...";
      loader.classList.add("events__older-loader--loading");
    }

    fetch(url, {
      headers: { Accept: "text/vnd.turbo-stream.html" },
      credentials: "same-origin",
      signal: this._olderLoadController.signal,
    })
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.text();
      })
      .then((html) => window.Turbo.renderStreamMessage(html))
      .then(() => {
        cancelAnimationFrame(this._ensureScrollableFrame);
        this._ensureScrollableFrame = requestAnimationFrame(() => {
          if (!this.element.isConnected) return;
          this.prependAnchor = null;
          if (force) this.#ensureScrollable();
        });
      })
      .catch((e) => {
        if (e.name === "AbortError") return;

        if (!silent && loader.isConnected) {
          loader.textContent = "could not load older events";
          loader.disabled = false;
          loader.classList.add("events__older-loader--manual");
        }

        console.error("Failed to load older events", e);
      })
      .finally(() => {
        if (loader.isConnected) {
          loader.classList.remove("events__older-loader--loading");
        }

        this._olderLoadController = null;
        this.isLoadingOlder = false;
      });
  }

  #showManualOlderLoader() {
    if (!this.hasOlderLoaderTarget) return;
    if (this.isLoadingOlder) return;
    if (!this.olderLoaderTarget.dataset.url) return;

    this.olderLoaderTarget.disabled = false;
    this.olderLoaderTarget.textContent = "load older events";
    this.olderLoaderTarget.classList.add("events__older-loader--manual");
  }

  #hideManualOlderLoader() {
    if (!this.hasOlderLoaderTarget) return;

    this.olderLoaderTarget.classList.remove("events__older-loader--manual");
    this.olderLoaderTarget.disabled = true;

    if (!this.isLoadingOlder) {
      this.olderLoaderTarget.textContent = "";
    }
  }

  #trimTop() {
    const items = this.#eventItems();

    while (items.length > MAX_ITEMS) {
      this.#removeEventItem(items.shift());
    }

    this.#removeLeadingDecorations();
    this.#refreshOlderLoaderCursor();
  }

  #updateFeedStatus() {
    this.#updateClocks();
    this.#updateConnectionStatus();
    this.#updateJumpStatus();
    this.#updateLoadedCount();
    this.#updateNewestTime();
    this.#updatePositionStatus();
  }

  #updateConnectionStatus() {
    if (!this.hasConnectionStatusTarget) return;

    const online = globalThis.navigator?.onLine !== false;
    this.connectionStatusTarget.textContent = online ? "online" : "offline";
    this.connectionStatusTarget.classList.toggle(
      "event-status__connection--offline",
      !online,
    );
  }

  #startClocks() {
    this.#updateClocks();
    this._clockTimer = setInterval(() => this.#updateClocks(), 1000);
  }

  #startViewHeartbeat() {
    if (!this.canMarkViewedValue) return;

    this._viewHeartbeatTimer = setInterval(() => {
      if (!this.element.isConnected) return;
      if (document.visibilityState !== "visible") return;
      if (!this.isAtBottom) return;

      this.#scheduleMarkViewed();
    }, VIEW_HEARTBEAT_INTERVAL);
  }

  #updateClocks() {
    const now = new Date();
    const datetime = now.toISOString();

    if (this.hasLocalClockTarget) {
      this.localClockTarget.setAttribute("datetime", datetime);
      this.localClockTarget.textContent = this.#formatClock(now);
    }

    if (this.hasUtcClockTarget) {
      this.utcClockTarget.setAttribute("datetime", datetime);
      this.utcClockTarget.textContent = this.#formatClock(now, { utc: true });
    }
  }

  #updateJumpStatus() {
    if (!this.hasJumpBarTarget || !this.hasNewCountTarget) return;

    const pendingCount = this.pendingEvents.length;
    const show = !this.isAtBottom && pendingCount > 0;
    this.jumpBarTarget.classList.toggle("hidden", !show);

    if (show) {
      const label = `${pendingCount}${this.pendingOverflow ? "+" : ""} new`;
      this.newCountTarget.textContent = label;
      this.jumpBarTarget.setAttribute("aria-label", `${label} events`);
    } else {
      this.newCountTarget.textContent = "";
      this.jumpBarTarget.removeAttribute("aria-label");
    }
  }

  #updateLoadedCount() {
    if (!this.hasLoadedCountTarget) return;

    this.loadedCountTarget.textContent = String(this.#eventItems().length);
  }

  #updateNewestTime() {
    if (!this.hasNewestTimeTarget) return;

    const newestTime = this.#newestEventTime();

    if (!newestTime) {
      this.newestTimeTarget.removeAttribute("datetime");
      this.newestTimeTarget.textContent = "--:--:--";
      return;
    }

    this.newestTimeTarget.setAttribute("datetime", newestTime.datetime);
    this.newestTimeTarget.textContent = this.#formatClock(newestTime.date);
  }

  #updatePositionStatus() {
    if (!this.hasPositionStatusTarget) return;

    if (this.isAtBottom) {
      this.positionStatusTarget.textContent = "at bottom";
    } else if (this.#atTop()) {
      this.positionStatusTarget.textContent = "at top";
    } else {
      this.positionStatusTarget.textContent = "viewing older";
    }
  }

  #scheduleMarkViewed() {
    if (!this.canMarkViewedValue) return;

    clearTimeout(this._viewTimer);
    this._viewTimer = setTimeout(() => this.#markViewed(), 400);
  }

  #markViewed() {
    if (!this.canMarkViewedValue) return;
    if (!this.hasViewUrlValue) return;
    if (!this.isAtBottom) return;

    if (this.isMarkingViewed) {
      this.needsMarkViewed = true;
      return;
    }

    this.isMarkingViewed = true;
    this.needsMarkViewed = false;

    const csrf =
      document.querySelector('meta[name="csrf-token"]')?.content || "";
    const formData = new FormData();
    formData.append("authenticity_token", csrf);
    this.#appendViewFilters(formData);

    fetch(this.viewUrlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": csrf },
      credentials: "same-origin",
      keepalive: true,
      body: formData,
    })
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        if (this.element.isConnected) this.#markVisibleEventsRead();
      })
      .catch((e) => {
        if (this.element.isConnected) {
          console.error("Failed to mark sink as viewed", e);
        }
      })
      .finally(() => {
        this.isMarkingViewed = false;

        if (this.needsMarkViewed && this.isAtBottom && this.element.isConnected) {
          this.#scheduleMarkViewed();
        }
      });
  }

  #markVisibleEventsRead() {
    this.#restripeRows();
  }

  #applyDetailContext(link) {
    if (!link?.href) return;

    const url = new URL(link.href, window.location.href);

    this.#setOptionalParam(url, "event_type", this.eventTypeValue);
    this.#setOptionalParam(url, "date", this.eventDateValue);
    this.#setOptionalParam(url, "month", this.calendarMonthValue);
    this.#setOptionalParam(url, "q", this.searchQueryValue);

    if (this.propertyKeyValue?.trim()) {
      url.searchParams.set("property_key", this.propertyKeyValue);
      url.searchParams.set("property_op", this.propertyOpValue || "eq");

      if (this.propertyOpValue === "exists") {
        url.searchParams.delete("property_value");
      } else {
        url.searchParams.set("property_value", this.propertyValueValue || "");
      }
    } else {
      url.searchParams.delete("property_key");
      url.searchParams.delete("property_op");
      url.searchParams.delete("property_value");
    }

    link.href = `${url.pathname}${url.search}${url.hash}`;
  }

  #setOptionalParam(url, key, value) {
    if (value?.trim()) {
      url.searchParams.set(key, value);
    } else {
      url.searchParams.delete(key);
    }
  }

  #syncBrowserTimeZone() {
    const formatter = globalThis.Intl?.DateTimeFormat?.();
    const timeZone = formatter?.resolvedOptions?.()?.timeZone;

    if (!timeZone) return false;
    if (this.#cookieValue(TIME_ZONE_COOKIE) === timeZone) return false;

    document.cookie = [
      `${TIME_ZONE_COOKIE}=${encodeURIComponent(timeZone)}`,
      "path=/",
      `max-age=${TIME_ZONE_COOKIE_MAX_AGE}`,
      "SameSite=Lax",
    ].join("; ");

    const reloadKey = `telesink:time-zone:${timeZone}`;
    if (sessionStorage.getItem(reloadKey)) return false;

    sessionStorage.setItem(reloadKey, "1");

    if (window.Turbo?.visit) {
      window.Turbo.visit(window.location.href, { action: "replace" });
    } else {
      window.location.replace(window.location.href);
    }

    return true;
  }

  #cookieValue(name) {
    const cookie = (document.cookie || "")
      .split("; ")
      .find((part) => part.startsWith(`${name}=`));

    if (!cookie) return null;

    return decodeURIComponent(cookie.slice(name.length + 1));
  }

  #appendViewFilters(formData) {
    this.#appendOptionalField(formData, "event_type", this.eventTypeValue);
    this.#appendOptionalField(formData, "date", this.eventDateValue);
    this.#appendOptionalField(formData, "q", this.searchQueryValue);

    if (this.propertyKeyValue?.trim()) {
      formData.append("property_key", this.propertyKeyValue);
      formData.append("property_op", this.propertyOpValue || "eq");

      if (this.propertyOpValue !== "exists") {
        formData.append("property_value", this.propertyValueValue || "");
      }
    }
  }

  #appendOptionalField(formData, key, value) {
    if (value?.trim()) formData.append(key, value);
  }

  #parseSeenCutoff() {
    if (!this.hasSeenCutoffValue) return null;

    return this.#dateFromDatetime(this.seenCutoffValue);
  }

  #rebuildFeedDecorations() {
    this.#rebuildDayDelimiters();
    this.#rebuildUnreadDelimiter();
    this.#restripeRows();
  }

  #rebuildDayDelimiters() {
    this.listTarget
      .querySelectorAll(".day-delimiter")
      .forEach((el) => el.remove());

    const events = this.#eventItems();

    let lastDateKey = null;

    events.forEach((eventEl) => {
      const timeEl = eventEl.querySelector("time");
      if (!timeEl) return;

      const date = this.#dateFromDatetime(timeEl.getAttribute("datetime"));
      if (!date) return;

      const dateKey = this.#localDateKey(date);

      if (dateKey !== lastDateKey) {
        eventEl.before(this.#createDayDelimiter(date));
        lastDateKey = dateKey;
      }
    });
  }

  #rebuildUnreadDelimiter() {
    this.listTarget
      .querySelectorAll(".unread-delimiter")
      .forEach((el) => el.remove());

    if (!this.seenCutoffTime) return;

    const events = this.#eventItems();

    const firstUnread = events.find((eventEl) => {
      const timeEl = eventEl.querySelector("time");
      if (!timeEl) return false;

      const eventTime = this.#dateFromDatetime(timeEl.getAttribute("datetime"));
      if (!eventTime) return false;

      return eventTime > this.seenCutoffTime;
    });

    if (!firstUnread) return;

    const div = document.createElement("div");
    div.className = "unread-delimiter";
    div.setAttribute("role", "separator");
    div.setAttribute("aria-label", "unread events");
    div.title = "unread events";

    const span = document.createElement("span");
    span.className = "unread-delimiter__label";
    span.textContent = "unread";
    div.appendChild(span);

    firstUnread.before(div);
  }

  #createDayDelimiter(date) {
    const div = document.createElement("div");
    div.className = "day-delimiter";
    div.setAttribute("role", "separator");

    const span = document.createElement("span");
    span.className = "day-delimiter__label";

    const today = new Date();
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);

    if (this.#isSameDay(date, today)) span.textContent = "Today";
    else if (this.#isSameDay(date, yesterday)) span.textContent = "Yesterday";
    else {
      span.textContent = date.toLocaleDateString(navigator.language, {
        weekday: "long",
        month: "long",
        day: "numeric",
        year: "numeric",
      });
    }

    div.setAttribute("aria-label", span.textContent);
    div.appendChild(span);

    return div;
  }

  #eventItems() {
    return Array.from(this.listTarget.querySelectorAll(".event-feed__item"));
  }

  #removeEventItem(eventEl) {
    if (!eventEl) return;

    const detailFrameId = eventEl.querySelector(".event-detail-frame")?.id;
    if (detailFrameId && detailFrameId === this.openDetailFrameId) {
      this.openDetailFrameId = null;
    }

    eventEl.remove();
  }

  #restripeRows() {
    this.#eventItems().forEach((eventEl, index) => {
      eventEl.classList.toggle("event-feed__item--striped", index % 2 === 0);
    });
  }

  #newestEventTime() {
    const items = this.#eventItems().concat(this.pendingEvents);

    for (let index = items.length - 1; index >= 0; index -= 1) {
      const datetime = items[index].querySelector("time")?.getAttribute("datetime");
      const date = this.#dateFromDatetime(datetime);

      if (datetime && date) return { date, datetime };
    }

    return null;
  }

  #removeLeadingDecorations() {
    while (
      this.listTarget.firstElementChild &&
      !this.listTarget.firstElementChild.classList.contains("event-feed__item")
    ) {
      this.listTarget.firstElementChild.remove();
    }
  }

  #capturePrependAnchor() {
    const scrollRect = this.scrollTarget.getBoundingClientRect();
    const anchor = this.#eventItems().find((eventEl) => {
      const rect = eventEl.getBoundingClientRect();

      return rect.bottom >= scrollRect.top;
    });

    if (!anchor?.dataset.eventId) return null;

    return {
      eventId: anchor.dataset.eventId,
      top: anchor.getBoundingClientRect().top - scrollRect.top,
    };
  }

  #restorePrependAnchor() {
    if (!this.prependAnchor) return false;

    const { eventId, top } = this.prependAnchor;
    this.prependAnchor = null;

    const anchor = this
      .#eventItems()
      .find((eventEl) => eventEl.dataset.eventId === eventId);

    if (!anchor) return false;

    const scrollRect = this.scrollTarget.getBoundingClientRect();
    const currentTop = anchor.getBoundingClientRect().top - scrollRect.top;
    this.scrollTarget.scrollTop += currentTop - top;

    return true;
  }

  #refreshOlderLoaderCursor() {
    if (!this.hasOlderLoaderTarget) return;
    if (!this.olderLoaderTarget.dataset.url) return;

    const firstEventId = this.#eventItems()[0]?.dataset.eventId;
    if (!firstEventId) return;

    const url = new URL(this.olderLoaderTarget.dataset.url, window.location.href);
    url.searchParams.set("before_id", firstEventId);

    this.olderLoaderTarget.dataset.url = `${url.pathname}${url.search}`;
  }

  #formatClock(date, { utc = false } = {}) {
    const hours = utc ? date.getUTCHours() : date.getHours();
    const minutes = utc ? date.getUTCMinutes() : date.getMinutes();
    const seconds = utc ? date.getUTCSeconds() : date.getSeconds();

    return [
      hours,
      minutes,
      seconds,
    ]
      .map((part) => String(part).padStart(2, "0"))
      .join(":");
  }

  #dateFromDatetime(datetime) {
    if (!datetime) return null;

    const date = new Date(datetime);
    if (isNaN(date.getTime())) return null;

    return date;
  }

  #localDateKey(date) {
    return [
      date.getFullYear(),
      String(date.getMonth() + 1).padStart(2, "0"),
      String(date.getDate()).padStart(2, "0"),
    ].join("-");
  }

  #isSameDay(a, b) {
    return (
      a.getFullYear() === b.getFullYear() &&
      a.getMonth() === b.getMonth() &&
      a.getDate() === b.getDate()
    );
  }
}
