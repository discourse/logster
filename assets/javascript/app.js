moment.lang('en', {
      relativeTime : {
        future: "in %s",
        past:   "%s ago",
        s:  "secs",
        m:  "a min",
        mm: "%d mins",
        h:  "an hr",
        hh: "%d hrs",
        d:  "a day",
        dd: "%d days",
        M:  "a mth",
        MM: "%d mths",
        y:  "a yr",
        yy: "%d yrs"
      }
});


App = Ember.Application.create({
});

App.ajax =  function(url, settings) {
  settings = settings || {};
  settings.headers = settings.headers || {};
  settings.headers["X-SILENCE-LOGGER"] = true;
  return $.ajax(Logger.rootPath + url, settings);
};

App.preloadOrAjax = function(url, settings) {
  var preloaded = Logger.preload[url];
  if (preloaded) {
    // return a pseudo-XHR
    return {
      success: function(callback) {
        setTimeout(function() {
          callback(preloaded);
        }, 0);
        return this;
      },
      error: function() { return this; }
    };
  } else {
    return App.ajax(url, settings);
  }
};

App.Router.map(function() {
  this.route("index", { path: "/" });
  this.route("show", { path: "/show/:id" });
});

var entityMap = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': '&quot;',
    "'": '&#39;',
    "/": '&#x2F;'
  };

function escapeHtml(string) {
  return String(string).replace(/[&<>"'\/]/g, function (s) {
    return entityMap[s];
  });
}

function buildArrayString(array) {
  var buffer = [];
  _.each(array, function(v) {
    if (v === null) {
      buffer.push('null');
    } else if (Object.prototype.toString.call(v) === '[object Array]') {
      buffer.push(buildArrayString(v));
    } else {
      buffer.push(escapeHtml(v.toString()));
    }
  });
  return '[' + buffer.join(', ') + ']';
}

function buildHashString(hash, recurse) {
  if (!hash) return '';

  var buffer = [],
      hashes = [];
  _.each(hash, function(v, k) {

    if (v === null) {
      buffer.push('null');
    } else if (Object.prototype.toString.call(v) === '[object Array]') {
      buffer.push("<tr><td>" + escapeHtml(k) + "</td><td>" + buildArrayString(v) + "</td></tr>");
    } else if (typeof v === "object") {
      hashes.push(k);
    } else {
      buffer.push("<tr><td>" + escapeHtml(k) + "</td><td>" + escapeHtml(v) + "</td></tr>");
    }
  });

  if (_.size(hashes) > 0) {
    _.each(hashes, function(k1) {
      var v = hash[k1];
      buffer.push("<tr><td></td><td><table>");
      buffer.push("<td>" + escapeHtml(k1) + "</td><td>" + buildHashString(v, true) + "</td>");
      buffer.push("</table></td></tr>");
    });
  }
  var className = recurse?"": "env-table";
  return "<table class='"+ className +"'>" + buffer.join("\n") + "</table>";
}

App.Message = Ember.Object.extend({

  MAX_LEN: 200,

  expand: function() {
    this.set("expanded", true);
  },

  solve: function() {
    return App.ajax("/solve/" + this.get('key'), { type: "PUT" });
  },

  "delete": function() {
    return App.ajax("/message/" + this.get('key'), { type: "DELETE" });
  },

  protect: function() {
    this.set('protected', true);
    return App.ajax("/protect/" + this.get('key'), { type: "PUT" });
  },
  unprotect: function() {
    this.set('protected', false);
    return App.ajax("/unprotect/" + this.get('key'), { type: "DELETE" });
  },

  showCount: function() {
    return this.get('count') > 1;
  }.property('count'),

  hasMore: function() {
    var message = this.get("message");
    var expanded = this.get("expanded");

    return !expanded && message.length > this.MAX_LEN;
  }.property("message", "expanded"),

  shareUrl: function() {
    return Logger.rootPath + "/show/" + this.get('key');
  }.property("key"),

  displayMessage: function() {
    var message = this.get("message");
    var expanded = this.get("expanded");

    if (!expanded && message.length > this.MAX_LEN) {
      message = message.substr(0, this.MAX_LEN);
    }
    return message;
  }.property("message", "expanded"),

  updateFromObject: function(other) {
    // XXX Only updatable property is count right now
    this.set('count', other.get('count'));
  },

  canSolve: function() {
    var backtrace = this.get("backtrace");
    return this.get("env.application_version") && backtrace && (backtrace.length > 0);
  }.property(),

  envTable: function() {
    return buildHashString(this.get('env'));
  }.property("env"),


  rowClass: function() {
    switch (this.get("severity")) {
      case 0:
        return "debug";
      case 1:
        return "info";
      case 2:
        return "warn";
      case 3:
        return "error";
      case 4:
        return "fatal";
    }
  }.property("severity"),

  glyph: function() {
    switch (this.get("severity")) {
      case 0:
        return "";
      case 1:
        return "";
      case 2:
        return "<i class='fa fa-exclamation-circle warning'></i>";
      case 3:
        return "<i class='fa fa-times-circle error'></i>";
      case 4:
        return "<i class='fa fa-times-circle fatal'></i>";
    }
  }.property("severity")
});

