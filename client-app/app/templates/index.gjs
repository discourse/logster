import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import FaIcon from "@fortawesome/ember-fontawesome/components/fa-icon";
import BackToSiteLink from "client-app/components/back-to-site-link";
import MessageInfo from "client-app/components/message-info";
import MessageRow from "client-app/components/message-row";
import PageNav from "client-app/components/page-nav";
import PanelResizer from "client-app/components/panel-resizer";
import { modifier } from "ember-modifier";

const keepScrolledToBottom = modifier((element) => {
  const panel = element.parentElement;
  let shouldStick = true;

  const scrollToBottom = () => {
    panel.scrollTop = panel.scrollHeight - panel.clientHeight;
  };
  const updateStickiness = () => {
    shouldStick = panel.scrollHeight - panel.clientHeight - panel.scrollTop < 20;
  };
  const observer = new MutationObserver(() => {
    if (shouldStick) {
      scrollToBottom();
    }
  });

  scrollToBottom();
  panel.addEventListener("scroll", updateStickiness, { passive: true });
  observer.observe(element, { childList: true });

  return () => {
    observer.disconnect();
    panel.removeEventListener("scroll", updateStickiness);
  };
});

export default <template>
{{#if @controller.hasTopMenu}}
  <div id="top-menu">
    <BackToSiteLink
      @path={{@controller.backToSiteLinkPath}}
      @text={{@controller.backToSiteLinkText}}
    />
  </div>
{{/if}}
<div id="top-panel" class={{if @controller.hasTopMenu "with-top-menu"}}>
  <div id="log-table" {{keepScrolledToBottom}}>
    {{#if @model.moreBefore}}
      <div {{on "click" @controller.showMoreBefore}} class="show-more">
        {{#if @model.hideCountInLoadMore}}
          Load more
        {{else}}
          Select to see
          {{@model.totalBefore}}
          more
        {{/if}}
      </div>
    {{/if}}

    {{#if @controller.loading}}
      <div class="loading"></div>
    {{/if}}

    {{#each @model.rows as |row|}}
      <div class="message-row-wrapper">
        {{#if @controller.buildingGroupingPattern}}
          <input
            type="checkbox"
            class="grouping-checkbox"
            {{on "change" (fn @controller.handleCheckboxChange row)}}
          />
        {{/if}}
        <MessageRow @model={{row}} @selectRow={{fn @controller.selectRowAction row}} />
      </div>
    {{/each}}
  </div>
</div>

<div id="bottom-panel" class={{if @model.currentRow.group "group-view"}}>
  {{#if @model.currentRow.group}}
    <PageNav
      @list={{@model.currentRow.messages}}
      @position={{@model.currentGroupedMessagesPosition}}
      @extraClasses="group-nav"
      @navigate={{@controller.groupedMessageChangedAction}}
    />
  {{/if}}

  <MessageInfo
    @currentMessage={{@model.currentMessage}}
    @currentRow={{@model.currentRow}}
    @loadingEnv={{@model.loadingEnv}}
    @removeMessage={{@controller.removeMessage}}
    @solveMessage={{@controller.solveMessage}}
    @onTabChange={{@controller.tabChangedAction}}
    @envChangedAction={{@controller.envChangedAction}}
    @currentEnvPosition={{@model.currentEnvPosition}}
    @actionsInMenu={{@controller.actionsInMenu}}
    @showShare={{true}}
  />

  <div class="action-panel">
    <div class="severity-filters">
      <div class="more-wrapping">
        <label class="debug">
          <input
            type="checkbox"
            checked={{@controller.showDebug}}
            onchange={{fn @controller.updateFilter "showDebug"}}
          />
          <span>Debug</span>
        </label>

        <label class="info">
          <input
            type="checkbox"
            checked={{@controller.showInfo}}
            onchange={{fn @controller.updateFilter "showInfo"}}
          />
          <span>Info</span>
        </label>

        <label class="warn">
          <input
            type="checkbox"
            checked={{@controller.showWarn}}
            onchange={{fn @controller.updateFilter "showWarn"}}
          />
          <FaIcon @icon="exclamation-circle" class="warning" />
          <span>Warning</span>
        </label>

        <label class="error">
          <input
            type="checkbox"
            checked={{@controller.showErr}}
            onchange={{fn @controller.updateFilter "showErr"}}
          />
          <FaIcon @icon="times-circle" class="error" />
          <span>Error</span>
        </label>

        <label class="fatal">
          <input
            type="checkbox"
            checked={{@controller.showFatal}}
            onchange={{fn @controller.updateFilter "showFatal"}}
          />
          <FaIcon @icon="times-circle" class="fatal" />
          <span>Fatal</span>
        </label>
      </div>
    </div>

    <div class="search-clear-all">
      <input
        type="text"
        class="search"
        placeholder="Search"
        value={{@controller.searchTerm}}
        onkeyup={{@controller.updateSearch}}
      />

      <div class="footer-btns">
        {{#if @controller.showSettings}}
          {{#if @controller.showCreateGroupingPattern}}
            <button
              class="settings btn"
              type="button"
              {{on "click" @controller.createGroupingPatternFromSelectedRows}}
            >
              <span>Create Grouping Pattern</span>
            </button>
          {{/if}}

          <LinkTo @route="settings" class="settings btn no-text">
            <FaIcon @icon="cog" />
          </LinkTo>

          <button
            class="settings btn no-text"
            type="button"
            {{on "click" @controller.toggleGroupingPatternFromSelectedRows}}
          >
            <FaIcon @icon="list" />
          </button>
        {{/if}}

        <button
          class="clear btn danger"
          type="button"
          {{on "click" @controller.clear}}
        >
          <FaIcon @icon="trash-alt" prefix="far" />
          <span>Clear logs</span>
        </button>
      </div>
    </div>
  </div>
</div>

{{#if @controller.showGroupingPatternDialog}}
  <div class="grouping-pattern-dialog-overlay">
    <div class="grouping-pattern-dialog">
      <h3>Create Grouping Pattern</h3>
      <p>Edit the pattern below before creating:</p>
      <input
        type="text"
        class="grouping-pattern-input"
        value={{@controller.groupingPatternValue}}
        {{on "input" @controller.updateGroupingPatternValue}}
      />
      <div class="grouping-pattern-dialog-buttons">
        <button
          class="btn danger"
          type="button"
          {{on "click" @controller.cancelGroupingPattern}}
        >Cancel</button>
        <button
          class="btn"
          type="button"
          {{on "click" @controller.confirmGroupingPattern}}
        >Create</button>
      </div>
    </div>
  </div>
{{/if}}

<PanelResizer @onResize={{@controller.resizePanels}} />
</template>;
