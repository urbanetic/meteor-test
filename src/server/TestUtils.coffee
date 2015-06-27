return unless process.env.IS_MIRROR

fs = Npm.require('fs')
Future = Npm.require('fibers/future')
path = Npm.require('path')

resetDatabase = ->
  collections = CollectionUtils.getAll()
  collections.push Meteor.users
  _.each collections, (collection) ->
    ids = _.map collection.find().fetch(), (doc) -> doc._id
    Collections.removeAllDocs(collection)
    if ids.length > 0
      Logger.info('Removed docs', ids, 'in collection ' + Collections.getName(collection))

loadFixture = (args) ->
  # TODO(aramk) Not sure what is calling this module with null args.
  unless args
    Logger.warn('Ignoring empty args passed to loadFixture:', args)
    return
  Logger.info('Test fixtures: Loading fixture:', args)
  name = args.name ? args
  fixture = Fixtures[name]
  unless fixture then throw new Error('Test fixtures: No fixture loaded with name:' + name)

  _.each fixture, (docs, collectionId) ->
    isUserCollection = collectionId == 'users'
    if isUserCollection
      collection = Meteor.users
    else
      collectionName = Strings.toTitleCase(collectionId)
      collection = Collections.get(collectionName)
    unless collection
      throw new Error('Test fixtures: Collection not found:' + collectionId)
    
    _.each docs, (doc) ->
      origDoc = doc
      if isUserCollection
        doc = Setter.clone(origDoc)
        delete doc.password
      origDoc._id = (collection.direct ? collection).insert(doc)

    if isUserCollection
      _.each docs, (doc) -> Accounts.setPassword(doc._id, doc.password)
    else if collection == Projects
      _.each docs, (doc) ->
        entities = doc.entities
        _.each entities, (entity) ->
          entity.projectId = doc._id
          (Entities.direct ? Entities).insert(entity)
          Logger.info('Test fixtures: Inserted', entities.length, 'entities in project', doc._id)

    Logger.info('Test fixtures: Inserted', docs.length, collectionId)

Meteor.methods
  'tests/resetDatabase': ->
    resetDatabase()
    return true
  'tests/loadFixture': ->
    @unblock()
    loadFixture.apply(@, arguments)
    return true