App.MessageCollection = Em.Object.extend({

  messages: Em.A(),
  currentMessage: null,
  total: 0,

  solve: function(message) {
    var self = this;
    message.solve().then(function(){
      self.reload();
    });
  },

  "delete": function(message){
    var messages = this.get('messages');
    var idx = messages.indexOf(message);
    message.delete();
    message.set('selected', false);
    this.set('total', this.get('total')-1);
    this.get('messages').removeObject(message);

    if (idx > 0) {
      message = messages[idx-1];
      message.set('selected', true);
      this.set('currentMessage', message);
    } else {
      if (this.get('total') > 0) {
        message = messages[0];
        message.set('selected', true);
        this.set('currentMessage', message);
      } else {
        this.reload();
      }
    }

  },

  load: function(opts) {
    var self = this;
    opts = opts || {};

    var data = {
      filter: this.get("filter").join("_")
    };

    search = this.get("search");
    if (!_.isEmpty(search)) {
      data.search = search;
      var regexSearch = this.get("regexSearch");
      if(regexSearch) {
        data.regex_search = "true";
      }
    }

    if(opts.before){
      data.before = opts.before;
    }

    if (opts.after){
      data.after = opts.after;
    }

    App.ajax("/messages.json", {
      data: data
    }).success(function(data) {
        if (data.messages.length > 0) {
          var newRows = self.toMessages(data.messages);
          var messages = self.get("messages");
          if (opts.before) {
            messages.unshiftObjects(newRows);
          } else {
            newRows.forEach(function(nmsg) {
              messages.forEach(function(emsg, idx) {
                if (emsg.key == nmsg.key) {
                  messages.removeObject(emsg);
                  if (self.get('currentMessage') === emsg) {
                    // TODO would updateFromJson() work here?
                    self.set('currentMessage', nmsg);
                    nmsg.set('selected', emsg.get('selected'));
                  }
                }
              });
            });
            messages.addObjects(newRows);
            if (newRows.length > 0) {
              App.increaseTitleCount(newRows.length);
            }
          }
        }
        self.set("total", data.total);
     });
  },

  reload: function(){
    this.set("total", 0);
    this.get("messages").clear();

    this.load();
  },

  loadMore: function(){

    var messages = this.get("messages");
    if (messages.length === 0) {
      this.load({});
      return;
    }

    var lastKey = messages[messages.length-1].get("key");
    this.load({
      after: lastKey
    });
  },

  moreBefore: function(){
    return this.get("totalBefore") > 0;
  }.property("totalBefore"),

  totalBefore: function() {
    return this.get("total") - this.get("messages").length;
  }.property("total", "messages.[]"),

  showMoreBefore: function() {
    var messages = this.get("messages");
    var firstKey = messages[0].get("key");

    this.load({
      before: firstKey
    });
  },

  regexSearch: function() {
    search = this.get("search");
    if( search &&
        search.length > 2 &&
        search[0] === "/"
      ){
      var match = search.match(/\/(.*)\/(.*)/);
      if(match && match.length === 3){
        try {
          return new RegExp(match[1], match[2]);
        } catch(err) {
          // don't care
        }
      }
    }
  }.property("search"),

  toMessages: function(messages){
    return messages.map(function(m){
        return App.Message.create(m);
    });
  }
});

App.resetTitleCount = function() {
  App.titleCount = 0;
  document.title = App.title || document.title;
};

(function(){
  var hiddenProperty;
  var visibilitychange;

  $.each(["","webkit","ms","moz","ms"], function(index, prefix){
      var check = prefix + (prefix === "" ? "hidden" : "Hidden");
      if(document[check] !== undefined && !hiddenProperty ){
        hiddenProperty = check;
        visibilitychange = prefix + "visibilitychange";
      }
    });

  App.isHidden = function() {
    if (hiddenProperty !== undefined){
      return document[hiddenProperty];
    } else {
      return !document.hasFocus;
    }
  };

  console.log(visibilitychange);
  document.addEventListener(visibilitychange, function(){
    console.log("BLA +" + App.isHidden());
    if (!App.isHidden()) {
      App.resetTitleCount();
    }
  }, false);
})();


App.increaseTitleCount = function(increment){
  if (!App.isHidden()){
    return;
  }
  App.title = App.title || document.title;
  App.titleCount = App.titleCount || 0;
  App.titleCount += increment;
  document.title = App.title + " (" + App.titleCount + ")";
};

