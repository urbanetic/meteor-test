return unless process.env.IS_MIRROR

fs = Npm.require('fs')
Future = Npm.require('fibers/future')
coffee = Npm.require('coffee-script')
path = Npm.require('path')

privateAssetsPath = path.join process.cwd(), 'assets', 'app'

resetDatabase = ->
  Logger.info('Resetting test database')
  unless process.env.IS_MIRROR
    throw new Meteor.Error(500, 'Cannot reset database - not running in Velocity mirror')

  fut = new Future()
  collectionsRemoved = 0
  db = MongoInternals.defaultRemoteCollectionDriver().mongo.db
  db.collections (err, collections) ->
    appCollections = _.reject collections, (col) ->
      col.collectionName.indexOf('velocity') == 0 || col.collectionName == 'system.indexes'
    if appCollections.length > 0
      _.each appCollections, (appCollection) ->
        appCollection.remove (e) ->
          if (e)
            Logger.error('Failed removing collection', e)
            fut.return('fail: ' + e)
          collectionsRemoved++
          Logger.info 'Removed collection', appCollection.collectionName
          if appCollections.length == collectionsRemoved
            Logger.info('Finished resetting database')
            fut.return('success')
    else
      Logger.info('No collections found. No need to reset anything.')
      fut.return('success')
  fut.wait()

loadFixture = (args) ->
  # TODO(aramk) Not sure what is calling this module with null args.
  unless args then return
  Logger.info('Loading test fixture', args)
  assetPath = args.path ? args
  unless assetPath then throw new Error('No path specified for loading fixture:' + args)

  # NOTE: Assets.getText() doesn't allow packages access to the app's private assets, so we
  # read them manually.
  # https://github.com/meteor/meteor/issues/1382
  assetPath = path.join(privateAssetsPath, assetPath)
  console.log('assetPath', assetPath)
  asset = fs.readFileSync assetPath, 'utf8'

  # asset = Assets.getText(path)
  unless asset
    throw new Error('Fixture not found at path: ' + assetPath)

  console.log('asset!!!!', asset)
  fixture = parseFixtureAsset(asset, assetPath)
  console.log('fixture!!!!', fixture)

  _.each fixture, (docs, collectionId) ->
    isUserCollection = collectionId == 'users'
    if isUserCollection
      collection = Meteor.users
    else
      collectionName = Strings.toTitleCase(collectionId)
      collection = Collections.get(collectionName)
    unless collection
      throw new Error('Collection not found: ' + collectionId)
    
    _.each docs, (doc) ->
      origDoc = doc
      if isUserCollection
        doc = Setter.clone(origDoc)
        delete doc.password
      origDoc._id = collection.direct.insert(doc)

    if isUserCollection
      _.each docs, (doc) -> Accounts.setPassword(doc._id, doc.password)
    else if collection == Projects
      _.each docs, (doc) ->
        entities = doc.entities
        _.each entities, (entity) ->
          entity.projectId = doc._id
          Entities.direct.insert(entity)
          Logger.info('Inserted', entities.length, 'entities in project', doc._id)

    Logger.info('Test fixtures: Inserted', docs.length, collectionId)

parseFixtureAsset = (asset, assetPath) ->
  extension = Paths.getExtension(assetPath)
  if extension == 'json'
    JSON.parse(asset)
  else if _.contains(['yml', 'yaml'], extension)
    console.log('parsing a YAML file')
    try
      YAML.safeLoad(asset)
    catch e
      msg = 'Error parsing YAML fixture file'
      Logger.error(msg, e)
      throw new Error(msg)
  else if extension == 'coffee'
    coffee.eval(asset)
  else
    throw new Error('Unrecognized fixture extension: ' + extension)

Meteor.methods
  'tests/resetDatabase': ->
    console.log('tests/resetDatabase')
    resetDatabase()
    return true
  'tests/loadFixture': ->
    console.log('tests/loadFixture')
    loadFixture.apply(@, arguments)
    return true
