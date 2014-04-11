# Description:
#   Autotask Execute Command API
#
# Dependencies:
#   "<module name>": "<module version>"
#
# Configuration:
#   LIST_OF_ENV_VARS_TO_SET
#
# Commands:
#   hubot contact user@email.com - Responds with open contact URL
#   T12345678.0123 - Responds with ticket detail URL
#
# Notes:
#   <optional notes required for the script>
#
# Author:
#   scoop


soap     = require 'soap'
fs       = require 'fs'
mustache = require 'mustache'

config =
  wsdl: process.env.AUTOTASK_WSDL
  user: process.env.AUTOTASK_USER
  pass: process.env.AUTOTASK_PASS

class AutotaskAPI
  constructor: (@robot) ->

  query_xml_template:
    """
    <tns:query xmlns="http://autotask.net/ATWS/v1_5/">
      <sXML><![CDATA[
        <queryxml>
          <entity>{{entity}}</entity>
          <query>
          <field>
            {{field}}
            <expression op="{{op}}">{{expression}}</expression>
          </field>
          </query>
        </queryxml>
      ]]></sXML>
    </tns:query>
    """

  build_query_xml_template: (entity, field, expression, op) ->
    vars =
      entity: entity
      field: field
      expression: expression
      op: op || 'equals'

    query_xml = mustache.render @query_xml_template, vars

  query: (entity, field, expression, output, op) ->
    query_xml = @build_query_xml_template(entity, field,
      expression, op)

    soap.createClient config.wsdl, (err, client) ->
      client.setSecurity new soap.BasicAuthSecurity config.user,
        config.pass

      client.query query_xml, (err, result) ->
        output result.queryResult.EntityResults.Entity


module.exports = (robot) ->
  exec_command_api = 'https://ww7.autotask.net/Autotask/AutotaskExtend/ExecuteCommand.aspx?'
  autotask_api = new AutotaskAPI robot

  robot.hear /(T\d{8}\.\d+)/, (msg) ->
    ticket = msg.match[1]
    autotask_api.query 'ticket', 'ticketnumber', ticket, (results) ->
      result = results[0]
      if result
        msg.send "*#{result.TicketNumber}:* #{result.Title}\n" +
          "⏳ `#{new Date(result.LastActivityDate).toDateString()}` " +
          "💣 `#{new Date(result.DueDateTime).toDateString()}`\n" +
          "#{exec_command_api}Code=OpenTicketDetail&TicketNumber=#{ticket}"

  robot.respond /contact ([\w\.+-]+@[\w\.-]+\.\w+)/, (msg) ->
    email = msg.match[1]
    msg.reply "Contact Page: #{exec_command_api}Code=OpenContact&Email=#{email}"
