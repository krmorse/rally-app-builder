request = require 'request'
cheerio = require 'cheerio'
fs = require 'fs'
async = require 'async'

class Deploy
  constructor: (@username, @password, @server) ->
    @server ?= 'rally1.rallydev.com'
    @logger = console.log.bind(console)

  _loadHomePage: (res, b, cb) ->
    me = @
    options =
      url: "https://#{@server}/"
      method: 'GET'

    request options, (err, res, body) ->
      cb(err, res, body)

  _createDashboardPage: (res, b, cb) ->
    @logger('Calling _createDashboardPage')

    mtab = @tab or 'myhome'
    options =
      url: "https://#{@server}/slm/wt/edit/create.sp"
      method: 'POST'
      jar: true
      followAllRedirects: true
      form:
        name: @name
        #html: content
        type: 'DASHBOARD'
        timeboxFilter: 'none'
        pid: mtab
        editorMode: 'create'
        cpoid: @cpoid
        version: 0

    request(options, cb)

  _parseNewDashboardPageBody: (results, body, cb) ->
    @logger("Loading cheerio")
    cb(null, cheerio.load(body))

  _getCatalogPanels: ($, cb) ->
    @logger("Cheerio loaded")

    @dashboardOid = $('input[name="oid"]').val()

    options =
      url: "https://#{@server}/slm/panel/getCatalogPanels.sp?cpoid=#{@cpoid}&ignorePanelDefOids&gesture=getcatalogpaneldefs&_slug=/custom/#{@dashboardOid}",
      jar: true
      method: 'GET'
      followAllRedirects: true

    request(options, cb)

  _createCustomHtmlApp: (results, body, cb) ->
    @logger('Calling _createCustomHtmlApp')
    panels = JSON.parse body

    for p in panels
      ptoid = p.oid if p.title is "Custom HTML"

    options =
      url: "https://#{@server}/slm/dashboard/addpanel.sp?cpoid=#{@cpoid}&_slug=/custom/#{@dashboardOid}"
      method: 'POST'
      jar: true
      followAllRedirects: true
      form:
        panelDefinitionOid: ptoid
        col: 0
        index: 0
        dashboardName: "#{@tab}#{@dashboardOid}"
        gestrure: 'addpanel'

    request(options, cb)

  _changePanelSettings: (results, body, cb) ->
    @logger('Calling _changePanelSettings')

    @panelOid = JSON.parse(body).oid

    options =
      url: "https://#{@server}/slm/dashboard/changepanelsettings.sp?cpoid=#{@cpoid}&_slug=/custom/#{@dashboardOid}"
      method: 'POST'
      followAllRedirects: true
      jar: true
      form:
        oid: @panelOid
        dashboardName: "#{@tab}#{@dashboardOid}"
        settings: JSON.stringify {title: @name, content: @content}
        gestrure: 'changepanelsettings'

    request(options, cb)


  _setSinglePageLayout: (results, body, cb) ->
    @logger('Calling _setSinglePageLayout')
    options =
      url: "https://#{@server}/slm/dashboardSwitchLayout.sp?cpoid=#{@cpoid}&layout=SINGLE&dashboardName=#{@tab}#{@dashboardOid}&_slug=/custom/#{@dashboardOid}"
      method: 'GET'

    request(options, cb)

  _finish: (results, body, cb) -> 
    @logger('Calling _finish')
    cb(null)

  createNewPage: (cpoid, name, content, tab, shared, callback) ->
    @logger("Calling New Page")
    @tab = tab
    @name = name
    @cpoid = cpoid
    @content = content
    @shared = shared
    me = @

    @dashboardOid = 0
    @panelOid = 0

    tasks = [
      @_login.bind(me),
      @_loadHomePage.bind(me),
      @_createDashboardPage.bind(me),
      @_parseNewDashboardPageBody.bind(me),
      @_getCatalogPanels.bind(me),
      @_createCustomHtmlApp.bind(me),
      @_changePanelSettings.bind(me),
      @_setSinglePageLayout.bind(me),
      @_finish.bind(me)
    ]

    async.waterfall tasks, (err) =>
      @logger('Tasks are done.  Retuning')
      callback(null, @dashboardOid, @panelOid)

  updatePage: (doid, poid, cpoid, name, tab, content, callback) ->
    #callback ?= () ->

    @_login (err, res, b) ->
      mtab = tab or 'myhome'

      options =
        url: "https://#{@server}/slm/dashboard/changepanelsettings.sp?cpoid=#{cpoid}&_slug=/custom/#{doid}"
        method: 'POST'
        jar: true
        followAllRedirects: true
        form:
          oid: poid
          dashboardName: "#{tab}#{doid}"
          settings: JSON.stringify {title: name, content: content}
          gestrure: 'changepanelsettings'

      request options, (error, results, body) ->
        callback()

  _login: (callback) ->
    #callback ?= () ->
    @logger("Calling _login")

    ###
    options =
      url: "https://#{@server}/slm/platform/j_platform_security_check.op"
      method: 'POST'
      form:
        j_username: @username
        j_password: @password
    ###

    options =
      url: "https://#{@server}/slm/webservice/v2.0/security/authorize"
      method: 'GET'
      followAllRedirects: true
      jar: true
      auth:
        user: @username
        pass: @password
        sendImmediately: true

    request options, (err, res, body) =>
      callback(err, res, body)

exports.Deploy = Deploy