App.IndexRoute = Em.Route.extend({
  model: function(){
    // TODO from preload json?
    return App.MessageCollection.create();
  },

  setupController: function(controller, model) {
    this._super(controller, model);
    controller.setProperties({
      "showDebug": true,
      "showInfo": true,
      "showWarn": true,
      "showErr": true,
      "showFatal": true,
      "search": ''
    });
    controller.set("initialized", true);
    model.reload();

    var times = 0;
    var backoff = 1;

    this.refreshInterval = setInterval(function(){
      times += 1;
      var hidden = App.isHidden();
      var load = !hidden;

      if (hidden) {
        if (times % backoff === 0) {
          load = true;
          if (backoff<20) { backoff++; }
        }
      }
      // refresh a lot less aggressively in background
      if (load) {
        model.loadMore();
        if (!hidden) {
          backoff = 1;
        }
      }

    }, 3000);
  },

  deactivate: function(){
    clearInterval(this.refreshInterval);
  }
});

App.ShowRoute = Em.Route.extend({
  model: function(params) {
    var self = this;
    return new Promise(function(resolve, reject) {
      App.preloadOrAjax("/show/" + params.id + ".json").success(function(json) {
        resolve(App.Message.create(json));
      }).error(reject);
    });
  }
});

App.IndexController = Em.Controller.extend({

  currentMessage: Em.computed.alias('model.currentMessage'),

  actions: {
    expandMessage: function(message){
      message.expand();
    },

    selectMessage: function(message) {
      var old = this.get("currentMessage");
      if (old) {
        old.set("selected",false);
      }

      message.set('selected', true);
      this.set('currentMessage', message);
    },

    showMoreBefore: function(){
      this.get('model').showMoreBefore();
    },

    loadMore: function(){
      return this.get('model').loadMore();
    },

    clear: function() {
      var self = this;
      if (confirm("Clear the logs?\n\nCancel = No, OK = Clear")) {
        App.ajax("/clear", { type: "POST" }).success(function() {
          self.get('model').reload();
        });
      }
    },

    removeMessage: function(msg) {
      var messages = this.get('model');
      messages.delete(msg);
    },

    solveMessage: function(msg) {
      var messages = this.get('model');
      messages.solve(msg);
    }
  },

  filterChanged: function(){
    var severities = ["Debug", "Info", "Warn", "Err", "Fatal"];
    var filter = [];
    for(var i=0; i<5; i++){
      if(this.get("show" + severities[i])){
        filter.push(i);
      }
    }

    // always show unknown, rare
    filter.push(5);
    var model = this.get("model");
    model.set("filter", filter);
    if(this.get("initialized")){
      model.reload();
    }
  }.observes(
      "showDebug",
      "showInfo",
      "showWarn",
      "showErr",
      "showFatal"
    ),

  searchChanged: function(){
    var search = this.get("search");
    var model = this.get("model");
    model.set("search", search);

    if(this.get("initialized")){
      model.reload();
    }
  }.observes(
      "search"
    )

});

App.ShowController = Em.Controller.extend({
  actions: {
    protect: function(message) {
      this.get('model').protect();
    },

    unprotect: function(message) {
      this.get('model').unprotect();
    }
  }
});

App.PanelResizerComponent = Em.Component.extend({
  classNames: ['divider'],
  divideView: function(fromTop, win){
    var $win = win || $(window);
    var height = $win.height();
    var fromBottom = $win.height() - fromTop;

    if (fromTop < 100 || fromTop + 100 > height) {
      return;
    }


    this.topPanel.css("bottom", fromBottom + 5);
    this.bottomPanel.css("height", fromBottom - 15);
    this.divider.css("bottom", fromBottom - 5);
  },

  didInsertElement: function(){
    var self = this;

    // inspired by http://plugins.jquery.com/misc/textarea.js
    this.topPanel = $("#top-panel");
    this.divider = $(".divider");
    this.bottomPanel = $("#bottom-panel");

    var $win = $(window),
        resizing = false;

    var performDrag = function(e){
      if(!resizing) { return; }
      self.divideView(e.clientY, $win);
    };

    var endDrag = function(){
      $("#overlay").remove();
      resizing = false;

      if(localStorage){
        localStorage.logster_divider_bottom = parseInt(self.divider.css("bottom"),10);
      }

      $(document)
          .unbind('mousemove', performDrag)
          .unbind('mouseup', endDrag);
    };

    self.divider.on("mousedown", function(){
      $("<div id='overlay'></div>").appendTo($("body"));
      resizing = true;
      $(document)
        .mousemove(_.throttle(performDrag,25))
        .mouseup(endDrag);
    }).append("<div class='line-1'></div><div class='line-2'></div><div class='line-3'></div>");


    Em.run.next(function(){
      if(localStorage && localStorage.logster_divider_bottom){
        var fromTop = $win.height() - parseInt(localStorage.logster_divider_bottom,10);
        self.divideView(fromTop, $win);
      }
    });
  },

  willDestroyElement: function(){
    $(".divider").off("mousedown");
  }
});


