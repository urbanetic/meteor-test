return unless process.env.IS_MIRROR

# Deletes everything from the test database.
resetDatabase = ->
  collections = CollectionUtils.getAll().concat(Meteor.users)
  for collection in collections
    ids = _.pluck collection.find({}, {_id: 1}).fetch(), '_id'
    Collections.removeAllDocs(collection)
    if ids.length
      Logger.debug "Removed docs #{ids} in collection #{Collections.getName(collection)}"

# Parsers the `args` object from whatever form it is given in, and returns an object with all
# properties explicitly defined.
_parseFixtureArgs = (args) ->
  output = {}
  # Note that the name cannot contain a period.
  if Types.isString args then [output.type, output.name] = args.split('.', 2)
  else output = args
  output

loadFixture = (args) ->
  # TODO(aramk) Not sure what is calling this module with null args.
  unless args
    Logger.warn('Ignoring empty args passed to loadFixture:', args)
    return

  args = _parseFixtureArgs args
  Logger.debug('Test fixtures: Loading fixture:', args)

  # If only a single fixture is requested, wrap it in an array anyway.
  if args.name
    fixtures = {}
    fixtures[args.name] = Fixtures[args.type][args.name]
  else fixtures = Fixtures[args.type]
  Logger.debug 'fixtures', fixtures

  unless fixtures then throw new Error "Test fixtures: No fixture loaded with name '#{args.type}'"

  # Allow the fixtures file to specify a collection, but default to the type.
  collectionId = Fixtures[args.type]._collectionId ? args.type
  Logger.debug 'collectionId', collectionId

  isUserCollection = collectionId == 'users'
  if isUserCollection then collection = Meteor.users
  else collection = Collections.get Strings.toTitleCase(collectionId)
  unless collection then throw new Error "Test fixtures: Collection not found: #{collectionId}"

  # Create each fixture, skipping any private properties of the Fixture object (starting with _).
  Logger.debug 'start loop'
  for name, doc of fixtures when !name.startsWith('_')
    Logger.debug 'start name', name
    # If it's a user, set the password correctly
    if isUserCollection
      password = doc.password
      delete doc.password
      doc._id = (collection.direct ? collection).insert(doc)
      Accounts.setPassword(doc._id, password)
    # Otherwise just insert.
    else
      Logger.debug 'inserting'
      try
        doc._id = (collection.direct ? collection).insert(doc)
      catch e
        Logger.error 'error', e
      Logger.debug 'inserted ', doc._id

    # If it's a project, insert its entities.
    if collection == Projects
      for entity in doc.entities
        entity.projectId = doc._id
        (Entities.direct ? Entities).insert(entity)
      Logger.debug "Test fixtures: Inserted #{doc.entities.length} entities in project #{doc._id}"

  Logger.debug "Test fixtures: Inserted #{fixtures.length} #{collectionId}"
  if args.name then fixtures[args.name] else fixtures

# Attach the server-only methods to the TestUtils object.
_.extend TestUtils,
  _server:
    resetDatabase: resetDatabase
    loadFixture: loadFixture

Meteor.methods
  'tests/resetDatabase': ->
    resetDatabase()
    return true
  'tests/loadFixture': ->
    @unblock()
    loadFixture.apply(@, arguments)
    return true
