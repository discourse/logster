import { LinkTo } from "@ember/routing";
import MessageInfo from "client-app/components/message-info";

export default <template>
<LinkTo @route="index" class="recent-link">Recent</LinkTo>

<div id="bottom-panel" class="full">
  <MessageInfo
    @currentMessage={{@model}}
    @showTitle="true"
    @removeMessage={{@controller.removeMessage}}
    @solveMessage={{@controller.solveMessage}}
    @envChangedAction={{@controller.envChanged}}
    @currentEnvPosition={{@controller.envPosition}}
    @actionsInMenu={{false}}
  />
</div>
</template>;
