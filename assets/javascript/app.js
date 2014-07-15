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

App.Router.map(function(){
  this.route("index", { path: "/" });
  this.route("show", { path: "/show/:id" });
});

App.Message = Ember.Object.extend({

  MAX_LEN: 200,

  expand: function() {
    this.set("expanded", true);
  },

  protect: function() {
    this.set('protected', true);
    return App.ajax("/protect/" + this.get('key'), { type: "PUT" });
  },
  unprotect: function() {
    this.set('protected', false);
    return App.ajax("/unprotect/" + this.get('key'), { type: "DELETE" });
  },

  hasMore: function(){
    var message = this.get("message");
    var expanded = this.get("expanded");

    return !expanded && message.length > this.MAX_LEN;
  }.property("message", "expanded"),

  shareUrl: function() {
    return Logger.rootPath + "/show/" + this.get('key');
  }.property("key"),

  protectUrl: function() {
    return Logger.rootPath + (this.get('protected') ? '/unprotect/' : '/protect/') + this.get('key');
  }.property("key"),

  displayMessage: function() {
    var message = this.get("message");
    var expanded = this.get("expanded");

    if(!expanded && message.length > this.MAX_LEN){
      message = message.substr(0,this.MAX_LEN);
    }
    return message;
  }.property("message", "expanded"),

  showCount: function() {
    var count = this.get('count');
    if (count <= 1) {
      return "";
    } else {
      return "x" + count;
    }
  }.property("count"),

  envDebug: function(){
    var env = this.get("env");
    if(env){
      var buffer = [];
      _.each(env, function(v,k){
        if(k !== "params"){
          buffer.push(k + ": " + v);
        }
      });

      buffer.push("");
      if(_.size(env.params) > 0){
        buffer.push("Params:");
        buffer.push("");
        _.each(env.params, function(v,k){
          buffer.push("  " + k + ": " + v);
        });
      }
      return buffer.join("\n");
    }

  }.property("env"),

  rowClass: function() {
    switch(this.get("severity")){
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

  glyph: function(){
    switch(this.get("severity")){
      case 0:
        return "";
      case 1:
        return "";
      case 2:
        return "x";
      case 3:
        return "!";
      case 4:
        return "!!";
    }
  }.property("severity")
});

App.MessageCollection = Em.Object.extend({

  messages: Em.A(),
  total: 0,

  load: function(opts){
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
            messages.addObjects(newRows);
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
  }.property("total", "messages.@each"),

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
  actions: {
    expandMessage: function(message){
      message.expand();
    },

    showMoreBefore: function(){
      this.get('model').showMoreBefore();
    },

    loadMore: function(){
      return this.get('model').loadMore();
    },

    clear: function() {
      var self = this;
      App.ajax("/clear", { type: "POST" }).success(function() {
        self.get('model').reload();
      });
    },

    protect: function(message) {
      this.get('currentMessage').protect().success(function() {
        self.transitionToRoute("show", {id: self.get('key')});
      });
    },

    unprotect: function(message) {
      this.get('currentMessage').unprotect();
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
    ),


  checkIfAtBottom: function(){
    if (this.checkedBottom) {
      return;
    }

    var $topPanel = $("#top-panel");

    var scrollTop = $topPanel.scrollTop();
    var height = $topPanel.height();
    var scrollHeight = $topPanel[0].scrollHeight;

    this.stickToBottom = scrollHeight - 20 < height + scrollTop;
    this.checkedBottom = true;
  }
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

App.IndexView = Em.View.extend({
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
    this.refreshInterval = setInterval(function(){
      self.get('controller').send("loadMore");
    }, 3000);

    // inspired by http://plugins.jquery.com/misc/textarea.js
    this.topPanel = $("#top-panel");
    this.divider = $("#divider");
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
    $("#divider").off("mousedown");
    clearInterval(this.refreshInterval);
  }
});

App.MessageView = Em.View.extend({
  templateName: "message",

  tagName: "tr",

  classNameBindings: ["context.rowClass", ":message-row", "context.selected:selected"],

  click: function(){
    var old = this.get("controller.currentMessage");
    if(old){
      old.set("selected",false);
    }
    this.set("context.selected", true);
    this.set("controller.currentMessage", this.get("context"));
  },

  willInsertElement: function(){
    this.get("controller").checkIfAtBottom();
  },

  didInsertElement: function(){
    var self = this;
    var $topPanel = $("#top-panel");
    Em.run.next(function(){
      self.set("controller.checkedBottom", false);

      if (self.get("controller.stickToBottom")){
        self.set("controller.stickToBottom", false);
        $topPanel.scrollTop($topPanel[0].scrollHeight - $topPanel.height());
      }
    });
  }
});

App.ApplicationView = Em.View.extend({
  didInsertElement: function(){
    var updateTimes = function(){
      $('.auto-update-time').each(function(){
        var newTime = moment(
            parseInt(this.getAttribute('data-timestamp'),10)
          ).fromNow(),
            elem = this;

        if(newTime != elem.innerText) {
          elem.innerText = newTime;
        }

      });
      Em.run.later(updateTimes, 10000);
    };

    Em.run.later(updateTimes, 10000);
  }
});

Handlebars.registerHelper('timeAgo', function(prop, options){
  var timestamp = Ember.Handlebars.get(this, prop, options);
  var parsed = moment(timestamp);
  var formatted = "<span data-timestamp='" + timestamp + "' class='auto-update-time' title='" + parsed.format() +  "'>" + parsed.fromNow() + "</span>";

  return new Handlebars.SafeString(formatted);
});

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
  },
  willDestroyElement: function() {
    this.invokeParent("removeTab");
  }
});

App.TabLinkComponent = App.TabContentsComponent.extend({
  isLink: true
});
