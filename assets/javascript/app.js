App = Ember.Application.create({
});

App.ajax =  function(url, settings) {
  settings = settings || {};
  settings.headers = settings.headers || {};
  settings.headers["X-SILENCE-LOGGER"] = true;
  return $.ajax(Logger.rootPath + url, settings);
};


App.Router.map(function(){
  this.route("index", { path: "/" });
});

App.Message = Ember.Object.extend({

  MAX_LEN: 200,

  expand: function(){
    this.set("expanded",true);
  },

  hasMore: function(){
    var message = this.get("message");
    var expanded = this.get("expanded");

    return !expanded && message.length > this.MAX_LEN;
  }.property("message", "expanded"),

  displayMessage: function(){
    var message = this.get("message");
    var expanded = this.get("expanded");

    if(!expanded && message.length > this.MAX_LEN){
      message = message.substr(0,this.MAX_LEN);
    }
    return message;
  }.property("message","expanded"),

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
    }

  }.property("severity")
});

App.MessageCollection = Em.Object.extend({
  loadMore: function(){
    var self = this;
    var messages = this.get("messages");
    var lastKey = messages[messages.length-1].get("key");

    App.ajax("/messages.json?after="+lastKey)
       .success(function(data){
          if(data.messages.length > 0) {
            var messages = App.MessageCollection.toMessages(data.messages);
            self.get("messages").addObjects(messages);
          }
          self.set("total",data.total);
       });
  },

  moreBefore: function(){
    return this.get("totalBefore") > 0;
  }.property("totalBefore"),

  totalBefore: function() {
    return this.get("total") - this.get("messages").length;
  }.property("total", "messages.@each"),

  showMoreBefore: function() {
    var self = this;
    var messages = this.get("messages");
    var firstKey = messages[0].get("key");

    App.ajax("/messages.json?before="+firstKey)
       .success(function(data){
          var messages = App.MessageCollection.toMessages(data.messages);
          self.get("messages").unshiftObjects(messages);
          self.set("total",data.total);
       });
  }
});

App.MessageCollection.reopenClass({
  toMessages: function(messages){
    return messages.map(function(m){
        return App.Message.create(m);
    });
  },
  latest: function(){
    var self = this;
    var promise = Em.Deferred.create();

    App.ajax("/messages.json")
      .success(function(data){
        var messages = Em.A();
        messages.addObjects(self.toMessages(data.messages));
        promise.resolve(
          App.MessageCollection.create({
            messages: messages,
            total: data.total
          })
        );
      });

    return promise;
  }
});

App.IndexRoute = Em.Route.extend({
  model: function(){
    return App.MessageCollection.latest();
  },

  setupController: function(controller, model){
    this._super(controller, model);
    controller.set("showDebug",true);
    controller.set("showInfo",true);
    controller.set("showWarn",true);
    controller.set("showErr",true);
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
    }
  },

  checkIfAtBottom: function(){
    this.stickToBottom = window.innerHeight + window.scrollY > document.body.offsetHeight;
  }
});

App.IndexView = Em.View.extend({
  didInsertElement: function(){
    var self = this;
    this.refreshInterval = setInterval(function(){
      self.get('controller').send("loadMore");
    }, 3000);
  },

  willDestroyElement: function(){
    clearInterval(this.refreshInterval);
  }
});

App.MessageView = Em.View.extend({
  templateName: "message",

  tagName: "tr",

  classNameBindings: ["context.rowClass", "hidden:hidden"],

  hidden: function(){
    var controller = this.get("controller");
    var context = this.get("context");

    switch(context.get("severity")){
      case 0:
        return !controller.get("showDebug");
      case 1:
        return !controller.get("showInfo");
      case 2:
        return !controller.get("showWarn");
      case 3:
        return !controller.get("showErr");
    }
  }.property(
      "controller.showDebug",
      "controller.showInfo",
      "controller.showWarn",
      "controller.showErr"
    ),

  willInsertElement: function(){
    this.get("controller").checkIfAtBottom();
  },

  didInsertElement: function(){
    var self = this;
    Em.run.next(function(){
      if (self.get("controller.stickToBottom")){
        self.set("controller.stickToBottom", false);
        $(window).scrollTop($(document).height());
      }
    });
  }
});

Handlebars.registerHelper('timeAgo', function(prop, options){
  var timestamp = Ember.Handlebars.get(this, prop, options);
  return moment(timestamp).fromNow();
});
