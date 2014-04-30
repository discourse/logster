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

App.Message.reopenClass({
  latest: function(){
    var promise = Ember.Deferred.create();

    App.ajax("/messages.json")
      .success(function(data){
        var messages = Em.A();
        data.forEach(function(o){
          messages.pushObject(App.Message.create(o));
        });
        promise.resolve(messages);
      });

    return promise;
  }
});

App.IndexRoute = Em.Route.extend({
  model: function(){
    return App.Message.latest();
  }
});

App.IndexController = Em.Controller.extend({
  expandMessage: function(message){
    message.expand();
  }
});

Handlebars.registerHelper('timeAgo', function(prop, options){
  var timestamp = Ember.Handlebars.get(this, prop, options);
  return moment(timestamp).fromNow();
});
