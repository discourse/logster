App = Ember.Application.create({
});

App.ajax =  function(url, settings) {
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
            self.set("messages", self.get("messages").concat(messages));
          }
          self.set("total",data.total);
       });
  },
  moreBefore: function(){
    return this.get("totalBefore") > 0;
  }.property("totalBefore"),

  totalBefore: function() {
    return this.get("total") - this.get("messages").length;
  }.property("total", "messages"),

  showMoreBefore: function() {
    var self = this;
    var messages = this.get("messages");
    var firstKey = messages[0].get("key");

    App.ajax("/messages.json?before="+firstKey)
       .success(function(data){
          var messages = App.MessageCollection.toMessages(data.messages);
          self.set("messages", messages.concat(self.get("messages")));
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
        promise.resolve(
          App.MessageCollection.create({
            messages: self.toMessages(data.messages),
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
  }
});

App.IndexController = Em.Controller.extend({
  expandMessage: function(message){
    message.expand();
  },

  showMoreBefore: function(){
    this.get('model').showMoreBefore();
  },

  loadMore: function(){
    return this.get('model').loadMore();
  }
});

App.IndexView = Em.View.extend({
  didInsertElement: function(){
    var self = this;
    this.refreshInterval = setInterval(function(){
      self.get('controller').loadMore();
    }, 3000);
  },

  willDestroyElement: function(){
    clearInterval(this.refreshInterval);
  }
});

Handlebars.registerHelper('timeAgo', function(prop, options){
  var timestamp = Ember.Handlebars.get(this, prop, options);
  return moment(timestamp).fromNow();
});