App.MessageRowComponent = Em.Component.extend({

  tagName: "tr",

  classNameBindings: ["model.rowClass", ":message-row", "model.selected:selected"],

  click: function() {
    this.sendAction('selectedMessage', this.get('model'));
  },

  willInsertElement: function(){
    if (App.MessageRowComponent._checkedBottom) {
      return;
    }

    var $topPanel = $("#top-panel");

    var scrollTop = $topPanel.scrollTop();
    var height = $topPanel.height();
    var scrollHeight = $topPanel[0].scrollHeight;

    App.MessageRowComponent._stickToBottom = scrollHeight - 20 < height + scrollTop;
    App.MessageRowComponent._checkedBottom = true;
  },

  didInsertElement: function(){
    var self = this;
    var $topPanel = $("#top-panel");
    Em.run.next(function(){
      App.MessageRowComponent._checkedBottom = false;

      if (App.MessageRowComponent._stickToBottom){
        App.MessageRowComponent._stickToBottom = false;
        $topPanel.scrollTop($topPanel[0].scrollHeight - $topPanel.height());
      }
    });
  }
});

App.UpdateTimeComponent = Em.Component.extend({
  didInsertElement: function(){
    var updateTimes = function(){
      $('.auto-update-time').each(function(){
        var timestamp = parseInt(this.getAttribute('data-timestamp'),10);
        var elem = this;

        var text = App.formatTime(timestamp);

        if(text !== elem.innerText) {
          elem.innerText = text;
        }

      });
      Em.run.later(updateTimes, 60000);
    };

    Em.run.later(updateTimes, 60000);
  }
});

App.TimeFormatterComponent = Ember.Component.extend({
  tagName: 'span',
  classNames: 'auto-update-time',
  attributeBindings: ['data-timestamp', 'title'],

  title: function(){
    return this.get('moment').format();
  }.property(),

  "data-timestamp": function(){
    return this.get('timestamp');
  }.property(),

  moment: function(){
    return moment(this.get("timestamp"));
  }.property(),

  render: function(buffer){
    buffer.push(App.formatTime(this.get('timestamp')));
  },
});

App.formatTime = function(timestamp){
  var formatted;
  var time = moment(timestamp);
  var now = moment();

  if (time.diff(now.startOf('day')) > 0) {
    formatted = time.format('h:mm a');
  } else {
    if (time.diff(now.startOf('week')) > 0) {
      formatted = time.format('dd h:mm a');
    } else {
      if (time.diff(now.startOf('year')) > 0) {
        formatted = time.format('D MMM h:mm a');
      } else {
        formatted = time.format('D MMM YY');
      }
    }
  }

  return formatted;
};

App.TabbedSectionComponent = Ember.Component.extend({
  tabs: Em.A(),
  selectTab: function(view) {
    if (view.get('isLink')) {
      this.triggerAction(view.get('action'));
      return;
    }

    var selected = this.get("selected");
    if (selected) {
      selected.set("active", false);
    }
    this.set("selected", view);
    view.set("active", true);
  },
  addTab: function(tab) {
    this.get("tabs").addObject(tab);
    if (!this.get("selected") && !tab.get('isLink')) {
      this.selectTab(tab);
    }
  },
  removeTab: function(tab) {
    if (this.get("selected") === tab) {
      this.set("selected", null);
    }
    this.get("tabs").removeObject(tab);
  }
});

App.TabContentsComponent = Ember.Component.extend({
  classNameBindings: ["active", ":content"],
  isLink: false,

  invokeParent: function(name) {
    var current = this.get("parentView");
    while (current && !current[name]) {
      current = current.get("parentView");
    }
    if (current) {
      current[name](this);
    }
  },

  didInsertElement: function() {
    this.invokeParent("addTab");
    if (this.get("defaultTab")) {
      this.invokeParent("selectTab");
    }
  },
  willDestroyElement: function() {
    this.invokeParent("removeTab");
  },

});

App.MessageInfoComponent = Ember.Component.extend({
  actions: {
    protect: function(){
      this.get('currentMessage').protect();
    },
    unprotect: function(){
      this.get('currentMessage').unprotect();
    },
    "remove": function(){
      this.sendAction("removeMessage", this.get('currentMessage'));
    },
    solve: function() {
      this.sendAction("solveMessage", this.get('currentMessage'));
    }
  }
});

App.TabLinkComponent = App.TabContentsComponent.extend({
  isLink: true
});
