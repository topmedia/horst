module.exports = (grunt) ->
  grunt.initConfig
    source: 'scripts/autotask.coffee'
    destination: '../tools_machines/cookbooks/topmedia-hubot/files/default/scripts/autotask.coffee'

  grunt.registerTask 'default', ['copy-to-cookbook']
  grunt.registerTask 'copy-to-cookbook', 'Copies the local script to the cookbook destination', ->
    grunt.file.copy grunt.config.data.source,
      grunt.config.data.destination

