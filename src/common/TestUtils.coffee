return unless Velocity?

# jasmine.DEFAULT_TIMEOUT_INTERVAL = jasmine.getEnv().defaultTimeoutInterval = 20000

Logger.setLevel('debug')

TestUtils =
  
  _config: null
  _readyDf: null
  _isInit: false

  config: (args) ->
    unless args? then return @_config
    if @_config then throw new Error('TestUtils.config() already called.')
    @_readyDf = Q.defer()
    @_config = Setter.merge {}, args
    Logger.info('Setting up TestUtils...')
    queue = new DeferredQueue()
    queue.add ->
      return unless Meteor.isClient
      df = Q.defer()
      Meteor.logout (result) -> df.resolve(result)
      df.promise
    queue.add -> TestUtils.resetDatabase()
    queue.waitForAll().then(
      =>
        Logger.info('Set up TestUtils')
        @_isInit = true
        # If an onReady() hook was used, wait until it is complete.
        Q.when(@_config.onReady?()).then => @_readyDf.resolve()
      (err) =>
        Logger.info('Failed to set up TestUtils')
        @_readyDf.reject()
    )
    @_readyDf.promise

  loadFixture: (args) ->
    Logger.info('Loading test fixture:', args)
    # Allows onReady() code to load fixtures before other modules are alerted that TestUtils is
    # ready.
    if @_isInit then return @_loadFixture(args)

    # Wait for setup to complete before loading fixtures.
    df = Q.defer()
    @_readyDf.promise.fail(df.reject)
    unless @_readyDf.promise.isFulfilled()
      Logger.info('Waiting for TestUtils setup...')
    @_readyDf.promise.then => df.resolve @_loadFixture(args)
    df.promise

  _loadFixture: (args) ->
    df = Q.defer()
    Logger.info('Loading test fixture on server:', args)
    Meteor.call 'tests/loadFixture', args, (err, result) ->
      if err
        Logger.error('Failed to load test fixture', err)
        df.reject(err)
      else
        Logger.info('Loaded test fixture', args)
        df.resolve(result)
    df.promise
  
  resetDatabase: (args) ->
    Logger.info('Resetting test database on server...')
    df = Q.defer()
    Meteor.call 'tests/resetDatabase', args, (err, result) ->
      if err
        Logger.error('Failed to reset test database on server', err)
        df.reject(err)
      else
        Logger.info('Reset test database on server', args)
        df.resolve(result)
    df.promise

  ready: -> @_readyDf.promise
