// Meteor package definition.
Package.describe({
  name: 'urbanetic:test',
  version: '0.1.0',
  summary: 'A set of utilities for testing in Meteor using the Velocity framework.',
  git: 'https://bitbucket.org/urbanetic/meteor-test.git'
});

Package.onUse(function(api) {
  api.versionsFrom('METEOR@1.6.1');

  api.use([
    'coffeescript',
    'underscore',
    'aramk:q@1.0.1_1',
    'sanjo:jasmine@0.18.0',
    'urbanetic:utility@2.0.1'
  ]);
  //api.use(['practicalmeteor:chai@2.1.0_1'], {weak: true});
  api.imply(['sanjo:jasmine']);

  api.export([
    'TestUtils'
  ], ['client', 'server']);
  api.addFiles([
    'src/common/TestUtils.coffee'
  ], ['client', 'server']);
  api.addFiles([
    'src/server/TestUtils.coffee'
  ], ['server']);
});
