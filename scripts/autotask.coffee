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

  query: (params, output) ->
    query_xml = @build_query_xml_template(params.entity, params.field,
      params.expression, params.op)
    console.log query_xml

    soap.createClient config.wsdl, (err, client) ->
      client.setSecurity new soap.BasicAuthSecurity config.user,
        config.pass

      client.query query_xml, (err, result) ->
        output result.queryResult.EntityResults.Entity


module.exports = (robot) ->
  exec_command_api = 'http://tpmd.co/at/'
  autotask_api = new AutotaskAPI robot

  robot.hear /(T\d{8}\.\d+)/, (msg) ->
    params = 
      entity: 'ticket'
      field: 'ticketnumber'
      expression: msg.match[1]
    autotask_api.query params, (results) ->
      result = results[0]
      if result
        msg.send "🎫  *#{result.TicketNumber}:* #{result.Title}\n" +
          "⏳  `#{new Date(result.LastActivityDate).toDateString()}` " +
          "💣  `#{new Date(result.DueDateTime).toDateString()}`\n" +
          "#{exec_command_api}OpenTicketDetail/TicketNumber/#{result.TicketNumber}"

  robot.hear /^(lastname|email) (.+)/i, (msg) ->
    field = if msg.match[1] == 'lastname' then 'lastname' else 'emailaddress'
    params =
      entity: 'contact'
      field: field
      expression: msg.match[2]
      op: 'beginswith'
    autotask_api.query params, (results) ->
      return msg.reply 'No results. Try again?' unless results?

      if results.length > 1
        msg.send """Multiple results:
          #{ (["#{r.FirstName} #{r.LastName}", r.EMailAddress, r.Phone, "#{exec_command_api}OpenContact/ContactID/#{r.id}"].join ', ' for r in results[0..4]).join "\n" } """
      else if results.length == 1
        result = results[0]
        msg.send """👦  #{result.FirstName} #{result.LastName} <#{result.EMailAddress}>
          📞  #{result.Phone}
          📄  #{exec_command_api}OpenContact/ContactID/#{result.id}
          🎫  #{exec_command_api}NewTicket/Phone/#{result.Phone}"""

  robot.hear /^account (.+)/i, (msg) ->
    params =
      entity: 'account'
      field: 'accountname'
      expression: msg.match[1]
      op: 'beginswith'
    autotask_api.query params, (results) ->
      return msg.reply 'No results. Try again?' unless results?

      if results.length > 1
        msg.send """Multiple results:
          #{ ([r.AccountName, "#{exec_command_api}OpenAccount/AccountID/#{r.id}"].join ', ' for r in results[0..4]).join "\n" } """
      else if results.length == 1
        result = results[0]
        msg.send """🏢  #{result.AccountName}
          📄  #{exec_command_api}OpenAccount/AccountID/#{result.id}
          🎫  #{exec_command_api}NewTicket/AccountID/#{result.id}"""
