return unless Velocity?

# jasmine.DEFAULT_TIMEOUT_INTERVAL = jasmine.getEnv().defaultTimeoutInterval = 20000

TestUtils =
  
  _config: null
  _readyDf: null

  config: (args) ->
    unless args? then return @_config
    if @_config then throw new Error('TestUtils.config() already called.')
    @_readyDf = Q.defer()
    @_config = Setter.merge {
    }, args
    Logger.info('Setting up TestUtils...')
    TestUtils.resetDatabase().then =>
      console.log('onReady')
      @_readyDf.resolve()
      @_config.onReady?()
  
  loadFixture: (args) ->
    # Wait for setup to complete before loading fixtures.
    df = Q.defer()
    @_readyDf.promise.fail(df.reject)
    @_readyDf.promise.then ->
      df.resolve Promises.serverMethodCall 'tests/loadFixture', args
    df.promise
  
  resetDatabase: (args) -> Promises.serverMethodCall 'tests/resetDatabase', args

# if Meteor.isServer

#   console.log('Server!')
#   # Jasmine.onTest ->
#   console.log('onTest!')
#   beforeAll ->
#     console.log('beforeAll!')
