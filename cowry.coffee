(($) ->
  @RouteControllers = []
  @ModelCollections = []
  
  class Route
    constructor: (routeHash) ->
      @parameterNames = _.map routeHash.route.match( /(\w+):/g), (element) ->
        element.replace(/:/, '')
      @routeRegEx = new RegExp("^" + routeHash.route.replace(/([\w\d]+):/, '') + "$")
      
      # if we already have an instance of this controller use it; else make a new one
      console.log "Loading controller: #{routeHash.controller}"
      @controller = RouteControllers[routeHash.controller] || new window[routeHash.controller]
      @action = routeHash.action
       
      # put either the new controller into the array or the old one again
      RouteControllers[routeHash.controller] = @controller
      if @controller.after_create
        @controller.after_create()
      
    invoke: (parameterValues, element, event) ->
      try
        params = _.inject @parameterNames, (accumulator, element, index) ->
          accumulator[element] = parameterValues[index+1]
          return accumulator
        ,{}
        params.element = element
        params.event = event
        
        console.log("#{@controller.__proto__.constructor.toString().match(/function ([^\(]*)/)[1]} #{@action}")
        @controller[@action] params
      catch error
        console.log "Something went wrong: #{error.message} \n source: #{error.sourceURL} \n line: #{ error.line}";
  
  class @RouteManager
    constructor: ->
      $(document).click (event) =>
        element = if $(event.target).attr('href') then event.target else $(event.target).closest('[href]')[0]
        return unless element?
        
        routeString = $(element).attr("href")
        
        for route in @routes
          parameterMatches = routeString.match(route.routeRegEx)
          if parameterMatches
            event.preventDefault()
            route.invoke(parameterMatches, element, event)
            break
      @parseRoutes()
    
    parseRoutes: ->
      @routes = []
      return unless Routes?
      _.each Routes, (routeHash) =>
        @routes.push(new Route(routeHash))
  
  class @Model
    constructor: (modelInfo, @viewcallback = null) ->
      _.each _.keys( modelInfo ), (key) =>
        @[key] = modelInfo[key]
    
    create: (after_create = null)->
      $.ajax
        url: "/#{@resourceUrl()}#{@model.extension||".json"}",
        data: @
        method: 'post'
        success: (data, status, xhr) =>
          console.log transport.responseText
        failure: (data, status, xhr) =>
          throw "Failed to save model"
      this
    
    save: (after_save = null) ->
      $.ajax
        url: "{@myUrl()}"
        data: @
        method: 'post'
        success: (data, status, xhr) =>
          console.log transport.responseText
        failure: (data, status, xhr) =>
          throw "Failed to save model"
      this
    
    destroy: ->
      $.ajax
        url: "#{@myUrl()}#{@model.extension||".json"}",
        method: 'delete'
    
    my_url: ->
      "#{@.__proto__.constructor.resourceURL()}/#{@id}"
      
    @all: (callback) ->
      if window.ModelCollections[@className()]
        callback(window.ModelCollections[@className()])
      else
        window.ModelCollections[@className()] = new ModelCollection(@, null, callback)
    
    @find: (id, callback) ->
      if window.ModelCollections[@className()]
        callback(window.ModelCollections[@className()].find(id))
      else
        $.ajax
          url: "/#{@className().toLowerCase()}/#{id}#{@__proto__.extension || ".json"}"
          success: (data, status, xhr) ->
            callback(@(data))
          
    @className: ->
      @toString().match(/function ([^\(]*)/)[1]
    
    className: ->
      @__proto__.constructor.toString().match(/function ([^\(]*)/)[1]
      
  class @Controller
    constructor: ->
      @setup() if @setup
      @contentIndexDivs = $('.cowry_index')
      @contentShowDivs = $('.cowry_show')
  
    index: (params, secondaryCallback = null) ->
      @getIndexContent (content) =>
        @contentIndexDivs.each (index, element) =>
          @populateDiv element, content, 'Index', secondaryCallback
        @view['indexComplete'](content) if @view['indexComplete']?
      , params
  
    getIndexContent: (callback, params) ->
      callback(@controller_content)
    
    show:(params, secondaryCallback = null)->
      @getShowContent (content) =>
        @contentShowDivs.each (index, element) =>
          @populateDiv element, content, 'Show', secondaryCallback
        @view['showComplete'](content) if @view['showComplete']?
      , params
      
    getShowContent: (callback, params) ->
      callback(@controller_content)
      
    populateDiv: (element, content, action, callback) ->
      divName = _.last(element.className.split(/\s+/))
      if @view["#{divName}#{action}Template"]?
        $(element).children().remove()
        if @view["get#{divName}#{action}JSON"]?
          content = Mustache.to_html(@view["#{divName}#{action}Template"], @view["get#{divName}#{action}JSON"](content))
        else
          content = Mustache.to_html(@view["#{divName}#{action}Template"], content)
        $(element).append(content)
      @view["#{divName}#{action}Complete"]() if @view["#{divName}#{action}Complete"]?
      callback() if callback
  
  class @View
    constructor: ->
    
  class @ModelCollection extends Array
    constructor: (@model, associations, @callbackCompletion) ->
      @resourceName = @model.resourceURL associations
      if @model.extension?
        requestURL = "#{@resourceName}#{@model.extension}"
      else
        requestURL = "#{@resourceName}.json"
      new Ajax.Request requestURL,
        method: 'get'
        onSuccess: @callbacks.addUpdates.bind this
    
    find: (id) =>
      @detect (element) =>
        element.id == id
    
    deleteElement: (id) =>
      @reject (element) ->
        element.id == id
      
    callbacks:
      addUpdates: (transport) ->
        for model in ( transport.responseJSON || $.parseJSON(transport.responseText).rows )
          if model.class_name?
            @push new window[model.class_name](model)
          else
            @push new @model(model) 
        if @callbackCompletion?
          @callbackCompletion @
    
    toArray: ->
      @inject [], (acc, element) ->
        acc.push(element)
        acc


)(jQuery)