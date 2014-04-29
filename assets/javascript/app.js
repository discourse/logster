App = Ember.Application.create({
});

App.ajax =  function(url, settings) {
  return $.ajax(Logger.rootPath + url, settings);
};


App.Router.map(function(){
  this.route("index", { path: "/" });
});

App.Message = Ember.Object.extend({});

App.Message.reopenClass({
  latest: function(){
    return App.ajax("/messages.json")
      .success(function(data){
        var messages = Em.A();
        messages.forEach(function(o){
          messages.pushObject(o);
        });
        return messages;
      });
  }
});

App.IndexRoute = Em.Route.extend({
  model: function(){
    return App.Message.latest();
  }
});

Handlebars.registerHelper('timeAgo', function(prop, options){
  var timestamp = Ember.Handlebars.get(this, prop, options);
  return moment(timestamp).fromNow();
});
