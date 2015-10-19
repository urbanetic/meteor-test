return unless Velocity?

global = @

TestUtils =
  
  _config: null
  _readyDf: null
  _isInit: false

  config: (args) ->
    unless args? then return @_config
    if @_config then throw new Error('TestUtils.config() already called.')
    Logger.setLevel('debug')
    @_readyDf = Q.defer()
    @_config = Setter.clone args
    Logger.debug('Setting up TestUtils...')
    queue = new DeferredQueue()

    # Logout of the app.
    queue.add ->
      return unless Meteor.isClient
      df = Q.defer()
      Meteor.logout (result) -> df.resolve(result)
      df.promise

    # Reset the database.
    queue.add -> TestUtils.resetDatabase()

    queue.waitForAll().then(
      Meteor.bindEnvironment =>
        Logger.debug('Set up TestUtils')
        @_isInit = true
        # If an onReady() hook was used, wait until it is complete.
        Q.when(@_config.onReady?()).then => @_readyDf.resolve()
      Meteor.bindEnvironment (err) =>
        Logger.error('Failed to set up TestUtils')
        @_readyDf.reject()
    )
    if args.done then @_readyDf.promise.fin(args.done)
    @_readyDf.promise

  # Loads the fixtures specified in the arguments.
  #
  # * `args.type` - The type of fixtures to load. This will typically be the name of the collection
  #   to which the features belong. This is required.
  # * `args.name` - The name (or array of names) of the fixtures of the given `type` to load. Each
  #   fixture type will represent a map of feature name to content. The contents of each of the
  #   named fixtures will be loaded.
  #   If name is not specified, then all features of `type` will be loaded.
  #
  # If `args` is given as a simple string, it will be used as the `type` argument. If the string
  # contains a period, it will be interpreted as a path to a specific fixture (e.g. `feature.foo`
  # would load the fixture of type `feature` named `foo`).
  loadFixture: (args) ->
    Logger.debug('Loading test fixture:', args)
    # Allows onReady() code to load fixtures before other modules are alerted that TestUtils is
    # ready.
    if @_isInit then return @_loadFixture(args)

    # Wait for setup to complete before loading fixtures.
    df = Q.defer()
    @_readyDf.promise.fail(df.reject)
    unless @_readyDf.promise.isFulfilled()
      Logger.debug('Waiting for TestUtils setup...')
    @_readyDf.promise.then => df.resolve @_loadFixture(args)
    df.promise

  _loadFixture: (args) ->
    df = Q.defer()
    Logger.debug('Loading test fixture on server:', args)
    Meteor.call 'tests/loadFixture', args, (err, result) ->
      if err
        Logger.error('Failed to load test fixture', err)
        df.reject(err)
      else
        Logger.debug('Loaded test fixture', args)
        df.resolve(result)
    df.promise
  
  resetDatabase: (args) ->
    Logger.debug('Resetting test database on server...')
    df = Q.defer()
    Meteor.call 'tests/resetDatabase', args, (err, result) ->
      if err
        Logger.error('Failed to reset test database on server', err)
        df.reject(err)
      else
        Logger.debug('Reset test database on server', args)
        df.resolve(result)
    df.promise

  ready: -> @_readyDf.promise

  chai: Package['practicalmeteor:chai']
